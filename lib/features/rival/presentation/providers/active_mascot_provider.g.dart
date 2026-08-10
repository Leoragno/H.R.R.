// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_mascot_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeMascotHash() => r'8d8c271924110bdb7a1890db7e032af01258d4a8';

/// Mascotte attiva per l'utente corrente — letta da [myProfileProvider]
/// (si aggiorna in realtime quando l'utente cambia scelta in
/// Impostazioni, stesso meccanismo di accentColor), con fallback alla
/// prima del catalogo se non ha ancora scelto o se l'id persistito non è
/// (più) riconosciuto.
///
/// Copied from [activeMascot].
@ProviderFor(activeMascot)
final activeMascotProvider = AutoDisposeProvider<Mascot>.internal(
  activeMascot,
  name: r'activeMascotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$activeMascotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveMascotRef = AutoDisposeProviderRef<Mascot>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
