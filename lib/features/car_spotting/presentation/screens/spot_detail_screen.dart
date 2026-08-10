import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/spot.dart';
import '../../domain/entities/spot_comment.dart';
import '../providers/car_spotting_controller.dart';
import '../providers/car_spotting_provider.dart';
import '../widgets/rarity_badge.dart';
import '../widgets/rating_selector.dart';
import '../widgets/star_rating.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  final String spotId;
  const SpotDetailScreen({super.key, required this.spotId});

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _rate(double rating) async {
    final controller = ref.read(carSpottingControllerProvider.notifier);
    final result =
        await controller.rateSpot(spotId: widget.spotId, rating: rating);
    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hai valutato ${rating.toStringAsFixed(1)}★')),
      );
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    _commentController.clear();
    await ref
        .read(carSpottingControllerProvider.notifier)
        .addComment(spotId: widget.spotId, content: content);
  }

  Future<void> _confirmDelete(Spot spot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
        title: Text('Eliminare questo spot?',
            style: AppTheme.archivo(
                fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        content: Text('L\'azione non è reversibile.',
            style: AppTheme.archivo(color: AppColors.guidaTextSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Elimina',
                  style: AppTheme.archivo(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(carSpottingControllerProvider.notifier).deleteSpot(
          spotId: spot.id,
          photoUrl: spot.photoUrl,
        );
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final spotAsync = ref.watch(spotByIdProvider(widget.spotId));
    final myRatingAsync = ref.watch(myRatingForSpotProvider(widget.spotId));
    final commentsAsync = ref.watch(spotCommentsProvider(widget.spotId));
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.guidaBg2,
      body: spotAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.guidaCyan)),
        error: (err, st) => Center(
            child: Text('Errore: $err',
                style: AppTheme.archivo(color: AppColors.guidaTextSecondary))),
        data: (spot) {
          final title = [spot.detectedMake, spot.detectedModel]
              .where((s) => s != null && s.isNotEmpty)
              .join(' ');

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 11,
                        child: CachedNetworkImage(
                          imageUrl: spot.photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) =>
                              Container(color: AppColors.surfaceElevated),
                          errorWidget: (c, u, e) => Container(
                              color: AppColors.surfaceElevated,
                              child: const Icon(Icons.broken_image_rounded,
                                  color: AppColors.textDisabled)),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.black.withValues(alpha: 0),
                              ],
                              stops: const [0, 0.5],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title.isEmpty ? 'Auto sconosciuta' : title,
                                style: AppTheme.chakraPetch(
                                    fontSize: 28, color: AppColors.textPrimary),
                              ),
                            ),
                            RarityBadge(rarity: spot.detectedRarity),
                          ],
                        ),
                        if (spot.detectedYear != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${spot.detectedYear}',
                                style: AppTheme.archivo(
                                    color: AppColors.guidaTextSecondary,
                                    fontSize: 14)),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            StarRating(rating: spot.averageRating, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${spot.averageRating.toStringAsFixed(1)} · ${spot.ratingCount} voti',
                              style: AppTheme.archivo(
                                  color: AppColors.guidaTextSecondary,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                        if (spot.authorUsername != null ||
                            spot.locationLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              [
                                if (spot.authorUsername != null)
                                  '@${spot.authorUsername}',
                                if (spot.locationLabel != null)
                                  spot.locationLabel,
                              ].join(' · '),
                              style: AppTheme.archivo(
                                  color: AppColors.guidaCyan, fontSize: 12.5),
                            ),
                          ),
                        if (spot.caption != null && spot.caption!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(spot.caption!,
                                style: AppTheme.archivo(
                                    color: AppColors.textPrimary,
                                    fontSize: 14)),
                          ),
                        const SizedBox(height: 24),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('IL TUO VOTO',
                                  style: AppTheme.archivo(
                                      color: AppColors.guidaTextSecondary,
                                      fontSize: 11,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              myRatingAsync.when(
                                loading: () => const SizedBox(
                                    height: 36,
                                    child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.guidaCyan))),
                                error: (e, s) => Text(
                                    'Errore nel caricare il voto',
                                    style: AppTheme.archivo(
                                        color: AppColors.danger)),
                                data: (myRating) => StarRatingSelector(
                                  value: myRating?.rating ?? 0,
                                  onChanged: _rate,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text('COMMENTI',
                            style: AppTheme.archivo(
                                color: AppColors.guidaTextSecondary,
                                fontSize: 11,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                style: AppTheme.archivo(
                                    color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Scrivi un commento…',
                                  hintStyle: AppTheme.archivo(
                                      color: AppColors.guidaTextSecondary),
                                  filled: true,
                                  fillColor: const Color(0xE50C1120),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send_rounded,
                                  color: AppColors.guidaCyan),
                              onPressed: _submitComment,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        commentsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.guidaCyan)),
                          ),
                          error: (e, s) => Text(
                              'Impossibile caricare i commenti',
                              style: AppTheme.archivo(color: AppColors.danger)),
                          data: (comments) => _CommentList(comments: comments),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 14,
                left: 14,
                child: _RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => context.pop(),
                ),
              ),
              if (currentUserId != null && currentUserId == spot.authorId)
                Positioned(
                  top: 14,
                  right: 14,
                  child: _RoundIconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: () => _confirmDelete(spot),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentList extends StatelessWidget {
  final List<SpotComment> comments;
  const _CommentList({required this.comments});

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Nessun commento ancora.',
            style:
                AppTheme.archivo(color: AppColors.textDisabled, fontSize: 13)),
      );
    }
    return Column(
      children: [
        for (final comment in comments)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${comment.authorUsername ?? 'utente'}',
                    style: AppTheme.archivo(
                        color: AppColors.guidaCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(comment.content,
                    style: AppTheme.archivo(
                        color: AppColors.textPrimary, fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB80C1120),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
