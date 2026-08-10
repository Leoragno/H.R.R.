import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Una mascotte "Rival" selezionabile — per ora ne esiste solo il catalogo
/// dati, nessuna UI di selezione (vedi [kMascotCatalog] e
/// active_mascot_provider.dart). `id` è anche il prefisso dei file asset
/// (assets/mascots/<id>_hero.png, assets/poses/<id>_pose_N.png, ecc.).
class Mascot {
  final String id;
  final String name;
  final String personalityTag;
  final String tagline;
  final Color accentColor;

  /// R3X e DUST nel materiale grafico originale hanno una corona — dato
  /// modellato per fase 2 (badge di rarità), non ancora renderizzato.
  final bool hasCrown;

  const Mascot({
    required this.id,
    required this.name,
    required this.personalityTag,
    required this.tagline,
    required this.accentColor,
    this.hasCrown = false,
  });
}

const kMascotCatalog = <Mascot>[
  Mascot(
    id: 'nitro',
    name: 'NITRO',
    personalityTag: 'Veloce, leale, competitivo',
    tagline: 'Gas o niente.',
    accentColor: AppColors.guidaBlue,
  ),
  Mascot(
    id: 'r3x',
    name: 'R3X',
    personalityTag: 'Provocatore, troll, dominante',
    tagline: 'Ti vedo negli specchietti...',
    accentColor: AppColors.neonRed,
    hasCrown: true,
  ),
  Mascot(
    id: 'volt',
    name: 'VOLT',
    personalityTag: 'Freddo, calmo, implacabile',
    tagline: 'I numeri parlano.',
    accentColor: AppColors.neonPurple,
  ),
  Mascot(
    id: 'spark',
    name: 'SPARK',
    personalityTag: 'Energica, sociale, imprevedibile',
    tagline: 'Divertiti, ma perdi.',
    accentColor: AppColors.neonMagenta,
  ),
  Mascot(
    id: 'dust',
    name: 'DUST',
    personalityTag: 'Ironico, testardo, inarrestabile',
    tagline: 'Quack. Sorpassato.',
    accentColor: AppColors.neonAmber,
    hasCrown: true,
  ),
];
