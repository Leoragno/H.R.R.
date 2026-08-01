import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/hrr_icons.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/crew_mission.dart' as domain;
import '../../domain/entities/mission.dart' as domain;
import '../../domain/entities/mission_progress.dart' as domain;
import '../providers/mission_controller.dart';
import '../providers/mission_provider.dart';

enum _MissionTab { daily, weekly, season, secret }

enum _MissionState { inProgress, ready, claimed }

class _Reward {
  final String label;
  final Color color;
  const _Reward(this.label, this.color);
}

class _Mission {
  final String id;
  final IconData icon;
  final String title;
  final String desc;
  final double progress; // 0..1
  final String progressLabel;
  final _MissionState state;
  final List<_Reward> rewards;

  const _Mission({
    required this.id,
    required this.icon,
    required this.title,
    required this.desc,
    required this.progress,
    required this.progressLabel,
    required this.state,
    required this.rewards,
  });
}

class _PassTier {
  final int level;
  final IconData icon;
  final String reward;
  final bool unlocked;
  const _PassTier(this.level, this.icon, this.reward, this.unlocked);
}

class _SecretMission {
  final String title;
  final String desc;
  final String reward;
  final bool revealed;
  const _SecretMission(
      {required this.title,
      required this.desc,
      required this.reward,
      required this.revealed});
}

class _CrewMission {
  final String title;
  final String reward;
  final double progress;
  final String progressLabel;
  const _CrewMission(
      this.title, this.reward, this.progress, this.progressLabel);
}

class _EventCard {
  final String name;
  final String timeLeft;
  final int players;
  final String reward;
  final List<Color> art;
  const _EventCard(
      this.name, this.timeLeft, this.players, this.reward, this.art);
}

// ---- Reward token colors (mission chips only — not global design tokens) ----
const _rewardTitle = Color(0xFFFF9EC4); // pink
const _rewardFrame = Color(0xFF4FA8FF); // light blue

// Icona logica (missions.icon, stringa in DB) -> IconData Flutter. Mappa
// condivisa con achievements_screen.dart, vedi core/theme/hrr_icons.dart.
IconData _iconFor(String key) =>
    hrrIconByKey[key] ?? Icons.track_changes_rounded;

// ---- Mapper: entità di dominio (Mission/MissionProgress) -> view-model UI ----
// Vive qui perché _Mission/_Reward/ecc sono private al file: nessun altro
// punto può costruirle. Nessuna modifica alla grafica, solo alla sorgente dati.

List<_Reward> _rewardsFor(domain.Mission m) {
  final list = <_Reward>[];
  if (m.rewardRep > 0)
    list.add(_Reward('REP +${m.rewardRep}', AppColors.neonCyan));
  if (m.rewardXp > 0)
    list.add(_Reward('XP +${m.rewardXp}', AppColors.neonPurple));
  if (m.rewardBadgeIds.isNotEmpty)
    list.add(const _Reward('BADGE', AppColors.neonAmber));
  if (m.rewardTitles.isNotEmpty) list.add(_Reward('TITOLO', _rewardTitle));
  if (m.rewardAvatarFrame != null) list.add(_Reward('FRAME', _rewardFrame));
  for (final key in m.rewardProfileItems.keys) {
    list.add(_Reward(key.toUpperCase(), AppColors.neonGreen));
  }
  return list;
}

_MissionState _stateFor(
    domain.Mission m, domain.MissionProgress? p, Set<String> claimedIds) {
  if (claimedIds.contains(m.id)) return _MissionState.claimed;
  if (p?.completed == true) return _MissionState.ready;
  return _MissionState.inProgress;
}

double _progressFor(domain.Mission m, domain.MissionProgress? p) {
  if (m.targetValue <= 0) return 0;
  return ((p?.currentValue ?? 0) / m.targetValue).clamp(0, 1);
}

String _progressLabelFor(
    domain.Mission m, domain.MissionProgress? p, bool claimed) {
  if (claimed) return 'Riscattata';
  if (p?.completed == true) return 'Completata';
  final current = p?.currentValue ?? 0;
  final isKm = m.targetMetric == 'trip_completed';
  final currentStr =
      isKm ? current.toStringAsFixed(1) : current.toStringAsFixed(0);
  final targetStr = m.targetValue.toStringAsFixed(0);
  return isKm ? '$currentStr / $targetStr km' : '$currentStr / $targetStr';
}

