import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Avatar utente per righe/card di classifica — estratto da
/// leaderboard_screen.dart (era `_Avatar`, privato) per essere riusato
/// anche da RivalryCard, stessa implementazione.
class LeaderboardAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final Color? ringColor;
  const LeaderboardAvatar(
      {super.key, required this.url, required this.size, this.ringColor});

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: url == null
          ? Container(
              width: size,
              height: size,
              color: AppColor.surfaceHigh,
              child: Icon(Icons.person_rounded,
                  color: AppColor.inkFaint, size: size * 0.5),
            )
          : CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (c, u) => Container(
                  width: size, height: size, color: AppColor.surfaceHigh),
              errorWidget: (c, u, e) => Container(
                  width: size,
                  height: size,
                  color: AppColor.surfaceHigh,
                  child: Icon(Icons.person_rounded,
                      color: AppColor.inkFaint, size: size * 0.5)),
            ),
    );
    if (ringColor == null) return content;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor!, width: 2),
      ),
      child: content,
    );
  }
}
