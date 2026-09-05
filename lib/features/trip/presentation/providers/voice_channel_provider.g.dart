// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_channel_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$voiceChannelControllerHash() =>
    r'89d3b599d6013d89d22d3520c17d7e0909a6c300';

/// Canale voce push-to-talk "Auto amiche" — riusa lo stesso canale
/// Realtime condiviso "drivers-live" già usato per le posizioni live (vedi
/// [LiveMapController]/TripLiveController), stesso topic già autorizzato
/// dalla RLS in 0027_remove_crew_friends.sql: nessuna nuova migration.
///
/// Ogni pressione registra un clip PCM16 mono 8kHz in memoria (via
/// [AudioRecorder.startStream], niente file per la ripresa), lo incapsula
/// in un WAV minimale e lo invia in broadcast in base64. In ricezione i
/// clip vengono messi in coda e riprodotti uno alla volta, così due "spinte"
/// ravvicinate non si accavallano.
///
/// Copied from [VoiceChannelController].
@ProviderFor(VoiceChannelController)
final voiceChannelControllerProvider = AutoDisposeNotifierProvider<
    VoiceChannelController, VoiceChannelState>.internal(
  VoiceChannelController.new,
  name: r'voiceChannelControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$voiceChannelControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VoiceChannelController = AutoDisposeNotifier<VoiceChannelState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
