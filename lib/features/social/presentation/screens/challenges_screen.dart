import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/social_models.dart';
import '../social_providers.dart';
import '../widgets/social_widgets.dart';

/// Sfide 1 vs 1 (HEAT): record, NUOVA SFIDA (unico accento), richieste
/// ricevute e inviate, sfide in corso con tiro alla fune e tempo
/// rimasto, sfide concluse con RIVINCITA. Punteggi e chiusura sono
/// calcolati dal server (my_challenges, migrazione 0039).
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(challengesProvider);
    final me = ref.watch(authStateProvider).valueOrNull?.id ?? '';
    final myself = ref.watch(myProfileProvider).valueOrNull;
    final friends = {
      for (final f in ref.watch(friendsProvider).valueOrNull ?? const [])
        f.id: f.user,
    };
    final list = async.valueOrNull ?? const <Challenge>[];
    final now = DateTime.now();

    final incoming = [
      for (final c in list)
        if (c.incomingFor(me)) c
    ];
    final outgoing = [
      for (final c in list)
        if (c.outgoingFor(me)) c
    ];
    final live = [
      for (final c in list)
        if (c.status == ChallengeStatus.active) c,
    ];
    final done = [
      for (final c in list)
        if (c.status == ChallengeStatus.finished) c,
    ];
    final rec = recordOf(done, me);
    String name(String id) => friends[id]?.username ?? 'pilota';

    final children = <Widget>[
      const BackRow(),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ScreenTitle('Sfide\n1 vs 1', fontSize: 48),
                  const SizedBox(height: 6),
                  Text(
                      'sfida un amico su una metrica. chi fa meglio entro il '
                      'tempo vince la posta.',
                      style: AppType.text(
                          fontSize: 13, color: AppColor.inkMuted, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${rec.won}'),
                    const TextSpan(
                        text: ' – ',
                        style: TextStyle(color: AppColor.inkFaint)),
                    TextSpan(text: '${rec.lost}'),
                  ]),
                  style: AppType.display(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColor.ink),
                ),
                Text('VINTE – PERSE',
                    style: AppType.display(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        italic: false,
                        letterSpacing: 1.4,
                        color: AppColor.inkMuted)),
              ],
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
        child: HeatButton(
          label: 'NUOVA SFIDA',
          icon: Icons.sports_mma_rounded,
          height: 58,
          fontSize: 22,
          onPressed:
              async.hasError ? null : () => showNewChallengeSheet(context, ref),
        ),
      ),
    ];

    if (async.isLoading && list.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColor.ink)),
      ));
    } else if (async.hasError && list.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.fromLTRB(14, 18, 14, 0),
        child: EmptyNote('sfide non disponibili. trascina per riprovare.'),
      ));
    } else {
      if (incoming.isNotEmpty) {
        children.add(const _Label('Ricevute'));
        for (final c in incoming) {
          children.add(
              _Pad(_IncomingCard(challenge: c, from: name(c.challengerId))));
        }
      }
      if (outgoing.isNotEmpty) {
        children.add(const _Label('Inviate'));
        for (final c in outgoing) {
          children
              .add(_Pad(_OutgoingCard(challenge: c, to: name(c.opponentId))));
        }
      }
      children.add(_Label('In corso', trailing: '${live.length}'));
      if (live.isEmpty) {
        children.add(
            const _Pad(EmptyNote('nessuna sfida in corso. lanciane una.')));
      }
      for (final (i, c) in live.indexed) {
        children.add(HeatEnter(
          index: i,
          child: _Pad(_LiveCard(
            challenge: c,
            me: me,
            myself: myself,
            them: friends[c.otherId(me)],
            now: now,
          )),
        ));
      }
      if (done.isNotEmpty) {
        children.add(const _Label('Concluse'));
        for (final c in done.take(20)) {
          children.add(_Pad(_DoneRow(
            challenge: c,
            me: me,
            them: name(c.otherId(me)),
            now: now,
            onRematch: () => showNewChallengeSheet(context, ref,
                initialOpponentId: c.otherId(me),
                initialMetric: c.metric,
                initialHours: c.durationHours,
                initialStake: c.stakeXp),
          )));
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColor.ink,
            onRefresh: () => ref.refresh(challengesProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 36),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
        child: SectionLabel(text, trailing: trailing),
      );
}

class _Pad extends StatelessWidget {
  const _Pad(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: child,
      );
}

String _terms(Challenge c) =>
    '${c.metric.label} · ${c.durationLabel} · ${c.stakeXp} XP';

Future<void> _run(BuildContext context, Future<void> Function() op) async {
  try {
    await op();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(challengeErrorText(e))));
  }
}

