import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'voice_channel_provider.g.dart';

/// 8kHz mono, qualità voce: una spinta PTT di [_kMaxRecordSeconds] pesa
/// circa 128KB PCM grezzo (~170KB in base64), ben dentro il limite dei
/// messaggi broadcast Realtime — nessun file/CDN intermedio.
const _kSampleRate = 8000;
const _kMaxRecordSeconds = 8;
const _kMinRecordMs = 300;
const _kChannelName = 'drivers-live';

/// Chi ha appena parlato sul canale — solo per l'indicatore "in arrivo"
/// nella UI, mai persistito.
class VoiceActivity {
  final String profileId;
  final String username;
  const VoiceActivity(this.profileId, this.username);
}

class VoiceChannelState {
  final bool recording;
  final bool sending;
  final VoiceActivity? speaking;

  const VoiceChannelState({
    this.recording = false,
    this.sending = false,
    this.speaking,
  });

  VoiceChannelState copyWith({
    bool? recording,
    bool? sending,
    VoiceActivity? speaking,
    bool clearSpeaking = false,
  }) {
    return VoiceChannelState(
      recording: recording ?? this.recording,
      sending: sending ?? this.sending,
      speaking: clearSpeaking ? null : (speaking ?? this.speaking),
    );
  }
}

class _IncomingClip {
  final String profileId;
  final String username;
  final Uint8List wav;
  const _IncomingClip(this.profileId, this.username, this.wav);
}

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
@riverpod
class VoiceChannelController extends _$VoiceChannelController {
  RealtimeChannel? _channel;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<Uint8List>? _recordSub;
  BytesBuilder? _recordBuffer;
  DateTime? _recordStartedAt;
  Timer? _maxDurationTimer;

  final Queue<_IncomingClip> _playQueue = Queue();
  bool _draining = false;

  @override
  VoiceChannelState build() {
    ref.onDispose(_teardown);
    if (ref.watch(authStateProvider).valueOrNull != null) _join();
    return const VoiceChannelState();
  }

  void _join() {
    final channel = ref.read(supabaseClientProvider).channel(
          _kChannelName,
          opts: const RealtimeChannelConfig(private: true),
        );
    _channel = channel;
    channel
      ..onBroadcast(event: 'voice', callback: _onVoiceReceived)
      ..subscribe();
  }

  void _onVoiceReceived(Map<String, dynamic> payload) {
    final myId = ref.read(myProfileProvider).valueOrNull?.id;
    final profileId = payload['profileId'] as String?;
    final username = payload['username'] as String? ?? '';
    final audioB64 = payload['audio'] as String?;
    final sampleRate = (payload['sampleRate'] as num?)?.toInt() ?? _kSampleRate;
    if (profileId == null || profileId == myId || audioB64 == null) return;

    try {
      final pcm = base64Decode(audioB64);
      final wav = _wrapPcm16Wav(pcm, sampleRate: sampleRate);
      _playQueue.add(_IncomingClip(profileId, username, wav));
      if (!_draining) unawaited(_drainPlayQueue());
    } catch (_) {
      // Clip corrotto/non decodificabile: mai bloccare il canale per un
      // singolo messaggio malformato.
    }
  }

  Future<void> _drainPlayQueue() async {
    _draining = true;
    while (_playQueue.isNotEmpty) {
      final clip = _playQueue.removeFirst();
      state = state.copyWith(
          speaking: VoiceActivity(clip.profileId, clip.username));
      try {
        await _playClip(clip.wav);
      } catch (_) {
        // Riproduzione best-effort: passa al prossimo clip in coda.
      }
    }
    _draining = false;
    if (state.speaking != null) state = state.copyWith(clearSpeaking: true);
  }

