import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/notification_bell_button.dart';
import '../../../../core/widgets/profile_avatar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/spot.dart';
import '../providers/car_spotting_provider.dart';
import '../widgets/empty_spot_state.dart';
import '../widgets/spot_card.dart';

enum _Filter { tutti, rare, daVotare }

const _rareRarities = {'rare', 'epic', 'legendary'};

/// Feed Car Spotting, restyle secondo "HRR Car Spotting.dc.html". "Da
/// votare" sostituisce "Preferiti" del mockup: non esiste ancora un
/// sistema di preferiti lato dati, mentre ratingCount==0 è già disponibile.
class CarSpottingFeedScreen extends ConsumerStatefulWidget {
  const CarSpottingFeedScreen({super.key});

  @override
  ConsumerState<CarSpottingFeedScreen> createState() =>
      _CarSpottingFeedScreenState();
}

class _CarSpottingFeedScreenState extends ConsumerState<CarSpottingFeedScreen> {
  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();
  _Filter _filter = _Filter.tutti;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Spot> _apply(List<Spot> spots) {
    var out = spots;
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      out = out
          .where((s) =>
              (s.detectedMake ?? '').toLowerCase().contains(query) ||
              (s.detectedModel ?? '').toLowerCase().contains(query) ||
              (s.locationLabel ?? '').toLowerCase().contains(query))
          .toList();
    }
    switch (_filter) {
      case _Filter.tutti:
        break;
      case _Filter.rare:
        out =
            out.where((s) => _rareRarities.contains(s.detectedRarity)).toList();
      case _Filter.daVotare:
        out = out.where((s) => s.ratingCount == 0).toList();
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(spotsFeedProvider);
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final myXp = ref.watch(myProfileProvider).valueOrNull?.xp ?? 0;

    return Scaffold(
      backgroundColor: AppColor.base,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColor.cyan,
        foregroundColor: AppColor.void_,
        onPressed: () => context.push(AppRoutes.createSpot),
        child: const Icon(Icons.add_a_photo_rounded),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColor.cyan,
          onRefresh: () async => ref.invalidate(spotsFeedProvider),
          child: feed.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColor.cyan)),
            error: (err, st) => ListView(
              children: [
                const SizedBox(height: 80),
                EmptySpotState(
                  icon: Icons.error_outline_rounded,
                  message: 'Impossibile caricare il feed.\n$err',
                ),
              ],
            ),
            data: (spots) {
              final mySpotCount = spots.where((s) => s.authorId == myId).length;
              final filtered = _apply(spots);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      searchOpen: _searchOpen,
                      searchCtrl: _searchCtrl,
                      onToggleSearch: () =>
                          setState(() => _searchOpen = !_searchOpen),
                      onSearchChanged: () => setState(() {}),
                      filter: _filter,
                      onFilterChanged: (f) => setState(() => _filter = f),
                      myXp: myXp,
                      mySpotCount: mySpotCount,
                      onLeaderboard: () =>
                          context.push(AppRoutes.carSpottingLeaderboard),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: spots.isEmpty
                            ? const EmptySpotState()
                            : const EmptySpotState(
                                message:
                                    'Nessuno Spot trovato con questi criteri.',
                              ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final spot = filtered[i];
                          return SpotCard(
                            spot: spot,
                            onTap: () => context.push(AppRoutes.spotDetail
                                .replaceFirst(':spotId', spot.id)),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool searchOpen;
  final TextEditingController searchCtrl;
  final VoidCallback onToggleSearch;
  final VoidCallback onSearchChanged;
  final _Filter filter;
  final ValueChanged<_Filter> onFilterChanged;
  final int myXp;
  final int mySpotCount;
  final VoidCallback onLeaderboard;

  const _Header({
    required this.searchOpen,
    required this.searchCtrl,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.myXp,
    required this.mySpotCount,
    required this.onLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFF9DD4FF),
                      Color(0xFF35E0FF)
                    ],
                  ).createShader(b),
                  child: Text(
                    'CAR SPOTTING',
                    style: AppType.display(
                        fontSize: 26, letterSpacing: 1, color: Colors.white),
                  ),
                ),
              ),
              _IconSquareButton(
                  icon: Icons.search_rounded, onTap: onToggleSearch),
              const SizedBox(width: 10),
              _IconSquareButton(
                  icon: Icons.emoji_events_rounded, onTap: onLeaderboard),
              const SizedBox(width: 10),
              const NotificationBellButton(size: 44),
              const SizedBox(width: 10),
              const ProfileAvatarButton(size: 44),
            ],
          ),
          const SizedBox(height: 6),
          Text('Trova. Fotografa. Valuta.',
              style: AppType.text(
                  fontSize: 15, color: AppColor.inkMuted)),
          if (searchOpen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: searchCtrl,
              onChanged: (_) => onSearchChanged(),
              style: AppType.text(color: AppColor.ink),
              decoration: InputDecoration(
                hintText: 'Marca, modello, città…',
                hintStyle:
                    AppType.text(color: AppColor.inkMuted),
                filled: true,
                fillColor: const Color(0xE50C1120),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0x33A0AAFF)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                    label: 'Tutti',
                    selected: filter == _Filter.tutti,
                    onTap: () => onFilterChanged(_Filter.tutti)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Rare',
                    selected: filter == _Filter.rare,
                    onTap: () => onFilterChanged(_Filter.rare)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Da votare',
                    selected: filter == _Filter.daVotare,
                    onTap: () => onFilterChanged(_Filter.daVotare)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  badgeGradient: const [Color(0xFF2F6BFF), Color(0xFF35E0FF)],
                  badgeText: 'XP',
                  value: '$myXp',
                  label: 'Livello ${(myXp / 500).floor() + 1} · Spotter',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  badgeGradient: const [Color(0xFFFF7A1A), Color(0xFFFFB35C)],
                  badgeIcon: Icons.star_rounded,
                  value: '$mySpotCount',
                  label: 'Spot trovati',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconSquareButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      radius: 14,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: const Color(0xFF9DD4FF), size: 20),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColor.cyan.withValues(alpha: 0.24)
          : const Color(0xCC0C1422),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColor.cyan.withValues(alpha: 0.5)
                  : const Color(0x2EA0AAFF),
            ),
          ),
          child: Text(
            label,
            style: AppType.text(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF9DD4FF)
                  : AppColor.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final List<Color> badgeGradient;
  final String? badgeText;
  final IconData? badgeIcon;
  final String value;
  final String label;

  const _StatCard({
    required this.badgeGradient,
    this.badgeText,
    this.badgeIcon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: badgeGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: badgeText != null
                  ? Text(badgeText!,
                      style: AppType.text(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: const Color(0xFF04121F)))
                  : Icon(badgeIcon, size: 18, color: const Color(0xFF2A1200)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppType.text(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColor.ink)),
                Text(label,
                    maxLines: 1,
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
