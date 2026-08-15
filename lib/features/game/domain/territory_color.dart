import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Palette stabile per i territori rivali sulla mappa e nella classifica:
/// serve solo a distinguerli visivamente fra loro, non rappresenta
/// un'identità reale. Niente ciano: quell'accento è riservato a "mio"
/// (vedi [AppColor.cyan]), mai a un rivale. Riusa la palette identità
/// delle mascotte.
const kRivalPalette = [
  AppMascot.nitro,
  AppMascot.r3x,
  AppMascot.volt,
  AppMascot.spark,
  AppMascot.dust,
];

/// Colore stabile (hash sull'id) per un rivale — stessa persona sempre
/// stesso colore, senza bisogno di coordinamento col server.
Color rivalColorFor(String ownerId) {
  final idx = ownerId.hashCode.abs() % kRivalPalette.length;
  return kRivalPalette[idx];
}

/// Colore "identità" di un giocatore, usato sia per riempire la sua cella
/// sulla mappa sia per il pallino accanto al suo nome in classifica — stessa
/// logica in un unico posto così i due non possono disallinearsi: ciano se
/// sono io, altrimenti la palette rivali.
Color territoryIdentityColor({
  required String ownerId,
  required String? myProfileId,
}) {
  if (ownerId == myProfileId) return AppColor.cyan;
  return rivalColorFor(ownerId);
}
