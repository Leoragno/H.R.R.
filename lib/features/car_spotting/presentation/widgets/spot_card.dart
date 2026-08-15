import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/spot.dart';
import 'rarity_badge.dart';
import 'star_rating.dart';

/// Card feed, restyle secondo "HRR Car Spotting.dc.html" (righe 99-183):
/// foto con scrim, pill rarità, titolo in Chakra Petch, riga autore.
class SpotCard extends StatelessWidget {
  final Spot spot;
  final VoidCallback? onTap;

  const SpotCard({super.key, required this.spot, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = [spot.detectedMake, spot.detectedModel]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF00E1626), Color(0xF0080C14)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x29A0C8FF)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x80000000),
                blurRadius: 30,
                offset: Offset(0, 14)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: CachedNetworkImage(
                    imageUrl: spot.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                        color: AppColor.surfaceHigh,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: AppColor.cyan, strokeWidth: 2))),
                    errorWidget: (c, u, e) => Container(
                        color: AppColor.surfaceHigh,
                        child: const Icon(Icons.broken_image_rounded,
                            color: AppColor.inkFaint)),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.black.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.55],
                      ),
                    ),
                  ),
                ),
                if (spot.detectedRarity != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: RarityBadge(rarity: spot.detectedRarity),
                  ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Text(
                    title.isEmpty ? 'Auto sconosciuta' : title,
                    style:
                        AppType.display(fontSize: 22, color: Colors.white),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (spot.detectedYear != null)
                        Text('${spot.detectedYear}',
                            style: AppType.text(
                                color: AppColor.inkMuted,
                                fontSize: 13)),
                      const Spacer(),
                      if (spot.authorUsername != null)
                        Text('@${spot.authorUsername}',
                            style: AppType.text(
                                color: AppColor.cyan, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      StarRating(rating: spot.averageRating, size: 15),
                      const SizedBox(width: 8),
                      Text(
                        spot.ratingCount == 0
                            ? 'Non ancora votata'
                            : '${spot.averageRating.toStringAsFixed(1)} (${spot.ratingCount})',
                        style: AppType.text(
                            color: AppColor.inkMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
