// Edge Function "send-push" — invocata dal trigger DB
// notify_push_on_notification_insert (vedi
// supabase/migrations/0016_notification_push_trigger.sql) ad ogni nuova
// riga in `notifications`. Legge i token FCM del profilo da
// `push_tokens` (service role, bypassa RLS) e manda la push via la FCM
// HTTP v1 API.
//
// La legacy API (`fcm.googleapis.com/fcm/send`, un semplice "server key")
// è stata SPENTA da Google il 20 giugno 2024: non è più utilizzabile a
// prescindere dalla chiave. La v1 API richiede invece un access token
// OAuth2 ottenuto firmando un JWT con la chiave privata di un service
// account Firebase (RS256, via Web Crypto — nessuna libreria esterna).
//
// Setup:
//   1. Firebase Console -> Project Settings -> Service Accounts ->
//      "Generate new private key" -> scarica il JSON.
//   2. supabase functions deploy send-push
//   3. supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"
//   4. Aggiorna l'URL/service-role-key placeholder nella migration 0016
//      con quelli reali del tuo progetto (Project Settings -> API).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? ''

interface PushRequest {
  profile_id: string
  title: string
  body?: string | null
  data?: Record<string, unknown> | null
}

interface ServiceAccount {
  client_email: string
  private_key: string
  project_id: string
}

// Cache in-process dell'access token OAuth2: valido 1h, riusato tra
// invocazioni "calde" della function per non richiederne uno nuovo ad
// ogni singola push (ogni riga di `notifications` ne genera una).
let cachedToken: { token: string; expiresAt: number } | null = null

function pemToDer(pem: string): Uint8Array {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '')
  const raw = atob(base64)
  const bytes = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i)
  return bytes
}

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input
  let binary = ''
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

async function fetchAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const encHeader = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const encClaims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))
  const unsigned = `${encHeader}.${encClaims}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const jwt = `${unsigned}.${base64url(new Uint8Array(signature))}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  if (!res.ok) {
    throw new Error(`Scambio token OAuth2 fallito: ${res.status} ${await res.text()}`)
  }
  const json = await res.json()
  return json.access_token as string
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Date.now()
  if (cachedToken && cachedToken.expiresAt > now) return cachedToken.token
  const token = await fetchAccessToken(sa)
  cachedToken = { token, expiresAt: now + 55 * 60 * 1000 } // margine sotto l'ora reale
  return token
}

// FCM v1 accetta solo stringhe nei valori di `data`.
function stringifyData(data: Record<string, unknown> | null | undefined): Record<string, string> {
  if (!data) return {}
  const out: Record<string, string> = {}
  for (const [k, v] of Object.entries(data)) {
    out[k] = typeof v === 'string' ? v : JSON.stringify(v)
  }
  return out
}

Deno.serve(async (req: Request) => {
  try {
    const { profile_id, title, body, data } = (await req.json()) as PushRequest
    if (!profile_id || !title) {
      return new Response(JSON.stringify({ error: 'profile_id e title sono obbligatori' }), {
        status: 400,
      })
    }

    // Nessun service account configurato: no-op silenzioso — la notifica
    // in-app (Supabase Realtime) esiste comunque a prescindere da qui.
    if (!FCM_SERVICE_ACCOUNT_JSON) {
      return new Response(JSON.stringify({ skipped: 'FCM_SERVICE_ACCOUNT_JSON non configurata' }), {
        status: 200,
      })
    }

    let serviceAccount: ServiceAccount
    try {
      serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT_JSON)
    } catch {
      return new Response(JSON.stringify({ error: 'FCM_SERVICE_ACCOUNT_JSON non è un JSON valido' }), {
        status: 500,
      })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const { data: tokens, error } = await supabase
      .from('push_tokens')
      .select('token')
      .eq('profile_id', profile_id)

    if (error) throw error
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: 'nessun device registrato' }), {
        status: 200,
      })
    }

    const accessToken = await getAccessToken(serviceAccount)

    const results = await Promise.all(
      tokens.map(async (row: { token: string }) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: row.token,
                // Blocco `notification` (title/body): è quello che fa sì
                // che Android mostri DA SOLO una system notification in
                // barra quando l'app è in background/terminata — senza,
                // un messaggio "data-only" non produce mai un popup di
                // sistema, solo un evento silenzioso che l'app deve
                // gestire lei stessa (e non lo fa se non è in esecuzione).
                notification: { title, body: body ?? '' },
                // `android.notification.channel_id` deve combaciare con
                // l'id creato lato client (vedi hrrNotificationChannelId
                // in local_notifications_service.dart, IMPORTANCE_HIGH, e
                // il meta-data default_notification_channel_id nel
                // manifest): un id diverso qui fa cadere Android su un
                // canale creato al volo con importanza di default (niente
                // popup/heads-up né suono, solo una riga silenziosa).
                android: {
                  priority: 'high',
                  notification: {
                    channel_id: 'hrr_default_channel',
                    icon: 'ic_notification',
                    color: '#35E0FF',
                    sound: 'default',
                    notification_priority: 'PRIORITY_HIGH',
                    default_vibrate_timings: true,
                  },
                },
                data: stringifyData(data),
              },
            }),
          },
        )

        if (!res.ok) {
          const errText = await res.text()
          // Token non più valido (app disinstallata, token ruotato senza
          // passare da register_push_token, ecc.): lo rimuoviamo per non
          // ritentare all'infinito su un device morto.
          if (errText.includes('UNREGISTERED') || errText.includes('NOT_FOUND')) {
            await supabase.from('push_tokens').delete().eq('token', row.token)
          }
          return false
        }
        return true
      }),
    )

    return new Response(
      JSON.stringify({ sent: results.filter(Boolean).length, total: results.length }),
      { status: 200 },
    )
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 })
  }
})
