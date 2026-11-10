import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../domain/entities/spot.dart';
import '../providers/car_spotting_provider.dart';
import '../widgets/spot_heat_parts.dart';

enum _Tab {
  feed('FEED'),
  top('TOP AUTO'),
  mine('I MIEI');

  const _Tab(this.label);
  final String label;
}

/// SPOTTING (HEAT, handoff §12): titolo + CTA SPOTTA (unico accento della
/// schermata), tab FEED / TOP AUTO / I MIEI, card auto con foto smussata,
/// targa marca·anno/modello, voto medio in oro, autore e contatori.
class CarSpottingFeedScreen extends ConsumerStatefulWidget {
  const CarSpottingFeedScreen({super.key});

  @override
  ConsumerState<CarSpottingFeedScreen> createState() =>
      _CarSpottingFeedScreenState();
}

class _CarSpottingFeedScreenState extends ConsumerState<CarSpottingFeedScreen> {
  _Tab _tab = _Tab.feed;

  @override
  Widget build(BuildContext context) {
    final spots = switch (_tab) {
      _Tab.feed => ref.watch(spotsFeedProvider),
      _Tab.top => ref.watch(topRatedSpotsProvider),
      _Tab.mine => ref.watch(mySpotsProvider),
    };

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColor.accent,
            backgroundColor: AppColor.surfaceHigh,
            onRefresh: () async {
              switch (_tab) {
                case _Tab.feed:
                  ref.invalidate(spotsFeedProvider);
                  await ref.read(spotsFeedProvider.future);
                case _Tab.top:
                  ref.invalidate(topRatedSpotsProvider);
                  await ref.read(topRatedSpotsProvider.future);
                case _Tab.mine:
                  ref.invalidate(mySpotsProvider);
                  await ref.read(mySpotsProvider.future);
              }
            },
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 120),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      const Expanded(child: ScreenTitle('Spotting')),
                      SizedBox(
                        width: 136,
                        child: HeatButton(
                          label: 'Spotta',
                          icon: Icons.photo_camera_rounded,
                          height: 46,
                          fontSize: 18,
                          onPressed: () => context.push(AppRoutes.createSpot),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Tabs(
                  selected: _tab,
                  onSelect: (t) => setState(() => _tab = t),
                ),
                const SizedBox(height: 14),
                ...spots.when(
                  loading: () => const [
                    SizedBox(
                      height: 220,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColor.inkMuted),
                        ),
                      ),
                    ),
                  ],
                  error: (e, _) => const [
                    _Message(
                        'spot non disponibili. trascina giù per riprovare.'),
                  ],
                  data: (list) {
                    if (list.isEmpty) {
                      return [
                        _Message(_tab == _Tab.top
                            ? 'nessuna auto votata ancora.'
                            : _tab == _Tab.mine
                                ? 'non hai ancora pubblicato spot. tocca SPOTTA per il primo.'
                                : 'nessuno spot ancora. tocca SPOTTA per il primo.'),
                      ];
                    }
                    return [
                      for (final (i, s) in list.indexed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          child: HeatEnter(
                            index: i.clamp(0, 8),
                            child: SpotHeatCard(
                              spot: s,
                              rank: _tab == _Tab.top ? i + 1 : null,
                              onTap: () => context.push(AppRoutes.spotDetail
                                  .replaceFirst(':spotId', s.id)),
                            ),
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});

  final _Tab selected;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.line)),
      ),
      // Scorrevole: su schermi stretti / testo grande i tab non sforano.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in _Tab.values) ...[
              if (t != _Tab.values.first) const SizedBox(width: 22),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(t),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 3,
                        // Selezione in inchiostro: l'accento è di SPOTTA.
                        color: t == selected
                            ? AppColor.ink
                            : const Color(0x00000000),
                      ),
                    ),
                  ),
                  child: Text(
                    t.label,
                    style: AppType.display(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      italic: false,
                      letterSpacing: 1.4,
                      color: t == selected ? AppColor.ink : AppColor.inkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card spot: foto 190px con angoli smussati, targa, voto, rank graffiti
/// (solo TOP AUTO), riga autore con voti e commenti.
class SpotHeatCard extends StatelessWidget {
  const SpotHeatCard({
    super.key,
    required this.spot,
    required this.onTap,
    this.rank,
  });

  final Spot spot;
  final VoidCallback onTap;
  final int? rank;

  static const _shape = ChamferBorder(
    cut: 18,
    bottomLeft: true,
    side: BorderSide(color: AppColor.line),
  );

  @override
  Widget build(BuildContext context) {
    return HeatPressable(
      onTap: onTap,
      child: Container(
        decoration:
            const ShapeDecoration(color: AppColor.surface, shape: _shape),
        child: ClipPath(
          clipper: const ShapeBorderClipper(shape: _shape),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 190,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SpotPhoto(url: spot.photoUrl),
                    if (rank != null)
                      Positioned(
                        right: 14,
                        top: 8,
                        child: GraffitiText('#$rank',
                            fontSize: 40, color: AppColor.gold, angle: -.14),
                      ),
                    Positioned(
                      left: 0,
                      bottom: 14,
                      right: 110,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SpotPlate(
                          brand: spotBrandLine(spot),
                          model: spotModelLine(spot),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 14,
                      child: Container(
                        color: AppColor.base,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 18, color: AppColor.gold),
                            const SizedBox(width: 4),
                            Text(
                              spotRatingLabel(spot),
                              style: AppType.display(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColor.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    SpotAuthorFace(mascotId: spot.authorMascotId),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${spot.authorUsername ?? 'pilota'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.text(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            spotMeta(spot),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.text(
                                fontSize: 12, color: AppColor.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Counter(
                        icon: Icons.how_to_vote_rounded,
                        value: spot.ratingCount),
                    const SizedBox(width: 12),
                    _Counter(
                        icon: Icons.chat_bubble_rounded,
                        value: spot.commentCount),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColor.inkMuted),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: AppType.text(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColor.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 24),
      child: Column(
        children: [
          const Icon(Icons.photo_camera_outlined,
              size: 42, color: AppColor.inkFaint),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppType.text(
                fontSize: 14, color: AppColor.inkMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
