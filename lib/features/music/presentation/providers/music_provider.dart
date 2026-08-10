import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/track.dart';

part 'music_provider.g.dart';

/// Coda demo: nessuna integrazione con un servizio di streaming reale
/// (Spotify/Apple Music) è collegata — non richiesta, non ci sono
/// credenziali/SDK forniti. Tracce SoundHelix: file MP3 pubblicati
/// esplicitamente come esempi liberi per testare player audio, non
/// materiale con licenza incerta.
const musicQueue = <Track>[
  Track(
    title: 'Night Drive',
    artist: 'HRR Radio',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    artGradient: [Color(0xFF35E0FF), Color(0xFF2F6BFF)],
  ),
  Track(
    title: 'Neon Circuit',
    artist: 'HRR Radio',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    artGradient: [Color(0xFFFF2FD0), Color(0xFF7B3BFF)],
  ),
  Track(
    title: 'Redline',
    artist: 'HRR Radio',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    artGradient: [Color(0xFFFFB020), Color(0xFFFF3B5C)],
  ),
  Track(
    title: 'Midnight Straight',
    artist: 'HRR Radio',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    artGradient: [Color(0xFF39FF88), Color(0xFF2F6BFF)],
  ),
  Track(
    title: 'Apex',
    artist: 'HRR Radio',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    artGradient: [Color(0xFF8B5CF6), Color(0xFF35E0FF)],
  ),
];

/// Player condiviso per l'intera app (cassetto musica raggiungibile da
/// tutte le tab principali) — vive quanto l'app, mai autoDispose: cambiare
/// tab non deve interrompere la riproduzione.
@Riverpod(keepAlive: true)
AudioPlayer audioPlayer(AudioPlayerRef ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
}

/// Indice del brano corrente nella coda. Il player parte "vuoto"
/// (nessun setUrl) finché l'utente non preme play la prima volta.
@Riverpod(keepAlive: true)
class MusicController extends _$MusicController {
  bool _loaded = false;

  @override
  int build() {
    final player = ref.watch(audioPlayerProvider);
    final sub = player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) next();
    });
    ref.onDispose(sub.cancel);
    return 0;
  }

  Track get currentTrack => musicQueue[state];

  Future<void> _load(int index, {required bool autoplay}) async {
    state = index;
    _loaded = true;
    final player = ref.read(audioPlayerProvider);
    await player.setUrl(musicQueue[index].url);
    if (autoplay) await player.play();
  }

  Future<void> togglePlay() async {
    final player = ref.read(audioPlayerProvider);
    if (!_loaded) {
      await _load(state, autoplay: true);
      return;
    }
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> next() => _load((state + 1) % musicQueue.length, autoplay: true);

  Future<void> previous() =>
      _load((state - 1 + musicQueue.length) % musicQueue.length,
          autoplay: true);

  Future<void> selectTrack(int index) => _load(index, autoplay: true);
}
