import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../domain/entities/spot.dart';

/// Pezzi condivisi dalle schermate Spotting HEAT (feed, nuovo, dettaglio).

/// Sfondo delle foto mancanti / in caricamento (radial-gradient del design).
const spotPhotoFallback = DecoratedBox(
  decoration: BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.topCenter,
      radius: 1.3,
      colors: [AppColor.surfaceHigh, AppColor.surface],
      stops: [0, .7],
    ),
  ),
);

class SpotPhoto extends StatelessWidget {
  const SpotPhoto({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return spotPhotoFallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => spotPhotoFallback,
      errorWidget: (_, __, ___) => const Stack(
        fit: StackFit.expand,
        children: [
          spotPhotoFallback,
          Icon(Icons.broken_image_rounded, color: AppColor.inkFaint),
        ],
      ),
    );
  }
}

/// "MARCA · ANNO" sopra, modello grande sotto.
String spotBrandLine(Spot s) => [
      (s.detectedMake ?? '').trim().toUpperCase(),
      if (s.detectedYear != null) '${s.detectedYear}',
    ].where((e) => e.isNotEmpty).join(' · ');

String spotModelLine(Spot s) {
  final m = (s.detectedModel ?? '').trim();
  return m.isEmpty ? 'AUTO SCONOSCIUTA' : m.toUpperCase();
}

/// Media voti "4,3" o "—" senza voti.
String spotRatingLabel(Spot s) => s.ratingCount == 0
    ? '—'
    : s.averageRating.toStringAsFixed(1).replaceAll('.', ',');

String spotAgo(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'adesso';
  if (d.inMinutes < 60) return '${d.inMinutes} min fa';
  if (d.inHours < 24) return '${d.inHours} h fa';
  if (d.inDays == 1) return 'ieri';
  if (d.inDays < 30) return '${d.inDays} gg fa';
  return '${t.day.toString().padLeft(2, '0')}/'
      '${t.month.toString().padLeft(2, '0')}/${t.year}';
}

/// Posizione · quanto tempo fa.
String spotMeta(Spot s) => [
      (s.locationLabel ?? '').trim().isEmpty
          ? 'posizione nascosta'
          : s.locationLabel!.trim(),
      spotAgo(s.createdAt),
    ].join(' · ');

/// Targa scura a parallelogramma in basso a sinistra sulla foto.
class SpotPlate extends StatelessWidget {
  const SpotPlate({
    super.key,
    required this.brand,
    required this.model,
    this.modelSize = 28,
  });

  final String brand;
  final String model;
  final double modelSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecoration(
        color: AppColor.base,
        shape: SlantBorder(left: 0, right: 14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 26, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (brand.isNotEmpty)
            Text(
              brand,
              style: AppType.display(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                italic: false,
                letterSpacing: 1.8,
                color: AppColor.inkMuted,
              ),
            ),
          Text(
            model,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.display(
              fontSize: modelSize,
              fontWeight: FontWeight.w900,
              height: .95,
            ),
          ),
        ],
      ),
    );
  }
}

/// Volto della mascotte dell'autore (quadrato), icona se non scelta.
class SpotAuthorFace extends StatelessWidget {
  const SpotAuthorFace({super.key, required this.mascotId, this.size = 32});

  final String? mascotId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback =
        Icon(Icons.person_rounded, color: AppColor.inkFaint, size: size * .6);
    return SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: AppColor.surfaceHigh,
        child: mascotId == null
            ? fallback
            : Image.asset(
                'assets/faces/$mascotId.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}
