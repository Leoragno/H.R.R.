import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../../core/widgets/notification_bell_button.dart';
import '../../../../core/widgets/profile_avatar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rival/data/rivalry_tracker.dart';
import '../../../rival/presentation/providers/rival_controller_provider.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../providers/leaderboard_provider.dart';
import '../widgets/leaderboard_avatar.dart';
import '../widgets/rivalry_card.dart';

/// Classifica utenti, filtrabile per periodo (oggi/settimana/mese/sempre),
/// scope (globale o la propria crew) e metrica (XP/reputazione/km/velocità
/// massima) — la metrica scelta determina anche l'ordinamento lato server
/// in `leaderboard_global` (vedi [LeaderboardMetric]), cambiarla rifà
/// sempre la chiamata. "Classifica amici" (dal concept) resta fuori
/// scope: richiede il grafo amicizie, che non esiste ancora oggi — vedi
/// ARCHITECTURE.md Fase 3. Restyle secondo Guida.dc.html righe 341-404.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.week;
  LeaderboardScope _scope = LeaderboardScope.global;
  LeaderboardMetric _metric = LeaderboardMetric.xp;
  final _rivalryTracker = RivalryTracker();

  bool get _isCanonicalRivalry =>
      _metric == LeaderboardMetric.xp &&
      _period == LeaderboardPeriod.week &&
      _scope == LeaderboardScope.global;

  /// Rileva un sorpasso confrontando il rivale tracciato con la fetch
  /// fresca — solo alla visita della schermata (leaderboardProvider è già
  /// one-shot per visita, nessun polling/realtime aggiunto). Aggiorna
  /// comunque il tracker anche quando non scatta un festeggiamento, per
  /// evitare falsi positivi futuri.
  Future<void> _checkOvertake(List<LeaderboardEntry> list, String myId) async {
    final myIndex = list.indexWhere((e) => e.profileId == myId);
    if (myIndex == -1) return;

    final tracked = await _rivalryTracker.read(myId);
    if (tracked != null) {
      LeaderboardEntry? trackedNow;
      for (final e in list) {
        if (e.profileId == tracked.profileId) {
          trackedNow = e;
          break;
        }
      }
      final stillAbove =
          myIndex > 0 && list[myIndex - 1].profileId == tracked.profileId;
      if (!stillAbove &&
          trackedNow != null &&
          list[myIndex].rank < trackedNow.rank) {
        ref.read(rivalControllerProvider.notifier).announceOvertake(
              rivalName: trackedNow.displayName,
              newRank: trackedNow.rank,
            );
        unawaited(ref.read(supabaseClientProvider).rpc(
          'notify_leaderboard_overtake',
          params: {'p_victim_id': trackedNow.profileId},
        ));
      }
    }

    final newRivalAbove = myIndex > 0 ? list[myIndex - 1] : null;
    await _rivalryTracker.write(
      myId,
      newRivalAbove == null
          ? null
          : RivalrySnapshot(
              profileId: newRivalAbove.profileId,
              displayName: newRivalAbove.displayName,
              rank: newRivalAbove.rank,
            ),
    );
  }

  Future<void> _pickPeriod() async {
    final selected = await DraggableSheetScaffold.show<LeaderboardPeriod>(
      context,
      title: 'Periodo',
      builder: (ctx) => SheetOptionPicker<LeaderboardPeriod>(
        selected: _period,
        options: [
          for (final p in LeaderboardPeriod.values)
            SheetOption(value: p, label: p.label),
        ],
        onSelect: (_) {},
      ),
    );
    if (selected != null) setState(() => _period = selected);
  }

  Future<void> _pickScope() async {
    final selected = await DraggableSheetScaffold.show<LeaderboardScope>(
      context,
      title: 'Classifica',
      builder: (ctx) => SheetOptionPicker<LeaderboardScope>(
        selected: _scope,
        options: [
          for (final s in LeaderboardScope.values)
            SheetOption(value: s, label: s.label),
        ],
        onSelect: (_) {},
      ),
    );
    if (selected != null) setState(() => _scope = selected);
  }

  Future<void> _pickMetric() async {
    final selected = await DraggableSheetScaffold.show<LeaderboardMetric>(
      context,
      title: 'Metrica',
      builder: (ctx) => SheetOptionPicker<LeaderboardMetric>(
        selected: _metric,
        options: [
          for (final m in LeaderboardMetric.values)
            SheetOption(value: m, label: m.label),
        ],
        onSelect: (_) {},
      ),
    );
    if (selected != null) setState(() => _metric = selected);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(leaderboardProvider(_metric, _period, _scope));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    if (_isCanonicalRivalry && myId != null) {
      ref.listen<AsyncValue<List<LeaderboardEntry>>>(
        leaderboardProvider(_metric, _period, _scope),
        (previous, next) => next.whenData((list) => _checkOvertake(list, myId)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.guidaBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Classifiche',
                        style: AppTheme.archivo(
                          fontWeight: FontWeight.w900,
                          fontSize: 38,
                          color: AppColors.textPrimary,
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
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickPeriod,
                    child: Text(
                      _period.label,
                      style: AppTheme.archivo(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: AppColors.guidaTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 85,
                        child: _FilterPill(
                          icon: _scope == LeaderboardScope.global
                              ? Icons.public_rounded
                              : Icons.groups_rounded,
                          label: _scope.label,
                          onTap: _pickScope,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 115,
                        child: _FilterPill(
                          icon: _metric == LeaderboardMetric.speed
                              ? Icons.speed_rounded
                              : Icons.bar_chart_rounded,
                          label: _metric.label,
                          onTap: _pickMetric,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.guidaCyan)),
                error: (err, st) => Center(
                  child: Text('Errore: $err',
                      style: AppTheme.archivo(
                          color: AppColors.guidaTextSecondary)),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return _EmptyLeaderboard(scope: _scope);
                  }
                  LeaderboardEntry? mine;
                  for (final e in list) {
                    if (e.profileId == myId) {
                      mine = e;
                      break;
                    }
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                    children: [
                      if (_isCanonicalRivalry && myId != null)
                        RivalryCard(entries: list, myId: myId),
                      if (mine != null) ...[
                        _MyRankCard(entry: mine, metric: _metric),
                        const SizedBox(height: 14),
                      ],
                      _AddFriendsCard(
                          onTap: () => context.push(AppRoutes.friends)),
                      const SizedBox(height: 14),
                      for (final e in list)
                        _LeaderboardTile(
                          entry: e,
                          isMe: e.profileId == myId,
                          metric: _metric,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FilterPill({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE50C1120),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x33A0AAFF)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.guidaBlue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.archivo(
                      fontSize: 15, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFC9C9C9), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final LeaderboardMetric metric;
  const _MyRankCard({required this.entry, required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xDB121E3A),
        border: Border.all(color: AppColors.guidaBlue),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('${entry.rank}',
                textAlign: TextAlign.center,
                style: AppTheme.archivo(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 14),
          LeaderboardAvatar(
              url: entry.avatarUrl, size: 52, ringColor: AppColors.guidaCyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(entry.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.archivo(
                              fontSize: 20, color: AppColors.guidaCyan)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.guidaCyan.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('TU',
                          style: AppTheme.archivo(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.guidaCyan)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Lv.${entry.level}',
                    style: AppTheme.archivo(
                        fontSize: 16, color: const Color(0xFF75879E))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                switch (metric) {
                  LeaderboardMetric.xp => '${entry.periodXp}',
                  LeaderboardMetric.rep => '${entry.periodRep}',
                  LeaderboardMetric.km => entry.totalKm.toStringAsFixed(0),
                  LeaderboardMetric.speed =>
                    entry.topSpeedKmh.toStringAsFixed(0),
                },
                style: AppTheme.archivo(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: const Color(0xFFFFC93C)),
              ),
              Text(
                  switch (metric) {
                    LeaderboardMetric.xp => 'XP',
                    LeaderboardMetric.rep => 'REP',
                    LeaderboardMetric.km => 'km',
                    LeaderboardMetric.speed => 'km/h',
                  },
                  style: AppTheme.archivo(
                      fontSize: 14, color: const Color(0xFF75879E))),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddFriendsCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFriendsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE50A0E1A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x29A0C8FF)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.guidaBlue.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_alt_rounded,
                    color: AppColors.guidaCyan),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aggiungi amici',
                        style: AppTheme.archivo(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Aggiungi amici per competere con loro!',
                        style: AppTheme.archivo(
                            fontSize: 15, color: const Color(0xFF75879E))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.guidaTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final LeaderboardMetric metric;
  const _LeaderboardTile(
      {required this.entry, required this.isMe, required this.metric});

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (entry.rank) {
      1 => const Color(0xFFFFC93C),
      2 => const Color(0xFFDFE4EA),
      3 => const Color(0xFFFF8A1F),
      _ => AppColors.textPrimary,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.guidaCyan.withValues(alpha: 0.08)
            : const Color(0xE50A0E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppColors.guidaCyan.withValues(alpha: 0.6)
              : const Color(0x29A0C8FF),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              _medals[entry.rank] ?? '#${entry.rank}',
              style: AppTheme.archivo(
                  fontSize: entry.rank <= 3 ? 20 : 14,
                  fontWeight: FontWeight.w800,
                  color: entry.rank <= 3
                      ? AppColors.textPrimary
                      : AppColors.guidaTextSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          LeaderboardAvatar(url: entry.avatarUrl, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: AppTheme.archivo(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Lv.${entry.level} · @${entry.username}',
                  style: AppTheme.archivo(
                      color: AppColors.guidaTextSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            switch (metric) {
              LeaderboardMetric.xp => '${entry.periodXp} XP',
              LeaderboardMetric.rep => '${entry.periodRep} REP',
              LeaderboardMetric.km => '${entry.totalKm.toStringAsFixed(0)} km',
              LeaderboardMetric.speed =>
                '${entry.topSpeedKmh.toStringAsFixed(0)} km/h',
            },
            style: AppTheme.archivo(
                color: accentColor, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  final LeaderboardScope scope;
  const _EmptyLeaderboard({required this.scope});

  @override
  Widget build(BuildContext context) {
    final message = scope == LeaderboardScope.crew
        ? 'Nessun dato per la tua crew in questo periodo — oppure non fai\nancora parte di una crew.'
        : 'Nessun pilota in classifica per questo periodo.\nGuida, avvista auto e sali di livello!';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 48, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.archivo(
                  color: AppColors.guidaTextSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