  /// Su web un data: URI è riprodotto nativamente dall'elemento
  /// <audio> del browser; sulle piattaforme IO passiamo invece da un file
  /// temporaneo (path_provider non ha implementazione web), cancellato
  /// subito dopo la riproduzione.
  Future<void> _playClip(Uint8List wav) async {
    if (kIsWeb) {
      await _player.setAudioSource(
        AudioSource.uri(Uri.dataFromBytes(wav, mimeType: 'audio/wav')),
      );
      await _player.play();
      await _player.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed);
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/hrr_voice_${DateTime.now().microsecondsSinceEpoch}.wav');
    await file.writeAsBytes(wav, flush: true);
    try {
      await _player.setFilePath(file.path);
      await _player.play();
      await _player.playerStateStream.firstWhere(
          (s) => s.processingState == ProcessingState.completed);
    } finally {
      try {
        await file.delete();
      } catch (_) {
        // Best-effort: un temp file non ripulito non impatta la funzionalità.
      }
    }
  }

  /// Avvia la registrazione — no-op se già in corso o se il permesso
  /// microfono viene negato (il prompt nativo lo gestisce [AudioRecorder]).
  Future<void> startTalking() async {
    if (state.recording) return;
    if (!await _recorder.hasPermission()) return;

    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _kSampleRate,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ));
      _recordBuffer = BytesBuilder(copy: false);
      _recordStartedAt = DateTime.now();
      _recordSub = stream.listen(_recordBuffer!.add);
      state = state.copyWith(recording: true);
      _maxDurationTimer =
          Timer(const Duration(seconds: _kMaxRecordSeconds), stopTalking);
    } catch (_) {
      state = state.copyWith(recording: false);
    }
  }

  /// Ferma la registrazione e invia il clip sul canale — scarta pressioni
  /// accidentali sotto [_kMinRecordMs] senza inviare nulla.
  Future<void> stopTalking() async {
    if (!state.recording) return;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    state = state.copyWith(recording: false, sending: true);

    try {
      await _recorder.stop();
      await _recordSub?.cancel();
      _recordSub = null;
      final startedAt = _recordStartedAt;
      _recordStartedAt = null;
      final bytes = _recordBuffer?.takeBytes();
      _recordBuffer = null;

      if (bytes == null || bytes.isEmpty || startedAt == null) return;
      if (DateTime.now().difference(startedAt) <
          const Duration(milliseconds: _kMinRecordMs)) {
        return;
      }

      final channel = _channel;
      final profile = ref.read(myProfileProvider).valueOrNull;
      if (channel == null || profile == null) return;

      await channel.sendBroadcastMessage(event: 'voice', payload: {
        'profileId': profile.id,
        'username': profile.username,
        'sampleRate': _kSampleRate,
        'audio': base64Encode(bytes),
      });
    } catch (_) {
      // Invio best-effort: un errore di rete non deve bloccare il PTT.
    } finally {
      state = state.copyWith(sending: false);
    }
  }

  void _teardown() {
    _maxDurationTimer?.cancel();
    unawaited(_recordSub?.cancel());
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
  }
}

/// Incapsula PCM16LE mono in un contenitore WAV minimale (header RIFF a 44
/// byte, nessuna dipendenza esterna) così un player audio standard lo
/// riproduce senza bisogno di un decoder PCM dedicato.
Uint8List _wrapPcm16Wav(Uint8List pcm, {required int sampleRate}) {
  const bitsPerSample = 16;
  const numChannels = 1;
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  const blockAlign = numChannels * bitsPerSample ~/ 8;

  final header = BytesBuilder();
  void writeString(String s) => header.add(s.codeUnits);
  void writeUint32(int v) => header.add([
        v & 0xFF,
        (v >> 8) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 24) & 0xFF,
      ]);
  void writeUint16(int v) => header.add([v & 0xFF, (v >> 8) & 0xFF]);

  writeString('RIFF');
  writeUint32(36 + pcm.length);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(numChannels);
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(bitsPerSample);
  writeString('data');
  writeUint32(pcm.length);

  return (BytesBuilder()
        ..add(header.takeBytes())
        ..add(pcm))
      .takeBytes();
}
