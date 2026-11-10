import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../progression/domain/progression.dart';
import '../../../progression/presentation/progression_providers.dart';
import '../../../radar/presentation/providers/radar_provider.dart';
import '../../../rival/data/rival_dialogue.dart';
import '../../../rival/domain/entities/rival_popup.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../../../missions/presentation/providers/economy_providers.dart';
import '../../../social/presentation/social_providers.dart' show weekStart;
import '../../../trip/domain/driver_archetype.dart';
import '../../../trip/domain/entities/trip.dart';
import '../../../trip/presentation/providers/trip_live_provider.dart';
import '../../../trip/presentation/providers/trip_provider.dart';
import '../widgets/home_map_background.dart';
import '../widgets/whats_new_overlay.dart';

/// Home / tab "Guida" — HEAT. Protagonista: AVVIA GUIDA (unico elemento
/// pieno d'accento con glow). Sopra: mappa reale come sfondo, barra con
/// radio · livello · notifiche, NOTTE/GIORNO, RADAR e il pannello HEAT.
/// Sotto: sfida della mascotte, missioni di oggi, ultime guide.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MapLibreMapController? _mapController;

  static const _mapHeight = 450.0;

  @override
  void initState() {
    super.initState();
    // Novità HEAT: una sola volta, la prima apertura della Home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowWhatsNew(context);
    });
  }

  Future<void> _recenter() async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await controller.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15,
      ));
    } catch (_) {
      // Permesso negato o GPS non disponibile: niente di bloccante.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guida rimasta 'active' lato server perché il processo è stato ucciso
    // a metà tracking: la proponiamo qui una sola volta.
    ref.listen<AsyncValue<PersistedTripState?>>(pendingTripRecoveryProvider,
        (previous, next) {
      final saved = next.valueOrNull;
      if (saved == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _showTripRecoveryDialog(context, ref, saved);
      });
    });

    final top = MediaQuery.paddingOf(context).top;
    final night = isNightTime(DateTime.now());

    // Niente Scaffold proprio: così `Scaffold.of` trova quello della shell
    // (drawer della radio).
    return ColoredBox(
      color: AppColor.base,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child: Stack(
          children: [
            // Mappa decorativa: scorre col contenuto, nessun gesto (lo
            // scroll della pagina ha la precedenza).
            SizedBox(
              height: _mapHeight + top,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: HomeMapBackground(
                      onMapCreated: (c) => setState(() => _mapController = c),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x8C0B0912),
                          Color(0x000B0912),
                          Color(0x000B0912),
                          Color(0xF20B0912),
                        ],
                        stops: [0, .2, .62, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 14,
              top: top + 238,
              child: _HeatPanel(night: night),
            ),
            Positioned(
              right: 14,
              top: top + 308,
              child: _SquareButton(
                icon: Icons.my_location_rounded,
                onTap: _recenter,
                semantics: 'centra la mappa',
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14, top + 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TopBar(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ModeChip(night: night),
                      const _RadarChip(),
                    ],
                  ),
                  const SizedBox(height: 248 + 104),
                  HeatEnter(
                    child: HeatButton(
                      label: 'AVVIA GUIDA',
                      subtitle: 'registrazione con telemetria e FLOW',
                      height: 80,
                      fontSize: 38,
                      alignStart: true,
                      gradientEnd: night ? AppColor.night : AppColor.day,
                      onPressed: () => context.push(AppRoutes.tripLive),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const HeatEnter(index: 1, child: _RivalCard()),
                  const SizedBox(height: 10),
                  const _WeekBanner(),
                  const HeatEnter(index: 2, child: _MissionsCard()),
                  const SizedBox(height: 18),
                  const _RecentTrips(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BARRA IN ALTO
// ---------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(levelProgressProvider);
    final mascot = ref.watch(activeMascotProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final translucent = AppColor.surface.withValues(alpha: .92);

    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeatPanel(
            shape: const SlantBorder(left: 0, right: 10),
            color: translucent,
            padding: EdgeInsets.zero,
            onTap: () => Scaffold.maybeOf(context)?.openDrawer(),
            child: SizedBox(
              width: 50,
              child:
                  Icon(Icons.radio_rounded, color: AppColor.accent, size: 22),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: HeatPanel(
              color: translucent,
              padding: const EdgeInsets.fromLTRB(12, 5, 16, 5),
              onTap: () => context.push(AppRoutes.profile),
              child: Row(
                children: [
                  ClipPath(
                    clipper:
                        const ShapeBorderClipper(shape: SlantBorder.all(6)),
                    child: Image.asset(
                      'assets/faces/${mascot.id}.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'LV ${progress?.level ?? '–'} ',
                              style: AppType.display(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            Text(
                              progress?.title ?? '',
                              style: AppType.display(
                                fontSize: 13,
                                color: AppColor.accent,
                                letterSpacing: 1,
                                italic: false,
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              flex: 3,
                              child: Text(
                                progress == null
                                    ? ''
                                    : '${_fmt(progress.xpInLevel)} / '
                                        '${_fmt(progress.xpNeeded)} XP',
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: AppType.display(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColor.inkMuted,
                                  italic: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        SkewBar(value: progress?.fraction ?? 0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: unread > 0 ? 'notifiche, $unread non lette' : 'notifiche',
            child: HeatPanel(
              shape: const SlantBorder(left: 10, right: 0),
              color: translucent,
              padding: EdgeInsets.zero,
              onTap: () => context.push(AppRoutes.notifications),
              child: SizedBox(
                width: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_outlined,
                        color: AppColor.ink, size: 22),
                    if (unread > 0)
                      Positioned(
                        top: 7,
                        right: 6,
                        child: Container(
                          constraints:
                              const BoxConstraints(minWidth: 17, minHeight: 17),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          color: AppColor.accent,
                          alignment: Alignment.center,
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: AppType.display(
                              fontSize: 13,
                              color: AppColor.onAccent,
                              italic: false,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.night});

  final bool night;

  @override
  Widget build(BuildContext context) {
    return HeatChip(
      label: night ? 'NOTTE' : 'GIORNO',
      leading: Icon(
        night ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
        size: 18,
        color: night ? AppColor.night : AppColor.day,
      ),
      onTap: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(night
              ? 'notte: dalle 22 alle 6 le guide alzano l\'HEAT e moltiplicano gli XP.'
              : 'giorno: niente HEAT. dalle 22 ogni guida lo fa salire.'),
        )),
    );
  }
}

class _RadarChip extends ConsumerWidget {
  const _RadarChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(radarModeControllerProvider);
    return HeatChip(
      label: on ? 'RADAR ON' : 'RADAR OFF',
      leading: Transform.rotate(
        angle: .785,
        child: Container(
          width: 7,
          height: 7,
          color: on ? AppColor.accent : AppColor.inkFaint,
        ),
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColor.surface,
        barrierColor: const Color(0x99000000),
        shape: const RoundedRectangleBorder(),
        builder: (_) => const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 20, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel('RADAR VELOX / PATTUGLIA'),
                SizedBox(height: 12),
                _RadarModeSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.onTap,
    required this.semantics,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: HeatPanel(
        color: AppColor.surfaceHigh,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, color: AppColor.ink, size: 22),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HEAT
// ---------------------------------------------------------------------------

class _HeatPanel extends ConsumerWidget {
  const _HeatPanel({required this.night});

  final bool night;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heat = ref.watch(heatProvider);
    final streak = ref.watch(streakProvider);
    final lit = night ? AppColor.accent : AppColor.day;
    final mult = heatMultiplier(heat);

    return HeatPanel(
      shape: const SlantBorder(left: 0, right: 12),
      color: const Color(0xC70B0912),
      borderColor: null,
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'HEAT $heat',
                style: AppType.display(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                night
                    ? '×${mult.toStringAsFixed(2).replaceAll('.', ',')} XP'
                    : 'solo di notte',
                style: AppType.display(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColor.inkMuted,
                  italic: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= kHeatMax; i++)
                Icon(
                  i <= heat
                      ? Icons.local_fire_department_rounded
                      : Icons.local_fire_department_outlined,
                  size: 22,
                  color: i <= heat ? lit : AppColor.line,
                ),
            ],
          ),
          if (streak > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 16, color: AppColor.gold),
                const SizedBox(width: 4),
                Text(
                  'SERIE $streak ${streak == 1 ? 'GIORNO' : 'GIORNI'} · '
                  '+${streakBonusXp(streak + 1)} XP DOMANI',
                  style: AppType.display(
                    fontSize: 13,
                    letterSpacing: 1,
                    color: AppColor.gold,
                    italic: false,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CARD
// ---------------------------------------------------------------------------

class _RivalCard extends ConsumerWidget {
  const _RivalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mascot = ref.watch(activeMascotProvider);
    final trips = ref.watch(recentTripsProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final drovenToday = trips.any((t) =>
        t.startedAt.year == now.year &&
        t.startedAt.month == now.month &&
        t.startedAt.day == now.day);
    final pool = phrasesFor(
      mascot.id,
      drovenToday ? RivalMood.greeting : RivalMood.inactivityTaunt,
      bonded: ref.watch(activeBondProvider).unlocked(3),
    );
    // Stessa frase per tutto il giorno: niente sfarfallio ai rebuild.
    final line = pool[now.day % pool.length];
    final c = mascot.accentColor;

    return HeatPanel(
      shape: const ChamferBorder(cut: 14, bottomLeft: true),
      gradient: LinearGradient(
        colors: [c.withValues(alpha: .35), AppColor.surface],
        stops: const [0, .6],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      onTap: () => context.go(AppRoutes.game),
      child: Row(
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: SlantBorder.all(8, side: BorderSide(color: c, width: 1.5)),
            ),
            // Skin neon (pass / legame LV5): alone nel colore mascotte
            // intorno al ritratto.
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: const SlantBorder.all(8),
                shadows: ref.watch(cosmeticsProvider).neonSkin
                    ? [
                        BoxShadow(
                            color: c.withValues(alpha: .8), blurRadius: 14),
                        BoxShadow(
                            color: c.withValues(alpha: .5), blurRadius: 4),
                      ]
                    : null,
              ),
              child: ClipPath(
                clipper: const ShapeBorderClipper(shape: SlantBorder.all(8)),
                child: Image.asset(
                  'assets/faces/${mascot.id}.png',
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SFIDA DA ${mascot.name}',
                  style: AppType.display(
                    fontSize: 14,
                    letterSpacing: 1.8,
                    color: c,
                    italic: false,
                  ),
                ),
                const SizedBox(height: 3),
                Text('"$line"', style: AppType.body.copyWith(height: 1.35)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColor.inkMuted, size: 24),
        ],
      ),
    );
  }
}

/// "LA TUA SETTIMANA È PRONTA": km e pilota della settimana in corso,
/// tocco = storia /week. Solo se c'è almeno una guida da lunedì.
class _WeekBanner extends ConsumerWidget {
  const _WeekBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(recentTripsProvider).valueOrNull ?? const [];
    final from = weekStart(DateTime.now());
    final week = [
      for (final t in trips)
        if (!t.startedAt.isBefore(from)) t,
    ];
    if (week.isEmpty) return const SizedBox.shrink();
    final km = week.fold(0.0, (s, t) => s + t.distanceKm);
    final pilots = archetypesOf(week);
    final tally = <String, int>{};
    for (final a in pilots) {
      tally[a.name] = (tally[a.name] ?? 0) + 1;
    }
    final top = tally.entries.isEmpty
        ? null
        : tally.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HeatEnter(
        index: 2,
        child: HeatPanel(
          shape: const SlantBorder.all(10),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          onTap: () => context.push(AppRoutes.week),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColor.ink, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LA TUA SETTIMANA È PRONTA',
                        style: AppType.display(fontSize: 17, letterSpacing: 1)),
                    Text(
                      [
                        '${km.toStringAsFixed(km < 10 ? 1 : 0)} km',
                        if (top != null) 'pilota $top',
                      ].join(' · '),
                      style:
                          AppType.text(fontSize: 12, color: AppColor.inkMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColor.inkMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionsCard extends ConsumerWidget {
  const _MissionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(todayMissionsProvider);
    final total = m?.total ?? 0;
    return HeatPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
      onTap: () => context.push(AppRoutes.missions),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, color: AppColor.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'MISSIONI DI OGGI',
                        style: AppType.display(
                          fontSize: 15,
                          letterSpacing: 1.6,
                          italic: false,
                        ),
                      ),
                    ),
                    Text(
                      m == null ? '–' : '${m.done}/$total',
                      style: AppType.display(
                        fontSize: 15,
                        color: AppColor.inkMuted,
                        italic: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SkewBar(
                  value: total == 0 ? 0 : m!.done / total,
                  segments: total == 0 ? 4 : total,
                  color: AppColor.gold,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right_rounded,
              color: AppColor.inkMuted, size: 22),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ULTIME GUIDE
// ---------------------------------------------------------------------------

class _RecentTrips extends ConsumerWidget {
  const _RecentTrips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(recentTripsProvider);
    final count = tripsAsync.valueOrNull?.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'ULTIME GUIDE',
          trailing: count == null ? null : '$count guide',
        ),
        const SizedBox(height: 6),
        tripsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Center(
              child: CircularProgressIndicator(color: AppColor.accent),
            ),
          ),
          error: (e, _) => const _InfoRow(
            'impossibile caricare lo storico. riprova tra poco.',
          ),
          data: (trips) {
            if (trips.isEmpty) {
              return const _InfoRow(
                'nessuna guida registrata. premi AVVIA GUIDA per il primo FLOW.',
              );
            }
            return Column(
              children: [
                for (var i = 0; i < trips.length && i < 6; i++) ...[
                  if (i > 0) const SizedBox(height: 5),
                  HeatEnter(index: i, child: _TripRow(trip: trips[i])),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      color: AppColor.surface,
      child: Text(text, style: AppType.body.copyWith(color: AppColor.inkMuted)),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip});

  final Trip trip;

  static const _days = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final s = trip.startedAt;
    final night = isNightTime(s);
    final hm =
        '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
    final date = '${_days[s.weekday - 1]} ${s.day} · $hm';
    final minutes = (trip.durationSeconds / 60).round();
    final km = trip.distanceKm.toStringAsFixed(1).replaceAll('.', ',');

    return HeatPanel(
      borderColor: null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      onTap: () =>
          context.push(AppRoutes.tripDetail.replaceFirst(':tripId', trip.id)),
      child: Row(
        children: [
          Icon(
            night ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 20,
            color: AppColor.inkFaint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: AppType.text(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text('$km km · $minutes min', style: AppType.caption),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                trip.drivingScore?.toString() ?? '–',
                style: AppType.display(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'FLOW',
                style: AppType.display(
                  fontSize: 12,
                  letterSpacing: 1,
                  color: AppColor.inkMuted,
                  italic: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GUIDA INTERROTTA
// ---------------------------------------------------------------------------

void _showTripRecoveryDialog(
    BuildContext context, WidgetRef ref, PersistedTripState saved) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColor.surfaceHigh,
      title: const Text('Guida interrotta'),
      content: Text(
        'L\'ultima guida si è interrotta a ${saved.distanceKm.toStringAsFixed(1)} km. '
        'Vuoi riprenderla o chiuderla qui?',
        style: AppType.text(color: AppColor.inkMuted),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogCtx);
            await ref
                .read(tripLiveControllerProvider.notifier)
                .discardPersistedTrip(saved);
          },
          child: const Text('Scarta', style: TextStyle(color: AppColor.danger)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogCtx);
            await ref
                .read(tripLiveControllerProvider.notifier)
                .finishPersistedTrip(saved);
          },
          child: const Text('Termina qui'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogCtx);
            await ref
                .read(tripLiveControllerProvider.notifier)
                .resumeTrip(saved);
            if (context.mounted) context.push(AppRoutes.tripLive);
          },
          child: Text('Riprendi', style: TextStyle(color: AppColor.accent)),
        ),
      ],
    ),
  );
}

/// Interruttore della modalità Velox/Pattuglia + le sue 4 card di
/// monitoraggio quando attiva. Da spento nessun provider di
/// lib/features/radar/ fa richieste (vedi RadarModeController) — qui si
/// nasconde anche la UI corrispondente, non solo i dati.
class _RadarModeSection extends ConsumerWidget {
  const _RadarModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(radarModeControllerProvider);

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.radar_rounded,
                size: 20, color: enabled ? AppColor.accent : AppColor.inkMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Rilevamento Velox/Pattuglia',
                  style: AppType.text(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColor.ink)),
            ),
            Switch.adaptive(
              value: enabled,
              activeThumbColor: AppColor.accent,
              onChanged: (_) =>
                  ref.read(radarModeControllerProvider.notifier).toggle(),
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 6),
          const _RadarCardsGrid(),
          const SizedBox(height: 10),
          Text(
            'Tutti i dati sono aggiornati in tempo reale.',
            textAlign: TextAlign.center,
            style: AppType.text(fontSize: 11.5, color: AppColor.inkMuted),
          ),
        ],
      ],
    );
  }
}

/// Le 4 card di monitoraggio Velox/Pattuglia (API arancio, community
/// ciano) — conteggi reali dai provider in lib/features/radar/, mai
/// valori fissi.
class _RadarCardsGrid extends ConsumerWidget {
  const _RadarCardsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final veloxApi = ref.watch(currentVeloxApiEventsProvider);
    final pattugliaApi = ref.watch(currentPattugliaApiEventsProvider);
    final veloxCommunity = ref.watch(communityVeloxReportsProvider);
    final pattugliaCommunity = ref.watch(communityPattugliaReportsProvider);

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RadarCard(
                  icon: Icons.videocam_rounded,
                  color: AppColor.amber,
                  title: 'Velox API',
                  subtitle: veloxApi.when(
                    loading: () => 'Aggiornamento…',
                    error: (_, __) => 'Non disponibile',
                    data: (list) => 'OSM: ${list.length} punti monitorati.',
                  ),
                  isLoading: veloxApi.isLoading,
                  hasError: veloxApi.hasError,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RadarCard(
                  icon: Icons.local_police_rounded,
                  color: AppColor.amber,
                  title: 'Pattuglia API',
                  subtitle: pattugliaApi.when(
                    loading: () => 'Aggiornamento…',
                    error: (_, __) => 'Non disponibile',
                    data: (list) => 'Waze: ${list.length} nella zona.',
                  ),
                  isLoading: pattugliaApi.isLoading,
                  hasError: pattugliaApi.hasError,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RadarCard(
                  icon: Icons.videocam_rounded,
                  color: AppColor.accent,
                  title: 'Velox Community',
                  subtitle:
                      'Segnalazioni recenti: ${veloxCommunity.length} in zona.',
                  isLoading: false,
                  hasError: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RadarCard(
                  icon: Icons.shield_rounded,
                  color: AppColor.accent,
                  title: 'Pattuglia Community',
                  subtitle:
                      'Segnalazioni recenti: ${pattugliaCommunity.length} in zona.',
                  isLoading: false,
                  hasError: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RadarCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isLoading;
  final bool hasError;
  const _RadarCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor =
        hasError ? AppColor.danger : (isLoading ? AppColor.inkMuted : color);
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColor.surfaceHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.text(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: AppColor.ink)),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 4, top: 2),
                      decoration: BoxDecoration(
                          color: dotColor, shape: BoxShape.circle),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppType.text(fontSize: 11, color: AppColor.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