class _IncomingCard extends ConsumerWidget {
  const _IncomingCard({required this.challenge, required this.from});
  final Challenge challenge;
  final String from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(challengesProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(left: BorderSide(color: AppColor.ink, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '@$from',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const TextSpan(text: ' ti sfida'),
            ]),
            style: AppType.text(fontSize: 15, color: AppColor.ink),
          ),
          const SizedBox(height: 2),
          Text(_terms(challenge),
              style: AppType.display(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  italic: false,
                  letterSpacing: 1.2,
                  color: AppColor.inkMuted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallButton(
                  label: 'RIFIUTA',
                  onTap: () => _run(
                      context, () => ctrl.respond(challenge.id, accept: false)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallButton(
                  label: 'ACCETTA',
                  filled: true,
                  onTap: () => _run(
                      context, () => ctrl.respond(challenge.id, accept: true)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutgoingCard extends ConsumerWidget {
  const _OutgoingCard({required this.challenge, required this.to});
  final Challenge challenge;
  final String to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      color: AppColor.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('in attesa di @$to',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.text(fontSize: 14, color: AppColor.ink)),
                Text(_terms(challenge),
                    style:
                        AppType.text(fontSize: 12, color: AppColor.inkMuted)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _run(
                context,
                () =>
                    ref.read(challengesProvider.notifier).cancel(challenge.id)),
            child: Text('RITIRA',
                style: AppType.display(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    italic: false,
                    letterSpacing: 1.2,
                    color: AppColor.inkMuted)),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return HeatPanel(
      onTap: onTap,
      shape: const SlantBorder.all(8),
      color: filled ? AppColor.ink : AppColor.surfaceHigh,
      borderColor: filled ? null : AppColor.line,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 40,
        child: Center(
          child: Text(label,
              style: AppType.display(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: filled ? AppColor.base : AppColor.ink)),
        ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.challenge,
    required this.me,
    required this.myself,
    required this.them,
    required this.now,
  });

  final Challenge challenge;
  final String me;
  final AppUser? myself;
  final AppUser? them;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final mine = c.myScore(me);
    final theirs = c.theirScore(me);
    final total = mine + theirs;
    final share = total <= 0 ? .5 : (mine / total).toDouble();
    final (status, color) = mine > theirs
        ? ('stai vincendo', AppColor.success)
        : mine < theirs
            ? ('stai perdendo', AppColor.danger)
            : ('pari', AppColor.inkMuted);

    Widget score(String value, String who, CrossAxisAlignment align) => Column(
          crossAxisAlignment: align,
          children: [
            Text(value,
                style: AppType.display(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: AppColor.ink)),
            Text(who,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.text(fontSize: 11, color: AppColor.inkMuted)),
          ],
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: ShapeDecoration(
        color: AppColor.surface,
        shape: ChamferBorder(cut: 14, side: BorderSide(color: color)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(c.metric.icon, size: 17, color: AppColor.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(c.metric.label,
                    style: AppType.display(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        italic: false,
                        letterSpacing: 1.6,
                        color: AppColor.inkMuted)),
              ),
              const Icon(Icons.timer_rounded,
                  size: 16, color: AppColor.inkMuted),
              const SizedBox(width: 4),
              Text(c.endsAt == null ? '—' : timeLeftLabel(c.endsAt!, now),
                  style: AppType.display(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      italic: false,
                      color: AppColor.inkMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (myself != null)
                PilotFace(user: myself!, size: 44, ring: AppColor.ink),
              const SizedBox(width: 10),
              Expanded(
                  child: score(
                      c.metric.format(mine), 'tu', CrossAxisAlignment.start)),
              Text('VS',
                  style: AppType.display(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColor.inkFaint)),
              Expanded(
                  child: score(
                      c.metric.format(theirs),
                      '@${them?.username ?? 'pilota'}',
                      CrossAxisAlignment.end)),
              const SizedBox(width: 10),
              if (them != null) PilotFace(user: them!, size: 44),
            ],
          ),
          const SizedBox(height: 12),
          // Tiro alla fune: la mia parte in chiaro, la sua spenta.
          SkewBar(
            value: share,
            height: 8,
            color: AppColor.ink,
            track: AppColor.lineMuted,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status,
                        style: AppType.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color)),
                    Text('IN PALIO ${c.stakeXp} XP',
                        style: AppType.display(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            italic: false,
                            letterSpacing: 1.2,
                            color: AppColor.gold)),
                  ],
                ),
              ),
              HeatPanel(
                onTap: () => context.push(AppRoutes.tripLive),
                shape: const SlantBorder.all(8),
                color: AppColor.surfaceHigh,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('GUIDA ORA',
                          style: AppType.display(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColor.ink)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_double_arrow_right_rounded,
                          size: 18, color: AppColor.ink),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({
    required this.challenge,
    required this.me,
    required this.them,
    required this.now,
    required this.onRematch,
  });

  final Challenge challenge;
  final String me;
  final String them;
  final DateTime now;
  final VoidCallback onRematch;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final (badge, color) = switch (c.outcomeFor(me)) {
      ChallengeOutcome.won => ('VINTA', AppColor.success),
      ChallengeOutcome.lost => ('PERSA', AppColor.danger),
      _ => ('PARI', AppColor.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColor.surface,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(badge,
                        style: AppType.display(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: color)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          '${c.metric.format(c.myScore(me))} – '
                          '${c.metric.format(c.theirScore(me))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.display(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              italic: false,
                              color: AppColor.ink)),
                    ),
                  ],
                ),
                Text(
                    '@$them · ${c.metric.label} · '
                    '${agoLabel(c.endsAt ?? c.createdAt, now).toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppType.text(fontSize: 12, color: AppColor.inkMuted)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onRematch,
            icon:
                const Icon(Icons.replay_rounded, size: 16, color: AppColor.ink),
            label: Text('RIVINCITA',
                style: AppType.display(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    italic: false,
                    letterSpacing: 1,
                    color: AppColor.ink)),
          ),
        ],
      ),
    );
  }
}

/// Foglio "NUOVA SFIDA": amico, metrica, durata, posta. Usato anche da
/// profilo amico (amico già scelto) e RIVINCITA (tutto già scelto).
Future<void> showNewChallengeSheet(
  BuildContext context,
  WidgetRef ref, {
  String? initialOpponentId,
  ChallengeMetric initialMetric = ChallengeMetric.flow,
  int initialHours = 24,
  int initialStake = 250,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColor.surfaceHigh,
    shape: const ChamferBorder(cut: 18),
    builder: (_) => _NewChallengeSheet(
      initialOpponentId: initialOpponentId,
      initialMetric: initialMetric,
      initialHours: initialHours,
      initialStake: initialStake,
    ),
  );
}

class _NewChallengeSheet extends ConsumerStatefulWidget {
  const _NewChallengeSheet({
    required this.initialOpponentId,
    required this.initialMetric,
    required this.initialHours,
    required this.initialStake,
  });

  final String? initialOpponentId;
  final ChallengeMetric initialMetric;
  final int initialHours;
  final int initialStake;

  @override
  ConsumerState<_NewChallengeSheet> createState() => _NewChallengeSheetState();
}

class _NewChallengeSheetState extends ConsumerState<_NewChallengeSheet> {
  late String? _opponent = widget.initialOpponentId;
  late ChallengeMetric _metric = widget.initialMetric;
  late int _hours = widget.initialHours;
  late int _stake = widget.initialStake;
  bool _sending = false;
  String? _error;

  Future<void> _launch() async {
    final opp = _opponent;
    if (opp == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(challengesProvider.notifier).create(
            opponentId: opp,
            metric: _metric,
            durationHours: _hours,
            stakeXp: _stake,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = challengeErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
    String? oppName;
    for (final f in friends) {
      if (f.id == _opponent) oppName = f.username;
    }

    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: SectionLabel(t),
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            18, 14, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('NUOVA SFIDA',
                      style: AppType.display(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColor.ink)),
                ),
                IconButton(
                  tooltip: 'chiudi',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColor.ink),
                ),
              ],
            ),
            label('Amico'),
            SizedBox(
              height: 78,
              child: friends.isEmpty
                  ? Text('nessun amico da sfidare.',
                      style:
                          AppType.text(fontSize: 13, color: AppColor.inkMuted))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: friends.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final f = friends[i];
                        final sel = f.id == _opponent;
                        return GestureDetector(
                          onTap: () => setState(() => _opponent = f.id),
                          child: SizedBox(
                            width: 58,
                            child: Column(
                              children: [
                                Opacity(
                                  opacity: sel || _opponent == null ? 1 : .55,
                                  child: PilotFace(
                                      user: f.user,
                                      size: 52,
                                      ring: sel ? AppColor.ink : null),
                                ),
                                const SizedBox(height: 4),
                                Text(f.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.text(
                                        fontSize: 11,
                                        fontWeight: sel
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: sel
                                            ? AppColor.ink
                                            : AppColor.inkMuted)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            label('Metrica'),
            _Options<ChallengeMetric>(
              values: ChallengeMetric.values,
              selected: _metric,
              labelOf: (m) => m.label,
              onSelect: (m) => setState(() => _metric = m),
            ),
            label('Durata'),
            _Options<int>(
              values: const [24, 72],
              selected: _hours,
              labelOf: (h) => h == 24 ? '24 H' : '3 GIORNI',
              onSelect: (h) => setState(() => _hours = h),
            ),
            label('In palio'),
            _Options<int>(
              values: const [100, 250, 500],
              selected: _stake,
              labelOf: (s) => '$s XP',
              onSelect: (s) => setState(() => _stake = s),
            ),
            const SizedBox(height: 8),
            Text(
                'vince chi fa meglio entro il tempo e prende la posta. chi '
                'perde non perde XP.',
                style: AppType.text(fontSize: 12, color: AppColor.inkMuted)),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: AppType.text(fontSize: 13, color: AppColor.danger)),
            ],
            const SizedBox(height: 16),
            HeatButton(
              label: _sending
                  ? 'UN ATTIMO…'
                  : oppName == null
                      ? 'SCEGLI UN AMICO'
                      : 'SFIDA @${oppName.toUpperCase()}',
              icon: null,
              height: 56,
              fontSize: 22,
              onPressed: _opponent == null || _sending ? null : _launch,
            ),
          ],
        ),
      ),
    );
  }
}

class _Options<T> extends StatelessWidget {
  const _Options({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, v) in values.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: HeatPanel(
              onTap: () => onSelect(v),
              shape: const SlantBorder.all(8),
              color: v == selected ? AppColor.ink : AppColor.surface,
              borderColor: v == selected ? null : AppColor.line,
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Text(labelOf(v),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.display(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: v == selected ? AppColor.base : AppColor.ink)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
