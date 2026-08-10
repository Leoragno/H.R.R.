import 'package:equatable/equatable.dart';

/// Esito di una chiamata a `claim_territory_cells`: quante celle della
/// singola chiamata erano libere vs. rubate ad altri — usato per il
/// banner "Nuovi esagoni +N · Rubati N".
class TerritoryClaimResult extends Equatable {
  final int freshCount;
  final int stolenCount;

  const TerritoryClaimResult(
      {required this.freshCount, required this.stolenCount});

  static const zero = TerritoryClaimResult(freshCount: 0, stolenCount: 0);

  TerritoryClaimResult operator +(TerritoryClaimResult other) {
    return TerritoryClaimResult(
      freshCount: freshCount + other.freshCount,
      stolenCount: stolenCount + other.stolenCount,
    );
  }

  @override
  List<Object?> get props => [freshCount, stolenCount];
}
