// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'music_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioPlayerHash() => r'98f6e2d720cf9b635687e9ef8797288f103dcd48';

/// Player condiviso per l'intera app (cassetto musica raggiungibile da
/// tutte le tab principali) — vive quanto l'app, mai autoDispose: cambiare
/// tab non deve interrompere la riproduzione.
///
/// Copied from [audioPlayer].
@ProviderFor(audioPlayer)
final audioPlayerProvider = Provider<AudioPlayer>.internal(
  audioPlayer,
  name: r'audioPlayerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$audioPlayerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AudioPlayerRef = ProviderRef<AudioPlayer>;
String _$musicControllerHash() => r'feac1ad386aaa5893c50e3a6953357651fc26a24';

/// Indice del brano corrente nella coda. Il player parte "vuoto"
/// (nessun setUrl) finché l'utente non preme play la prima volta.
///
/// Copied from [MusicController].
@ProviderFor(MusicController)
final musicControllerProvider = NotifierProvider<MusicController, int>.internal(
  MusicController.new,
  name: r'musicControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$musicControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MusicController = Notifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
