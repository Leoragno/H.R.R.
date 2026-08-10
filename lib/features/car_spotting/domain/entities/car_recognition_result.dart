import 'package:equatable/equatable.dart';

/// Esito del riconoscimento auto — predisposto per la pipeline TFLite
/// on-device futura (non implementata in questo giro). Rispecchia i
/// campi `detected_*` di `spots`; oggi nessun usecase la produce, la
/// UI di creazione spot raccoglie marca/modello/anno solo a mano.
class CarRecognitionResult extends Equatable {
  final String? make;
  final String? model;
  final int? year;
  final String? category;
  final String? rarity;
  final double? confidence;

  const CarRecognitionResult({
    this.make,
    this.model,
    this.year,
    this.category,
    this.rarity,
    this.confidence,
  });

  @override
  List<Object?> get props => [make, model, year, category, rarity, confidence];
}
