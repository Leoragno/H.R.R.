import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/music_provider.dart';

/// Cassetto musica — si apre trascinando dal bordo sinistro dello schermo
/// (comportamento nativo di `Scaffold.drawer`, nessuna gesture custom da
/// reinventare). Disponibile su tutte le tab principali: vedi MainShell.
class MusicDrawer extends ConsumerWidget {
  const MusicDrawer({super.key});

  String _clock(Duration d) {
    final s = d.inSeconds.clamp(0, 999999);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(audioPlayerProvider);
    final trackIndex = ref.watch(musicControllerProvider);
    final track = musicQueue[trackIndex];
    final controller = ref.read(musicControllerProvider.notifier);
    final width = MediaQuery.sizeOf(context).width * 0.84;

    return Drawer(
      width: width,
      backgroundColor: const Color(0xF00C1120),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(26)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IN RIPRODUZIONE',
                          style: AppTheme.archivo(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: AppColors.guidaTextSecondary)),
                      const SizedBox(height: 6),
                      Text('HRR Radio',
                          style: AppTheme.archivo(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                  Material(
                    color: const Color(0xEB11172A),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.close_rounded,
                            color: AppColors.guidaTextSecondary, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AspectRatio(
                aspectRatio: 1,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 250, maxHeight: 250),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: track.artGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.music_note_rounded,
                        size: 52, color: Colors.white70),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Text(
                    track.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.archivo(
                        fontWeight: FontWeight.w800,
                        fontSize: 21,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    track.artist,
                    textAlign: TextAlign.center,
                    style: AppTheme.archivo(
                        fontSize: 15, color: AppColors.guidaTextSecondary),
                  ),
                  const SizedBox(height: 14),
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = player.duration ?? Duration.zero;
                      final ratio = duration.inMilliseconds == 0
                          ? 0.0
                          : (position.inMilliseconds / duration.inMilliseconds)
                              .clamp(0, 1)
                              .toDouble();
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 5,
                              backgroundColor: const Color(0xFF1E1E1E),
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.guidaCyan),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_clock(position),
                                  style: AppTheme.archivo(
                                      fontSize: 12,
                                      color: AppColors.guidaTextSecondary)),
                              Text(_clock(duration),
                                  style: AppTheme.archivo(
                                      fontSize: 12,
                                      color: AppColors.guidaTextSecondary)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: controller.previous,
                        icon: const Icon(Icons.skip_previous_rounded,
                            color: AppColors.textPrimary, size: 30),
                      ),
                      const SizedBox(width: 12),
                      StreamBuilder<PlayerState>(
                        stream: player.playerStateStream,
                        builder: (context, snapshot) {
                          final playing = snapshot.data?.playing ?? false;
                          return Material(
                            color: AppColors.guidaCyan,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: controller.togglePlay,
                              child: SizedBox(
                                width: 62,
                                height: 62,
                                child: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: AppColors.guidaOnAccent,
                                  size: 32,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: controller.next,
                        icon: const Icon(Icons.skip_next_rounded,
                            color: AppColors.textPrimary, size: 30),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _QueueLabel(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: musicQueue.length,
                itemBuilder: (context, i) {
                  final t = musicQueue[i];
                  final isCurrent = i == trackIndex;
                  return Material(
                    color: isCurrent
                        ? AppColors.guidaCyan.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => controller.selectTrack(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: t.artGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.archivo(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isCurrent
                                              ? AppColors.guidaCyan
                                              : AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(t.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.archivo(
                                          fontSize: 12.5,
                                          color: AppColors.guidaTextSecondary)),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Text('ORA',
                                  style: AppTheme.archivo(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                      color: AppColors.guidaCyan)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueLabel extends StatelessWidget {
  const _QueueLabel();

  @override
  Widget build(BuildContext context) {
    return Text('IN CODA',
        style: AppTheme.archivo(
            fontSize: 11,
            letterSpacing: 2,
            color: AppColors.guidaTextSecondary));
  }
}
