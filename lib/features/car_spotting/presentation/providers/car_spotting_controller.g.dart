// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_spotting_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$imageCompressorHash() => r'dac15c2e2c6a2c5252e8963a55a610b58b7e655e';

/// Isolato dietro un provider (non chiamato staticamente nel controller)
/// solo per poterlo sovrascrivere nei test: `flutter_image_compress` non
/// ha un'implementazione per ogni piattaforma (es. Windows desktop) e
/// lancerebbe UnimplementedError prima ancora di toccare un platform
/// channel mockabile.
///
/// Copied from [imageCompressor].
@ProviderFor(imageCompressor)
final imageCompressorProvider = AutoDisposeProvider<ImageCompressor>.internal(
  imageCompressor,
  name: r'imageCompressorProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$imageCompressorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ImageCompressorRef = AutoDisposeProviderRef<ImageCompressor>;
String _$carSpottingControllerHash() =>
    r'1a7bb4b1c05b74920d6120522d88506431c99444';

/// Orchestrazione publish/rate: chiama il repository, poi pubblica sul
/// bus del Mission Engine e invalida i provider di lettura così la UI
/// riflette subito l'esito. Nessuna feature deve mai chiamare
/// record_mission_event/il repository missioni direttamente — solo
/// publish() sul bus condiviso.
///
/// Copied from [CarSpottingController].
@ProviderFor(CarSpottingController)
final carSpottingControllerProvider =
    AutoDisposeAsyncNotifierProvider<CarSpottingController, void>.internal(
  CarSpottingController.new,
  name: r'carSpottingControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$carSpottingControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CarSpottingController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
