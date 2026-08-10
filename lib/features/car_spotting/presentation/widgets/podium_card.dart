import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/spot.dart';
import 'star_rating.dart';

/// Card podio (#1/#2/#3) per LeaderboardScreen. `rank` è 1-based.
class PodiumCard extends StatelessWidget {
  final int rank;
  final Spot spot;
  final VoidCallback? onTap;

  const PodiumCard(
      {super.key, required this.rank, required this.spot, this.onTap});

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  @override
  Widget build(BuildContext context) {
    final title = [spot.detectedMake, spot.detectedModel]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final accentColor = switch (rank) {
      1 => const Color(0xFFFFC93C),
      2 => const Color(0xFFDFE4EA),
      _ => const Color(0xFFFF8A1F),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE50A0E1A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                _medals[rank] ?? '#$rank',
                style: const TextStyle(fontSize: 22),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: spot.photoUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(
                    width: 56, height: 56, color: AppColors.surfaceElevated),
                errorWidget: (c, u, e) => Container(
                    width: 56,
                    height: 56,
                    color: AppColors.surfaceElevated,
                    child: const Icon(Icons.directions_car_rounded,
                        color: AppColors.textDisabled)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Auto sconosciuta' : title,
                    style: AppTheme.archivo(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  StarRating(rating: spot.averageRating, size: 13),
                ],
              ),
            ),
            Text(
              spot.averageRating.toStringAsFixed(1),
              style: TextStyle(
                  color: accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
