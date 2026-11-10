import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// Accento neon scelto dall'utente (Impostazioni). Persistito in locale;
/// a ogni cambio aggiorna [AppColor.accent] e `HrrApp` ricostruisce l'intero
/// albero (vedi main.dart), così ogni widget rilegge il nuovo colore.
class AccentController extends Notifier<HeatAccent> {
  static const _key = 'heat_accent';

  @override
  HeatAccent build() {
    _load();
    return HeatAccent.values.firstWhere(
      (a) => a.color == AppColor.accent,
      orElse: () => HeatAccent.corallo,
    );
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = HeatAccent.byName(prefs.getString(_key));
      if (saved != state) _apply(saved);
    } catch (_) {
      // Prefs non disponibili (test): resta il default.
    }
  }

  void _apply(HeatAccent a) {
    AppColor.setAccent(a.color);
    state = a;
  }

  Future<void> select(HeatAccent a) async {
    _apply(a);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, a.name);
    } catch (_) {}
  }
}

final accentProvider =
    NotifierProvider<AccentController, HeatAccent>(AccentController.new);
