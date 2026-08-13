import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/friend_profile.dart';
import '../providers/friends_provider.dart';

/// Ricerca/aggiungi amici + richieste in arrivo + lista amici accettati.
/// Prima di questa schermata "Aggiungi amici" (leaderboard_screen.dart) era
/// un pulsante morto: nessuna UI collegata alla tabella friendships (vedi
/// 0023_friends.sql per le RPC che la rendono finalmente utilizzabile).
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(friendsSearchControllerProvider);
    final requestsAsync = ref.watch(pendingFriendRequestsProvider);
    final friendsAsync = ref.watch(myFriendsProvider);
    final searching = searchState.query.trim().length >= 2;

    return Scaffold(
      backgroundColor: AppColors.guidaBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 18, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                    onPressed: () => context.pop(),
                  ),
                  Text('Amici',
                      style: AppTheme.archivo(
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => ref
                    .read(friendsSearchControllerProvider.notifier)
                    .setQuery(v),
                style: AppTheme.archivo(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cerca per username',
                  hintStyle:
                      AppTheme.archivo(color: AppColors.guidaTextSecondary),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.guidaTextSecondary),
                  filled: true,
                  fillColor: const Color(0xE50A0E1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0x29A0C8FF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0x29A0C8FF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.guidaCyan),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                children: [
                  if (searching) ..._searchSection(searchState),
                  if (!searching) ...[
                    ...requestsAsync.when(
                      loading: () => const [],
                      error: (_, __) => const [],
                      data: (requests) => _requestsSection(requests),
                    ),
                    _sectionTitle('I tuoi amici'),
                    ...friendsAsync.when(
                      loading: () => [_loadingRow()],
                      error: (_, __) =>
                          [_errorRow('Impossibile caricare gli amici')],
                      data: (friends) => friends.isEmpty
                          ? [
                              _emptyRow(
                                  'Nessun amico ancora — cerca uno username qui sopra.')
                            ]
                          : [for (final f in friends) _FriendTile(friend: f)],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _searchSection(FriendsSearchState state) {
    if (state.loading) return [_loadingRow()];
    if (state.error != null) return [_errorRow(state.error!)];
    if (state.results.isEmpty) {
      return [_emptyRow('Nessun utente trovato per "${state.query}".')];
    }
    return [for (final r in state.results) _SearchResultTile(result: r)];
  }

  List<Widget> _requestsSection(List<FriendRequest> requests) {
    if (requests.isEmpty) return const [];
    return [
      _sectionTitle('Richieste in arrivo'),
      for (final r in requests) _RequestTile(request: r),
      const SizedBox(height: 8),
    ];
  }

  Widget _sectionTitle(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(label,
            style: AppTheme.archivo(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.guidaTextSecondary)),
      );

  Widget _loadingRow() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.guidaCyan)),
      );

  Widget _errorRow(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(message,
            style: AppTheme.archivo(color: AppColors.guidaTextSecondary)),
      );

  Widget _emptyRow(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(message,
            style: AppTheme.archivo(color: AppColors.guidaTextSecondary)),
      );
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
            ),
    );
  }
}

class _TileShell extends StatelessWidget {
  final Widget avatar;
  final String title;
  final String subtitle;
  final Widget trailing;
  const _TileShell({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE50A0E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x29A0C8FF)),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.archivo(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                Text(subtitle,
                    style: AppTheme.archivo(
                        fontSize: 13, color: AppColors.guidaTextSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  final FriendSearchResult result;
  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(friendsSearchControllerProvider.notifier);
    return _TileShell(
      avatar: _Avatar(url: result.avatarUrl, size: 44),
      title: result.displayName,
      subtitle: '@${result.username} · Lv.${result.level}',
      trailing: switch (result.relationship) {
        FriendRelationship.accepted =>
          const Icon(Icons.check_circle_rounded, color: AppColors.neonGreen),
        FriendRelationship.pendingOutgoing => Text('Inviata',
            style: AppTheme.archivo(
                fontSize: 13, color: AppColors.guidaTextSecondary)),
        FriendRelationship.pendingIncoming => Text('In arrivo',
            style: AppTheme.archivo(fontSize: 13, color: AppColors.guidaCyan)),
        FriendRelationship.none =>
          _AddButton(onTap: () => notifier.sendRequest(result.profileId)),
      },
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.guidaCyan.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('Aggiungi',
              style: TextStyle(
                  color: AppColors.guidaCyan, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final FriendRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(friendsSearchControllerProvider.notifier);
    return _TileShell(
      avatar: _Avatar(url: request.avatarUrl, size: 44),
      title: request.displayName,
      subtitle: '@${request.username} · Lv.${request.level}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.neonRed),
            onPressed: () => notifier.respondToRequest(
                requesterId: request.requesterId, accept: false),
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.neonGreen),
            onPressed: () => notifier.respondToRequest(
                requesterId: request.requesterId, accept: true),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  final FriendProfile friend;
  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TileShell(
      avatar: _Avatar(url: friend.avatarUrl, size: 44),
      title: friend.displayName,
      subtitle: '@${friend.username} · Lv.${friend.level}',
      trailing: IconButton(
        icon: const Icon(Icons.person_remove_outlined,
            color: AppColors.guidaTextSecondary),
        onPressed: () => _confirmRemove(context, ref),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
        title: const Text('Rimuovere amico?'),
        content: Text('${friend.displayName} non sarà più tuo amico.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(friendsSearchControllerProvider.notifier)
          .removeFriend(friend.profileId);
    }
  }
}
