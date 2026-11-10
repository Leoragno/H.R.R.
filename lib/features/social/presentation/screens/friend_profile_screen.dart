import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pilots/presentation/widgets/pilot_emblem.dart';
import '../../../rival/domain/entities/mascot.dart';
import '../../domain/social_models.dart';
import '../social_providers.dart';
import '../widgets/social_widgets.dart';
import 'challenges_screen.dart';

/// Profilo di un amico (HEAT): hero con la sua mascotte, stato, il suo
/// pilota, l'auto, quattro numeri, il testa a testa nelle sfide e la CTA
/// "SFIDA @nome" (unico accento). Niente "rimuovi": l'app è chiusa.
class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friend = ref.watch(friendProvider(profileId));
    if (friend == null) {
      final loading = ref.watch(friendsProvider).isLoading;
      return Scaffold(
        backgroundColor: AppColor.base,
        body: SafeArea(
          child: Column(
            children: [
              const BackRow(),
              Expanded(
                child: Center(
                  child: loading
                      ? const CircularProgressIndicator(color: AppColor.ink)
                      : Text('pilota non trovato.',
                          style: AppType.text(
                              fontSize: 14, color: AppColor.inkMuted)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final me = ref.watch(authStateProvider).valueOrNull?.id ?? '';
    final u = friend.user;
    final mascot = kMascotCatalog.firstWhere((m) => m.id == u.mascotId,
        orElse: () => kMascotCatalog.first);
    final status = friendStatus(friend,
        driving: ref.watch(drivingNowProvider).contains(friend.id),
        now: DateTime.now());
    final history = ref.watch(friendPilotProvider(friend.id));
    final trips =
        ref.watch(friendTripsProvider(friend.id)).valueOrNull ?? const [];
    final topSpeed = trips.fold<double>(
        0, (m, t) => (t.maxSpeedKmh ?? 0) > m ? t.maxSpeedKmh! : m);
    final bestFlow = trips.fold<int>(
        0, (m, t) => (t.drivingScore ?? 0) > m ? t.drivingScore! : m);
    final h2h = [
      for (final c
          in ref.watch(challengesProvider).valueOrNull ?? const <Challenge>[])
        if (c.otherId(me) == friend.id && c.status == ChallengeStatus.finished)
          c,
    ];
    final rec = recordOf(h2h, me);
    final car =
        [u.vehicleBrand, u.vehicleModel].whereType<String>().join(' ').trim();

    final stats = [
      ('KM TOTALI', u.totalKm.round().toString()),
      ('GUIDE', u.totalTrips.toString()),
      ('TOP SPEED', topSpeed == 0 ? '—' : '${topSpeed.round()} km/h'),
      ('MIGLIOR FLOW', bestFlow == 0 ? '—' : '$bestFlow'),
    ];

    return Scaffold(
      backgroundColor: AppColor.base,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(
            friend: friend,
            mascot: mascot,
            status: status,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColor.surface,
                border: Border.all(color: AppColor.line),
              ),
              child: Row(
                children: [
                  PilotEmblem(
                    monogram: history.main?.monogram ?? '?',
                    width: 52,
                    locked: history.main == null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IL SUO PILOTA',
                            style: AppType.display(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                italic: false,
                                letterSpacing: 1.6,
                                color: AppColor.inkMuted)),
                        Text(
                            history.main?.name.toUpperCase() ??
                                'ANCORA DA SCOPRIRE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.display(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColor.ink)),
                        if (history.main != null)
                          Text(history.main!.source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.text(
                                  fontSize: 12, color: AppColor.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (car.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Container(
                color: AppColor.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car_rounded,
                        size: 22, color: AppColor.inkMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(car.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.display(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: AppColor.ink)),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Column(
              children: [
                for (var r = 0; r < 2; r++)
                  Padding(
                    padding: EdgeInsets.only(top: r == 0 ? 0 : 5),
                    child: Row(
                      children: [
                        for (var c = 0; c < 2; c++) ...[
                          if (c == 1) const SizedBox(width: 5),
                          Expanded(child: _Stat(stats[r * 2 + c])),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
            child: Row(
              children: [
                const Expanded(child: SectionLabel('Testa a testa')),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${rec.won}'),
                    const TextSpan(
                        text: ' – ',
                        style: TextStyle(color: AppColor.inkFaint)),
                    TextSpan(text: '${rec.lost}'),
                  ]),
                  style: AppType.display(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColor.ink),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: h2h.isEmpty
                ? const EmptyNote('non vi siete ancora sfidati.')
                : Column(
                    children: [
                      for (final c in h2h.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _H2hRow(challenge: c, me: me),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 36),
            child: HeatButton(
              label: 'SFIDA @${friend.username.toUpperCase()}',
              icon: Icons.sports_mma_rounded,
              height: 58,
              fontSize: 22,
              onPressed: () => showNewChallengeSheet(context, ref,
                  initialOpponentId: friend.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.friend,
    required this.mascot,
    required this.status,
  });

  final Friend friend;
  final Mascot mascot;
  final FriendStatus status;

  @override
  Widget build(BuildContext context) {
    final u = friend.user;
    return SizedBox(
      height: 340,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(.56, -.1),
                  radius: .9,
                  colors: [
                    mascot.accentColor.withValues(alpha: .35),
                    AppColor.base.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: 30,
            width: 230,
            height: 262,
            child: Image.asset(
              'assets/mascots/${mascot.id}_hero.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 150,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000B0912), AppColor.base],
                  stops: [0, .72],
                ),
              ),
            ),
          ),
          const SafeArea(child: BackRow()),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColor.base,
                    border: Border.all(color: status.color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Diamond(color: status.color, size: 7),
                      const SizedBox(width: 6),
                      Text(status.label,
                          style: AppType.display(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              italic: false,
                              letterSpacing: 1.4,
                              color: status.color)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text('@${u.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.display(
                        fontSize: 50,
                        fontWeight: FontWeight.w900,
                        height: .9,
                        color: AppColor.ink)),
                const SizedBox(height: 6),
                Text(
                  [
                    'LV ${u.level}',
                    mascot.name,
                    if (u.country != null && u.country!.isNotEmpty) u.country!,
                  ].join(' · '),
                  style: AppType.text(fontSize: 14, color: AppColor.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.stat);
  final (String, String) stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const ShapeDecoration(
        color: AppColor.surface,
        shape: ChamferBorder(cut: 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.display(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  italic: false,
                  letterSpacing: 1.4,
                  color: AppColor.inkMuted)),
          Text(stat.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.display(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColor.ink)),
        ],
      ),
    );
  }
}

class _H2hRow extends StatelessWidget {
  const _H2hRow({required this.challenge, required this.me});
  final Challenge challenge;
  final String me;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final (badge, color) = switch (c.outcomeFor(me)) {
      ChallengeOutcome.won => ('VINTA', AppColor.success),
      ChallengeOutcome.lost => ('PERSA', AppColor.danger),
      _ => ('PARI', AppColor.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColor.surface,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(badge,
                style: AppType.display(
                    fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          ),
          Expanded(
            child: Text(c.metric.label,
                style: AppType.text(fontSize: 13, color: AppColor.inkMuted)),
          ),
          Text(
              '${c.metric.format(c.myScore(me))} – '
              '${c.metric.format(c.theirScore(me))}',
              style: AppType.display(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  italic: false,
                  color: AppColor.ink)),
        ],
      ),
    );
  }
}
