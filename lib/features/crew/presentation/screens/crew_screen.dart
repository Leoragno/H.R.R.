import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../../../../core/widgets/notification_bell_button.dart';
import '../../../../core/widgets/profile_avatar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../game/domain/entities/territory_standing.dart';
import '../../../game/presentation/providers/territory_provider.dart';
import '../../../missions/domain/entities/crew_mission.dart';
import '../../../missions/presentation/providers/mission_provider.dart';
import '../../domain/entities/crew.dart';
import '../../domain/entities/crew_member.dart';
import '../providers/crew_provider.dart';

/// Tab "Crew": se l'utente non ne fa parte, sfoglia/crea/entra; altrimenti
/// mostra la sua crew (membri, ruoli, missioni e territorio di crew — le
/// ultime due già cablate altrove, riusate qui). Nessun mockup di
/// riferimento per questa schermata (vedi ARCHITECTURE.md): costruita sui
/// token del design "Guida" e sugli stessi pattern di leaderboard/game.
class CrewScreen extends ConsumerWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.guidaBg,
      body: SafeArea(
        child: profile == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.guidaCyan))
            : profile.crewId == null
                ? const _BrowseCrewsView()
                : _CrewDetailView(
                    crewId: profile.crewId!, myProfileId: profile.id),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Nessuna crew: sfoglia / crea / entra
// ---------------------------------------------------------------------