_Mission _toUiMission(
    domain.Mission m, domain.MissionProgress? p, Set<String> claimedIds) {
  final claimed = claimedIds.contains(m.id);
  return _Mission(
    id: m.id,
    icon: _iconFor(m.icon),
    title: m.title,
    desc: m.description,
    progress: _progressFor(m, p),
    progressLabel: _progressLabelFor(m, p, claimed),
    state: _stateFor(m, p, claimedIds),
    rewards: _rewardsFor(m),
  );
}

String _secretRewardLabel(domain.Mission m) {
  if (m.rewardTitles.isNotEmpty) return 'TITOLO · ${m.rewardTitles.first}';
  if (m.rewardBadgeIds.isNotEmpty) return 'BADGE raro';
  if (m.rewardRep > 0) return 'REP +${m.rewardRep}';
  return '???';
}

_SecretMission _toUiSecretMission(domain.Mission m) => _SecretMission(
      title: m.title,
      desc: m.description,
      reward: _secretRewardLabel(m),
      revealed:
          true, // RLS restituisce solo le secret già completate dall'utente
    );

String _formatXp(int xp) =>
    xp >= 1000 ? '${(xp / 1000).toStringAsFixed(1)}k' : '$xp';

_CrewMission _toUiCrewMission(domain.CrewMission c) {
  final rewardParts = <String>[
    if (c.rewardRep > 0) 'REP +${c.rewardRep}',
    if (c.rewardXp > 0) 'XP +${c.rewardXp}',
  ];
  final progress = c.targetValue <= 0
      ? 0.0
      : (c.currentValue / c.targetValue).clamp(0, 1).toDouble();
  return _CrewMission(
    c.title,
    rewardParts.isEmpty ? '—' : rewardParts.join(' · '),
    progress,
    '${c.currentValue.toStringAsFixed(0)} / ${c.targetValue.toStringAsFixed(0)}',
  );
}

// ---- Dati ancora statici in questo giro: Battle Pass (nessun sistema di
// sblocco tier costruito) ed Eventi (feature Eventi ancora placeholder,
// nessuna sorgente dati reale a cui collegarsi). Crew Missions è invece
// collegata a crewMissionsProvider — vuota finché profiles.crew_id è null. ----

const _passTiers = [
  _PassTier(15, Icons.bolt_rounded, 'REP +100', true),
  _PassTier(16, Icons.local_fire_department_rounded, 'XP +80', true),
  _PassTier(17, Icons.emoji_events_rounded, 'Badge', true),
  _PassTier(18, Icons.diamond_rounded, 'Skin', false),
  _PassTier(19, Icons.shield_rounded, 'Frame', false),
  _PassTier(20, Icons.star_rounded, 'Titolo raro', false),
];

const _eventStrip = [
  _EventCard('Night Run', '2h 10m', 84, 'REP +400',
      [Color(0xFF7C3AED), Color(0xFFFF2D95)]),
  _EventCard('Westside Drive', '5h 40m', 51, 'REP +250',
      [Color(0xFF22D3EE), Color(0xFF0A7EA4)]),
  _EventCard('Daily Challenge', '11h 02m', 212, 'REP +80',
      [Color(0xFFFFB020), Color(0xFFFF2D95)]),
];

