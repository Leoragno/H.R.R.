import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../../../../core/widgets/notification_bell_button.dart';
import '../../../../core/widgets/profile_avatar_button.dart';
import '../../../radar/presentation/providers/radar_provider.dart';
import '../../../trip/domain/entities/trip.dart';
import '../../../trip/presentation/providers/trip_live_provider.dart';
import '../../../trip/presentation/providers/trip_provider.dart';
import '../../../trip/presentation/widgets/route_preview_painter.dart';
import '../widgets/home_map_background.dart';

/// Home / tab "Guida": sfondo decorativo + sheet trascinabile con storico
/// viaggi e CTA per iniziare una nuova corsa. Vedi Guida.dc.html righe
/// 152-282 (stato non-live: mappa + bottom sheet). Prende il posto del
/// vecchio HUD pilota (rimosso per ora su richiesta) — era prima il
/// contenuto del tab "Mappa", spostato qui e rinominato.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MapLibreMapController? _mapController;

  // La sheet trascinabile può collassare fino a questa frazione
  // dell'altezza schermo (vedi minChildSize sotto): il FAB "centra" resta
  // sempre appena sopra, qualunque sia la sua posizione attuale.
  static const _sheetMinChildSize = 0.14;

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
      // Permesso negato o GPS non disponibile: nessun errore bloccante da
      // mostrare, l'utente può comunque continuare a esplorare la mappa a
      // mano.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guida rimasta 'active' lato server perché il processo è stato ucciso
    // a metà tracking (kill di sistema, riavvio, force-stop): la
    // proponiamo qui una sola volta, invece di lasciarla bloccata per
    // sempre fuori dalla cronologia (che mostra solo status='completed').
    ref.listen<AsyncValue<PersistedTripState?>>(pendingTripRecoveryProvider,
        (previous, next) {
      final saved = next.valueOrNull;
      if (saved == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _showTripRecoveryDialog(context, ref, saved);
      });
    });

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: Stack(
        children: [
          Positioned.fill(
            child: HomeMapBackground(
              onMapCreated: (c) => setState(() => _mapController = c),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColor.void_.withValues(alpha: 0.55),
                    AppColor.void_.withValues(alpha: 0),
                    AppColor.void_.withValues(alpha: 0),
                    AppColor.void_.withValues(alpha: 0.6),
                  ],
                  stops: const [0, 0.22, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            right: AppSpace.md,
            bottom: MediaQuery.sizeOf(context).height * _sheetMinChildSize +
                AppSpace.md,
            child: _RecenterButton(onTap: _recenter),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.34,
            minChildSize: _sheetMinChildSize,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [_sheetMinChildSize, 0.34, 0.92],
            builder: (context, scrollController) =>
                _GuidaSheet(scrollController: scrollController),
          ),
        ],
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.surfaceHigh.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(AppSpace.md),
          child: Icon(Icons.my_location_rounded, color: AppColor.ink, size: 26),
        ),
      ),
    );
  }
}

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
          child:
              const Text('Scarta', style: TextStyle(color: AppColor.danger)),
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
          child: const Text('Riprendi',
              style: TextStyle(color: AppColor.cyan)),
        ),
      ],
    ),
  );
}

class _GuidaSheet extends ConsumerWidget {
  final ScrollController scrollController;
  const _GuidaSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(recentTripsProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColor.surfaceHigh.withValues(alpha: 0.92),
            AppColor.void_.withValues(alpha: 0.96),
          ],
        ),
        border: const Border(
          top: BorderSide(color: AppColor.line, width: 1),
          left: BorderSide(color: AppColor.line, width: 1),
          right: BorderSide(color: AppColor.line, width: 1),
        ),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: AppSpace.sm),
                Container(
                  width: 96,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColor.line,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Guide',
                        style: AppType.text(
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          color: AppColor.ink,
                        ),
                      ),
                      const Row(
                        children: [
                          NotificationBellButton(size: 40),
                          SizedBox(width: 10),
                          ProfileAvatarButton(),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
                  child: NeonCtaButton(
                    label: 'Drive',
                    icon: Icons.play_arrow_rounded,
                    minHeight: 58,
                    onPressed: () => context.push(AppRoutes.tripLive),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                      AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
                  child: _RadarModeSection(),
                ),
              ],
            ),
          ),
          tripsAsync.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: AppColor.cyan),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('Impossibile caricare lo storico',
                    style:
                        AppType.text(color: AppColor.inkMuted)),
              ),
            ),
            data: (trips) {
              if (trips.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyTrips(),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
                sliver: SliverList.separated(
                  itemCount: trips.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColor.line),
                  itemBuilder: (context, i) =>
                      _TripRow(trip: trips[i], showDivider: i > 0),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.directions_car_rounded,
              color: AppColor.inkMuted, size: 30),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              'Ancora nessuna guida registrata. Premi Drive per iniziare.',
              style: AppType.text(
                  color: AppColor.inkMuted, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
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
                size: 20,
                color: enabled
                    ? AppColor.cyan
                    : AppColor.inkMuted),
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
              activeThumbColor: AppColor.cyan,
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
            style: AppType.text(
                fontSize: 11.5, color: AppColor.inkMuted),
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
                  color: AppColor.cyan,
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
                  color: AppColor.cyan,
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
                    style: AppType.text(
                        fontSize: 11, color: AppColor.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final Trip trip;
  final bool showDivider;
  const _TripRow({required this.trip, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final start = trip.startedAt;
    final end = trip.endedAt;
    final date = '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')}/${start.year}';
    final timeRange = end == null ? _hm(start) : '${_hm(start)} – ${_hm(end)}';
    final duration = trip.durationSeconds ~/ 60;

    return InkWell(
      onTap: () =>
          context.push(AppRoutes.tripDetail.replaceFirst(':tripId', trip.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              height: 46,
              child: trip.route.length >= 2
                  ? RoutePreview(points: trip.route)
                  : CustomPaint(painter: _SparkPainter(trip.id.hashCode)),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date,
                      style: AppType.text(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: AppColor.ink)),
                  const SizedBox(height: 2),
                  Text(timeRange,
                      style: AppType.text(
                          fontSize: 15, color: AppColor.inkMuted)),
                  Text(
                      '${trip.distanceKm.toStringAsFixed(1)} km · $duration min',
                      style: AppType.text(
                          fontSize: 15, color: AppColor.inkMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—',
                  style: AppType.metric.copyWith(fontSize: 28),
                ),
                Text('KM/H', style: AppType.label),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Sparkline decorativa e deterministica, usata solo come fallback per i
/// viaggi antecedenti al salvataggio del percorso reale (route vuota).
class _SparkPainter extends CustomPainter {
  final int seed;
  const _SparkPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = seed & 0x7fffffff;
    final points = <Offset>[];
    for (var i = 0; i < 8; i++) {
      final x = size.width * i / 7;
      final noise = ((rnd >> (i * 3)) % 100) / 100;
      final y = size.height * (0.2 + 0.6 * noise);
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColor.inkMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