class _BrowseCrewsView extends ConsumerWidget {
  const _BrowseCrewsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crewsAsync = ref.watch(browseCrewsProvider);
    final actionState = ref.watch(crewActionsControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Crew',
                style: AppTheme.archivo(
                    fontWeight: FontWeight.w900,
                    fontSize: 38,
                    color: AppColors.textPrimary),
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
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: NeonCtaButton(
            label: 'Crea una crew',
            icon: Icons.add_rounded,
            onPressed: actionState.isLoading
                ? null
                : () => DraggableSheetScaffold.show<void>(
                      context,
                      title: 'Crea una crew',
                      builder: (ctx) => const _CreateCrewForm(),
                    ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          child: Text(
            'Oppure entra in una crew esistente',
            style: AppTheme.archivo(
                fontSize: 14, color: AppColors.guidaTextSecondary),
          ),
        ),
        Expanded(
          child: crewsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.guidaCyan)),
            error: (e, _) => Center(
              child: Text('Impossibile caricare le crew',
                  style:
                      AppTheme.archivo(color: AppColors.guidaTextSecondary)),
            ),
            data: (crews) {
              if (crews.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Nessuna crew esiste ancora. Sii il primo a crearne una!',
                      textAlign: TextAlign.center,
                      style: AppTheme.archivo(
                          color: AppColors.guidaTextSecondary),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                itemCount: crews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _CrewBrowseTile(crew: crews[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CrewBrowseTile extends ConsumerWidget {
  final Crew crew;
  const _CrewBrowseTile({required this.crew});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(crewActionsControllerProvider);
    return GlassCard(
      child: Row(
        children: [
          _CrewEmblem(url: crew.emblemUrl, tag: crew.tag, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crew.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.archivo(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text('[${crew.tag}]',
                    style: AppTheme.archivo(
                        fontSize: 13, color: AppColors.guidaTextSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          NeonCtaButton(
            label: 'Entra',
            minHeight: 40,
            fontSize: 13,
            onPressed: actionState.isLoading
                ? null
                : () => ref
                    .read(crewActionsControllerProvider.notifier)
                    .join(crew.id),
          ),
        ],
      ),
    );
  }
}

class _CreateCrewForm extends ConsumerStatefulWidget {
  const _CreateCrewForm();

  @override
  ConsumerState<_CreateCrewForm> createState() => _CreateCrewFormState();
}

class _CreateCrewFormState extends ConsumerState<_CreateCrewForm> {
  final _nameCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final tag = _tagCtrl.text.trim().toUpperCase();
    if (name.length < 3) {
      setState(() => _error = 'Il nome deve avere almeno 3 caratteri');
      return;
    }
    if (tag.length < 2 || tag.length > 6) {
      setState(() => _error = 'Il tag deve avere fra 2 e 6 caratteri');
      return;
    }
    setState(() => _error = null);

    final notifier = ref.read(crewActionsControllerProvider.notifier);
    await notifier.createCrew(
      name: name,
      tag: tag,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ref.read(crewActionsControllerProvider).hasError) {
      setState(() => _error = 'Creazione fallita: nome o tag già in uso?');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(crewActionsControllerProvider).isLoading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTextField(controller: _nameCtrl, label: 'Nome crew', maxLength: 24),
        const SizedBox(height: 12),
        _SheetTextField(
            controller: _tagCtrl, label: 'Tag (2-6 caratteri)', maxLength: 6),
        const SizedBox(height: 12),
        _SheetTextField(
          controller: _descCtrl,
          label: 'Descrizione (opzionale)',
          maxLines: 3,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: AppTheme.archivo(color: AppColors.danger, fontSize: 13)),
        ],
        const SizedBox(height: 18),
        NeonCtaButton(
          label: loading ? 'Creazione...' : 'Crea crew',
          onPressed: loading ? null : _submit,
        ),
      ],
    );
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int? maxLength;
  final int maxLines;
  const _SheetTextField({
    required this.controller,
    required this.label,
    this.maxLength,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: AppTheme.archivo(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.archivo(color: AppColors.guidaTextSecondary),
        filled: true,
        fillColor: const Color(0xFF0E1424),
        counterStyle: AppTheme.archivo(
            color: AppColors.guidaTextSecondary, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.guidaCyan),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// In una crew: membri, ruoli, missioni e territorio
// ---------------------------------------------------------------------

class _CrewDetailView extends ConsumerWidget {
  final String crewId;
  final String myProfileId;
  const _CrewDetailView({required this.crewId, required this.myProfileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crewAsync = ref.watch(myCrewProvider);
    final membersAsync = ref.watch(crewMembersProvider(crewId));
    final actionState = ref.watch(crewActionsControllerProvider);
    final territoryAsync =
        ref.watch(territoryStandingsProvider(TerritoryScope.crew));
    final crewMissionsAsync = ref.watch(crewMissionsProvider(crewId));
    final votersAsync = ref.watch(crewDisbandVotersProvider(crewId));

    return crewAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.guidaCyan)),
      error: (e, _) => Center(
        child: Text('Impossibile caricare la crew',
            style: AppTheme.archivo(color: AppColors.guidaTextSecondary)),
      ),
      data: (crew) {
        // profiles.crew_id punta a una crew non ancora arrivata da questo
        // fetch (o cancellata): un breve loader finché non si allinea.
        if (crew == null) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.guidaCyan));
        }

        final members = membersAsync.valueOrNull ?? const <CrewMember>[];
        CrewMember? me;
        for (final m in members) {
          if (m.profileId == myProfileId) {
            me = m;
            break;
          }
        }
        final isOwner = me?.role == CrewRole.owner;
        final totalAreaKm2 = (territoryAsync.valueOrNull ?? const [])
            .fold<double>(0, (sum, s) => sum + s.areaKm2);
        final voters = votersAsync.valueOrNull ?? const <String>[];
        final voteActive = voters.isNotEmpty;
        final iHaveVoted = voters.contains(myProfileId);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    crew.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.archivo(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        color: AppColors.textPrimary),
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
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CrewEmblem(url: crew.emblemUrl, tag: crew.tag, size: 60),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('[${crew.tag}]',
                                style: AppTheme.archivo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.guidaCyan)),
                            if (crew.description != null &&
                                crew.description!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(crew.description!,
                                  style: AppTheme.archivo(
                                      fontSize: 13,
                                      color: AppColors.guidaTextSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _StatPill(
                            label: 'Membri', value: '${members.length}'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatPill(
                          label: 'Territorio (30gg)',
                          value: '${totalAreaKm2.toStringAsFixed(2)} km²',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (voteActive) ...[
              const SizedBox(height: 16),
              _DisbandVoteBanner(
                crewId: crewId,
                votesCount: voters.length,
                membersCount: members.length,
                iHaveVoted: iHaveVoted,
                loading: actionState.isLoading,
              ),
            ],
            const SizedBox(height: 22),
            Text('MEMBRI',
                style: AppTheme.archivo(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.guidaTextSecondary,
                    letterSpacing: 1)),
            const SizedBox(height: 10),
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.guidaCyan)),
              ),
              error: (e, _) => Text('Impossibile caricare i membri',
                  style:
                      AppTheme.archivo(color: AppColors.guidaTextSecondary)),
              data: (list) => Column(
                children: [
                  for (final m in list)
                    _MemberTile(
                      member: m,
                      isMe: m.profileId == myProfileId,
                      canManage: isOwner && m.profileId != myProfileId,
                      crewId: crewId,
                      hasVoted: voters.contains(m.profileId),
                    ),
                ],
              ),
            ),
            if ((crewMissionsAsync.valueOrNull ?? const []).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('MISSIONI DI CREW',
                  style: AppTheme.archivo(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.guidaTextSecondary,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              for (final mission in crewMissionsAsync.value!)
                _CrewMissionTile(mission: mission),
            ],
            const SizedBox(height: 22),
            if (!isOwner)
              _DangerButton(
                label: 'Abbandona crew',
                onPressed: actionState.isLoading
                    ? null
                    : () => _confirmLeave(context, ref, crewId),
              )
            else if (members.length == 1)
              _DangerButton(
                label: 'Elimina crew',
                onPressed: actionState.isLoading
                    ? null
                    : () => _confirmDisband(context, ref, crewId, members),
              )
            else
              Column(
                children: [
                  _DangerButton(
                    label: 'Abbandona crew',
                    outlined: true,
                    onPressed: actionState.isLoading
                        ? null
                        : () => _confirmOwnerLeave(context, ref, crewId, members),
                  ),
                  const SizedBox(height: 10),
                  _DangerButton(
                    label: 'Elimina crew',
                    onPressed: actionState.isLoading
                        ? null
                        : () => _confirmDisband(context, ref, crewId, members),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLeave(
      BuildContext context, WidgetRef ref, String crewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
        title: const Text('Abbandonare la crew?'),
        content: Text('Dovrai richiedere di rientrare per farne di nuovo parte.',
            style: AppTheme.archivo(color: AppColors.guidaTextSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Abbandona',
                style: AppTheme.archivo(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(crewActionsControllerProvider.notifier).leave(crewId);
    }
  }

  Future<void> _confirmOwnerLeave(BuildContext context, WidgetRef ref,
      String crewId, List<CrewMember> members) async {
    final successor = _predictedSuccessor(members, myProfileId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
        title: const Text('Abbandonare la crew?'),
        content: Text(
          successor == null
              ? 'Dovrai richiedere di rientrare per farne di nuovo parte.'
              : '${successor.displayName} diventerà il nuovo proprietario della crew.',
          style: AppTheme.archivo(color: AppColors.guidaTextSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Abbandona',
                style: AppTheme.archivo(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(crewActionsControllerProvider.notifier)
          .leaveWithSuccession(crewId);
    }
  }

  Future<void> _confirmDisband(BuildContext context, WidgetRef ref,
      String crewId, List<CrewMember> members) async {
    final alone = members.length == 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
        title: const Text('Eliminare la crew?'),
        content: Text(
          alone
              ? 'L\'azione è irreversibile: la crew verrà eliminata subito.'
              : 'Serve il voto unanime di tutti i ${members.length} membri. '
                  'Il tuo voto viene registrato subito; l\'azione è irreversibile.',
          style: AppTheme.archivo(color: AppColors.guidaTextSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(alone ? 'Elimina' : 'Vota per eliminare',
                style: AppTheme.archivo(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(crewActionsControllerProvider.notifier).castDisbandVote(crewId);
    }
  }
}

/// Stessa regola dell'RPC `crew_leave`: officer più anziano, altrimenti
/// il membro più anziano per data di ingresso — solo per mostrare chi
/// diventerebbe proprietario nel dialogo di conferma.
CrewMember? _predictedSuccessor(List<CrewMember> members, String leavingId) {
  final others = members.where((m) => m.profileId != leavingId).toList();
  if (others.isEmpty) return null;
  others.sort((a, b) {
    if (a.role == CrewRole.officer && b.role != CrewRole.officer) return -1;
    if (b.role == CrewRole.officer && a.role != CrewRole.officer) return 1;
    return a.joinedAt.compareTo(b.joinedAt);
  });
  return others.first;
}

class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  const _DangerButton(
      {required this.label, required this.onPressed, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.danger),
          backgroundColor: outlined ? null : AppColors.danger.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label,
            style: AppTheme.archivo(
                color: AppColors.danger, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _DisbandVoteBanner extends ConsumerWidget {
  final String crewId;
  final int votesCount;
  final int membersCount;
  final bool iHaveVoted;
  final bool loading;
  const _DisbandVoteBanner({
    required this.crewId,
    required this.votesCount,
    required this.membersCount,
    required this.iHaveVoted,
    required this.loading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote_rounded,
                  color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Votazione per sciogliere la crew: $votesCount/$membersCount hanno votato',
                  style: AppTheme.archivo(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final notifier =
                          ref.read(crewActionsControllerProvider.notifier);
                      if (iHaveVoted) {
                        await notifier.retractDisbandVote(crewId);
                      } else {
                        await notifier.castDisbandVote(crewId);
                      }
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                iHaveVoted ? 'Ritira il voto' : 'Vota per sciogliere',
                style: AppTheme.archivo(
                    color: AppColors.danger, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1424),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppTheme.chakraPetch(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppColors.guidaCyan)),
          Text(label,
              style: AppTheme.archivo(
                  fontSize: 11, color: AppColors.guidaTextSecondary)),
        ],
      ),
    );
  }
}

enum _MemberAction { promote, demote, kick }

class _MemberTile extends ConsumerWidget {
  final CrewMember member;
  final bool isMe;
  final bool canManage;
  final String crewId;
  final bool hasVoted;
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canManage,
    required this.crewId,
    required this.hasVoted,
  });

  Color _roleColor(CrewRole role) => switch (role) {
        CrewRole.owner => const Color(0xFFFFC93C),
        CrewRole.officer => AppColors.guidaBlue,
        CrewRole.member => AppColors.guidaTextSecondary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _Avatar(url: member.avatarUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.archivo(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.guidaCyan.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('TU',
                            style: AppTheme.archivo(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.guidaCyan)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('${member.role.label} · Lv.${member.level}',
                    style: AppTheme.archivo(
                        fontSize: 12.5, color: _roleColor(member.role))),
              ],
            ),
          ),
          if (hasVoted)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.how_to_vote_rounded,
                  color: AppColors.danger, size: 18),
            ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.guidaTextSecondary),
              onPressed: () => _openActions(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    final action = await DraggableSheetScaffold.show<_MemberAction>(
      context,
      title: member.displayName,
      builder: (ctx) => SheetOptionPicker<_MemberAction>(
        selected: null,
        options: [
          if (member.role == CrewRole.member)
            const SheetOption(
                value: _MemberAction.promote, label: 'Promuovi a officer'),
          if (member.role == CrewRole.officer)
            const SheetOption(
                value: _MemberAction.demote, label: 'Retrocedi a membro'),
          const SheetOption(
              value: _MemberAction.kick, label: 'Espelli dalla crew'),
        ],
        onSelect: (_) {},
      ),
    );
    if (action == null || !context.mounted) return;

    final notifier = ref.read(crewActionsControllerProvider.notifier);
    switch (action) {
      case _MemberAction.promote:
        await notifier.setRole(
            crewId: crewId, profileId: member.profileId, role: CrewRole.officer);
      case _MemberAction.demote:
        await notifier.setRole(
            crewId: crewId, profileId: member.profileId, role: CrewRole.member);
      case _MemberAction.kick:
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0E1522),
            title: const Text('Espellere questo membro?'),
            content: Text('${member.displayName} verrà rimosso dalla crew.',
                style: AppTheme.archivo(color: AppColors.guidaTextSecondary)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annulla')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Espelli',
                    style: AppTheme.archivo(color: AppColors.danger)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await notifier.kick(crewId: crewId, profileId: member.profileId);
        }
    }
  }
}

class _CrewMissionTile extends StatelessWidget {
  final CrewMission mission;
  const _CrewMissionTile({required this.mission});

  @override
  Widget build(BuildContext context) {
    final progress = mission.targetValue <= 0
        ? 0.0
        : (mission.currentValue / mission.targetValue).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE50A0E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x29A0C8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mission.title,
              style: AppTheme.archivo(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF1B2338),
              color: AppColors.guidaCyan,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${mission.currentValue.toStringAsFixed(0)} / '
            '${mission.targetValue.toStringAsFixed(0)} · +${mission.rewardXp} XP',
            style: AppTheme.archivo(
                fontSize: 12.5, color: AppColors.guidaTextSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Widget condivisi fra le due viste
// ---------------------------------------------------------------------

class _CrewEmblem extends StatelessWidget {
  final String? url;
  final String tag;
  final double size;
  const _CrewEmblem({required this.url, required this.tag, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.guidaGradientCta),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        tag.toUpperCase(),
        style: AppTheme.archivo(
            fontWeight: FontWeight.w900,
            fontSize: size * 0.3,
            color: AppColors.guidaOnAccent),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;
  const _Avatar({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: url == null
          ? Container(
              width: size,
              height: size,
              color: AppColors.surfaceElevated,
              child: Icon(Icons.person_rounded,
                  color: AppColors.textDisabled, size: size * 0.5),
            )
          : CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (c, u) => Container(
                  width: size, height: size, color: AppColors.surfaceElevated),
              errorWidget: (c, u, e) => Container(
                  width: size,
                  height: size,
                  color: AppColors.surfaceElevated,
                  child: Icon(Icons.person_rounded,
                      color: AppColors.textDisabled, size: size * 0.5)),
            ),
    );
  }
}