class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  _MissionTab _tab = _MissionTab.daily;
  _Mission? _celebrating;

  domain.MissionType? get _activeType => switch (_tab) {
        _MissionTab.daily => domain.MissionType.daily,
        _MissionTab.weekly => domain.MissionType.weekly,
        _MissionTab.season => domain.MissionType.seasonal,
        _MissionTab.secret => null,
      };

  Map<String, domain.MissionProgress> _progressByMissionId() {
    final progress = ref.watch(myMissionProgressProvider).valueOrNull ??
        const <domain.MissionProgress>[];
    return {for (final p in progress) p.missionId: p};
  }

  Set<String> _claimedIds() =>
      (ref.watch(myClaimedMissionIdsProvider).valueOrNull ?? const <String>[])
          .toSet();

  List<_Mission> get _activeList {
    final type = _activeType;
    if (type == null) return const [];
    final missions =
        ref.watch(activeMissionsProvider(type: type)).valueOrNull ??
            const <domain.Mission>[];
    final progressByMissionId = _progressByMissionId();
    final claimedIds = _claimedIds();
    return missions
        .map((m) => _toUiMission(m, progressByMissionId[m.id], claimedIds))
        .toList();
  }

  List<_SecretMission> get _secretMissionsList {
    final revealed = ref
            .watch(activeMissionsProvider(type: domain.MissionType.secret))
            .valueOrNull ??
        const <domain.Mission>[];
    final totalSlots = ref.watch(secretMissionSlotCountProvider).valueOrNull ??
        revealed.length;
    final lockedCount = (totalSlots - revealed.length).clamp(0, totalSlots);
    return [
      ...revealed.map(_toUiSecretMission),
      for (var i = 0; i < lockedCount; i++)
        const _SecretMission(
            title: '???', desc: '', reward: '???', revealed: false),
    ];
  }

  int get _progressPct {
    final daily = ref
            .watch(activeMissionsProvider(type: domain.MissionType.daily))
            .valueOrNull ??
        const <domain.Mission>[];
    final weekly = ref
            .watch(activeMissionsProvider(type: domain.MissionType.weekly))
            .valueOrNull ??
        const <domain.Mission>[];
    final seasonal = ref
            .watch(activeMissionsProvider(type: domain.MissionType.seasonal))
            .valueOrNull ??
        const <domain.Mission>[];
    final all = [...daily, ...weekly, ...seasonal];
    if (all.isEmpty) return 0;
    final claimedIds = _claimedIds();
    final done = all.where((m) => claimedIds.contains(m.id)).length;
    return ((done / all.length) * 100).round().clamp(0, 100);
  }

  Future<void> _claim(_Mission mission) async {
    if (mission.state != _MissionState.ready) return;
    final claim =
        await ref.read(missionControllerProvider.notifier).claim(mission.id);
    if (claim == null || !mounted) return;
    setState(() => _celebrating = mission);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final season = ref.watch(activeSeasonProvider).valueOrNull;
    final daysLeft = season == null
        ? 0
        : season.endsAt.difference(DateTime.now()).inDays.clamp(0, 999);

    // Nessuna crew reale collegata: mostra la sezione vuota invece di
    // inventare progressi per una crew a cui l'utente non appartiene.
    final crewId = profile?.crewId;
    final crewMissionsList = crewId == null
        ? const <_CrewMission>[]
        : (ref.watch(crewMissionsProvider(crewId)).valueOrNull ??
                const <domain.CrewMission>[])
            .map(_toUiCrewMission)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    progressPct: _progressPct,
                    seasonName: season?.name ?? '—',
                    seasonLevel: profile?.level ?? 0,
                    xpLabel: _formatXp(profile?.xp ?? 0),
                    daysLeft: daysLeft,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TabBar(
                      current: _tab,
                      onChanged: (t) => setState(() => _tab = t)),
                ),
                if (_tab == _MissionTab.season)
                  SliverToBoxAdapter(
                      child: _BattlePassTrack(tiers: _passTiers)),
                if (_tab != _MissionTab.secret)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: _activeList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 11),
                      itemBuilder: (context, i) => _MissionCard(
                          mission: _activeList[i], onClaim: _claim),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: _SecretMissionsList(missions: _secretMissionsList),
                  ),
                SliverToBoxAdapter(
                    child: _CrewMissionsSection(missions: crewMissionsList)),
                SliverToBoxAdapter(child: _EventsStrip(events: _eventStrip)),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          ),
          if (_celebrating != null)
            _CelebrationOverlay(
                mission: _celebrating!,
                onClose: () => setState(() => _celebrating = null)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int progressPct;
  final String seasonName;
  final int seasonLevel;
  final String xpLabel;
  final int daysLeft;
  const _Header({
    required this.progressPct,
    required this.seasonName,
    required this.seasonLevel,
    required this.xpLabel,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.7, -1),
          radius: 1.4,
          colors: [Color(0x4D7C3AED), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                              colors: [Colors.white, AppColors.neonCyan])
                          .createShader(b),
                      child: Text(
                        'MISSIONS',
                        style: AppTheme.orbitron(
                            fontWeight: FontWeight.w900,
                            fontSize: 27,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      seasonName.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'MISSION PROGRESS',
                    style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary),
                  ),
                  Text(
                    '$progressPct%',
                    style: AppTheme.orbitron(
                        fontWeight: FontWeight.w800,
                        fontSize: 23,
                        color: AppColors.neonCyan),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressPct / 100,
              minHeight: 9,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.neonCyan),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HudChip(
                    label: 'SEASON LEVEL',
                    value: 'LV $seasonLevel',
                    color: AppColors.neonPurple),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: _HudChip(
                      label: 'XP', value: xpLabel, color: AppColors.neonCyan)),
              const SizedBox(width: 8),
              Expanded(
                child: _HudChip(
                    label: 'SEASON END',
                    value: '$daysLeft giorni',
                    color: AppColors.neonMagenta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HudChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 7.5,
                  letterSpacing: 1.2,
                  color: color.withOpacity(0.85))),
          const SizedBox(height: 2),
          Text(value,
              style: AppTheme.orbitron(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final _MissionTab current;
  final ValueChanged<_MissionTab> onChanged;
  const _TabBar({required this.current, required this.onChanged});

  static const _labels = {
    _MissionTab.daily: 'DAILY',
    _MissionTab.weekly: 'WEEKLY',
    _MissionTab.season: 'SEASON',
    _MissionTab.secret: 'SECRET',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          for (final tab in _MissionTab.values) ...[
            if (tab != _MissionTab.daily) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: current == tab
                        ? AppColors.neonCyan.withOpacity(0.16)
                        : AppColors.surfaceGlass,
                    border: Border.all(
                      color: current == tab
                          ? AppColors.neonCyan.withOpacity(0.6)
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    _labels[tab]!,
                    style: AppTheme.orbitron(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: current == tab
                          ? AppColors.neonCyan
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BattlePassTrack extends StatelessWidget {
  final List<_PassTier> tiers;
  const _BattlePassTrack({required this.tiers});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BATTLE PASS · TRACK',
            style: TextStyle(
                fontSize: 8.5,
                letterSpacing: 1.8,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: tiers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = tiers[i];
                final color =
                    t.unlocked ? AppColors.neonCyan : AppColors.textDisabled;
                return Container(
                  width: 78,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: t.unlocked
                        ? AppColors.neonCyan.withOpacity(0.12)
                        : AppColors.surfaceGlass,
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('LV ${t.level}',
                          style: const TextStyle(
                              fontSize: 7.5, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          color: color.withOpacity(0.18),
                        ),
                        child: Icon(t.icon, size: 18, color: color),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        t.reward,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                            height: 1.1),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final _Mission mission;
  final ValueChanged<_Mission> onClaim;
  const _MissionCard({required this.mission, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final (stateLabel, stateColor) = switch (mission.state) {
      _MissionState.inProgress => ('IN CORSO', AppColors.textSecondary),
      _MissionState.ready => ('PRONTA', AppColors.neonAmber),
      _MissionState.claimed => ('COMPLETATA', AppColors.neonGreen),
    };
    final ready = mission.state == _MissionState.ready;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: ready
            ? AppColors.neonAmber.withOpacity(0.08)
            : AppColors.surfaceGlass,
        border: Border.all(
            color: ready
                ? AppColors.neonAmber.withOpacity(0.4)
                : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: AppColors.neonCyan.withOpacity(0.12),
              border: Border.all(color: AppColors.neonCyan.withOpacity(0.3)),
            ),
            child: Icon(mission.icon, color: AppColors.neonCyan, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mission.title,
                        style: AppTheme.orbitron(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                    Text(
                      stateLabel,
                      style: TextStyle(
                          fontSize: 8.5,
                          letterSpacing: 1,
                          color: stateColor,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(mission.desc,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: mission.progress,
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation(
                        ready ? AppColors.neonAmber : AppColors.neonCyan),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mission.progressLabel,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (mission.state != _MissionState.claimed)
                      GestureDetector(
                        onTap: () => onClaim(mission),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: ready
                                ? const LinearGradient(colors: [
                                    AppColors.neonAmber,
                                    Color(0xFFFFE9A3)
                                  ])
                                : null,
                            color: ready ? null : AppColors.surfaceElevated,
                            border: Border.all(
                                color: ready
                                    ? AppColors.neonAmber
                                    : AppColors.border),
                          ),
                          child: Text(
                            ready ? 'RISCATTA' : 'IN CORSO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  ready ? Colors.black : AppColors.textDisabled,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (mission.rewards.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in mission.rewards)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            color: r.color.withOpacity(0.14),
                            border: Border.all(color: r.color.withOpacity(0.4)),
                          ),
                          child: Text(
                            r.label,
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9.5,
                                color: r.color),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecretMissionsList extends StatelessWidget {
  final List<_SecretMission> missions;
  const _SecretMissionsList({required this.missions});

  @override
  Widget build(BuildContext context) {
    final foundCount = missions.where((m) => m.revealed).length;
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'SBLOCCATE $foundCount / ${missions.length} · LE SEGRETE APPAIONO SOLO QUANDO LE COMPLETI',
            style: const TextStyle(
                fontSize: 8.5,
                letterSpacing: 1.5,
                color: AppColors.textSecondary),
          ),
        ),
        for (final m in missions) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: m.revealed
                  ? AppColors.neonPurple.withOpacity(0.1)
                  : AppColors.surfaceGlass,
              border: Border.all(
                  color: m.revealed
                      ? AppColors.neonPurple.withOpacity(0.4)
                      : AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: (m.revealed
                            ? AppColors.neonPurple
                            : AppColors.textDisabled)
                        .withOpacity(0.16),
                  ),
                  child: Icon(
                    m.revealed
                        ? Icons.auto_awesome_rounded
                        : Icons.lock_rounded,
                    size: 21,
                    color: m.revealed
                        ? AppColors.neonPurple
                        : AppColors.textDisabled,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.revealed ? m.title : '??? MISSIONE SEGRETA',
                        style: AppTheme.orbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: m.revealed
                              ? Colors.white
                              : AppColors.textDisabled,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.revealed
                            ? m.desc
                            : 'Sblocca completandola in viaggio per scoprirla',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        m.reward,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          color: m.revealed
                              ? AppColors.neonAmber
                              : AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

class _CrewMissionsSection extends StatelessWidget {
  final List<_CrewMission> missions;
  const _CrewMissionsSection({required this.missions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CREW MISSIONS',
                style: AppTheme.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(AppRoutes.crew),
                child: const Text(
                  'Night Phantoms ›',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neonPurple,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final c in missions)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: [
                  AppColors.neonPurple.withOpacity(0.2),
                  AppColors.surfaceGlass
                ]),
                border:
                    Border.all(color: AppColors.neonPurple.withOpacity(0.32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        c.reward,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            color: Color(0xFFC9B8FF)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: c.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.neonMagenta),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.progressLabel,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EventsStrip extends StatelessWidget {
  final List<_EventCard> events;
  const _EventsStrip({required this.events});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'EVENTI LIVE',
                style: AppTheme.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(AppRoutes.events),
                child: const Text(
                  'Tutti ›',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neonGreen,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 144,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final e = events[i];
                return GestureDetector(
                  onTap: () => context.push(AppRoutes.events),
                  child: Container(
                    width: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: AppColors.surfaceGlass,
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 66,
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: e.art)),
                          padding: const EdgeInsets.all(7),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                e.timeLeft,
                                style: const TextStyle(
                                    fontSize: 8, color: Color(0xFFFFE9A3)),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.orbitron(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text('${e.players} piloti',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Text(
                                e.reward,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 9.5,
                                    color: AppColors.neonCyan),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationOverlay extends StatelessWidget {
  final _Mission mission;
  final VoidCallback onClose;
  const _CelebrationOverlay({required this.mission, required this.onClose});

  int get _rep {
    final repReward = mission.rewards.firstWhere(
      (r) => r.label.startsWith('REP'),
      orElse: () => const _Reward('REP +50', AppColors.neonCyan),
    );
    return int.tryParse(
            RegExp(r'\d+').firstMatch(repReward.label)?.group(0) ?? '50') ??
        50;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.82),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [
                    AppColors.neonCyan,
                    AppColors.neonPurple,
                    AppColors.neonMagenta
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.neonPurple.withOpacity(0.7),
                      blurRadius: 44)
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  size: 46, color: Colors.black),
            ),
            const SizedBox(height: 18),
            const Text(
              'MISSION COMPLETE',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 4,
                  color: AppColors.neonGreen),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                mission.title,
                textAlign: TextAlign.center,
                style: AppTheme.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '+$_rep',
              style: AppTheme.orbitron(
                  fontWeight: FontWeight.w900,
                  fontSize: 44,
                  color: Colors.white),
            ),
            const Text(
              'REP',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 3,
                  color: AppColors.neonCyan),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                alignment: WrapAlignment.center,
                children: [
                  for (final r in mission.rewards)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: r.color.withOpacity(0.16),
                        border: Border.all(color: r.color.withOpacity(0.5)),
                      ),
                      child: Text(r.label,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: r.color)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            GestureDetector(
              onTap: onClose,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                      colors: [AppColors.neonPurple, AppColors.neonCyan]),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.neonCyan.withOpacity(0.5),
                        blurRadius: 28)
                  ],
                ),
                child: Text(
                  'CONTINUA',
                  style: AppTheme.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
