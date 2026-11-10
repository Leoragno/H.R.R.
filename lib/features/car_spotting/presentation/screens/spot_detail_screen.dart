import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/spot.dart';
import '../../domain/entities/spot_comment.dart';
import '../providers/car_spotting_controller.dart';
import '../providers/car_spotting_provider.dart';
import '../widgets/spot_heat_parts.dart';

/// DETTAGLIO SPOT (HEAT, handoff §14): foto hero 330px sfumata nel fondo,
/// targa grande e voto medio in oro, autore, pannello IL TUO VOTO a 5
/// stelle (non si votano i propri spot), commenti e barra di scrittura
/// fissa in basso. Elimina solo per l'autore, con conferma.
///
/// Unico accento: il bottone INVIA. Stelle in oro (semantico del voto).
class SpotDetailScreen extends ConsumerStatefulWidget {
  final String spotId;
  const SpotDetailScreen({super.key, required this.spotId});

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  final _comment = TextEditingController();

  /// Voto appena dato, mostrato subito mentre il server risponde.
  int? _pendingVote;
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _vote(int v) async {
    setState(() => _pendingVote = v);
    final result = await ref
        .read(carSpottingControllerProvider.notifier)
        .rateSpot(spotId: widget.spotId, rating: v.toDouble());
    if (!mounted) return;
    setState(() => _pendingVote = null);
    _say(result != null
        ? 'voto $v/5 registrato'
        : 'voto non registrato. riprova.');
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final result = await ref
        .read(carSpottingControllerProvider.notifier)
        .addComment(spotId: widget.spotId, content: text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (result != null) {
      _comment.clear();
      FocusScope.of(context).unfocus();
      _say('commento pubblicato');
    } else {
      _say('commento non pubblicato. riprova.');
    }
  }

  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.carSpotting);

  Future<void> _delete(Spot spot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _ConfirmDialog(),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(carSpottingControllerProvider.notifier)
          .deleteSpot(spotId: spot.id, photoUrl: spot.photoUrl);
      if (!mounted) return;
      _say('spot eliminato');
      _leave();
    } catch (_) {
      if (mounted) _say('eliminazione non riuscita. riprova.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final spotAsync = ref.watch(spotByIdProvider(widget.spotId));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColor.base,
      body: spotAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColor.inkMuted),
          ),
        ),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _HeroIcon(icon: Icons.arrow_back_rounded, onTap: _leave),
              ),
              Expanded(
                child: Center(
                  child: Text('spot non trovato.',
                      style: AppType.text(color: AppColor.inkMuted)),
                ),
              ),
            ],
          ),
        ),
        data: (spot) {
          final mine = myId != null && myId == spot.authorId;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    _Hero(
                      spot: spot,
                      onBack: _leave,
                      onDelete: mine ? () => _delete(spot) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          SpotAuthorFace(
                              mascotId: spot.authorMascotId, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@${spot.authorUsername ?? 'pilota'}',
                                  style: AppType.text(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  spotMeta(spot),
                                  style: AppType.text(
                                      fontSize: 12, color: AppColor.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((spot.caption ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(spot.caption!.trim(),
                            style: AppType.text(fontSize: 14, height: 1.45)),
                      ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _VotePanel(
                        spotId: spot.id,
                        mine: mine,
                        pending: _pendingVote,
                        onVote: (v) => mine
                            ? _say('non puoi votare i tuoi spot')
                            : _vote(v),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
                      child: SectionLabel('Commenti'),
                    ),
                    _Comments(spotId: spot.id),
                  ],
                ),
              ),
              _CommentBar(
                controller: _comment,
                sending: _sending,
                onSend: _send,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.spot, required this.onBack, this.onDelete});

  final Spot spot;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 330 + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SpotPhoto(url: spot.photoUrl),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000B0912), AppColor.base],
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 10,
            right: 10,
            child: Row(
              children: [
                _HeroIcon(icon: Icons.arrow_back_rounded, onTap: onBack),
                const Spacer(),
                if (onDelete != null)
                  _HeroIcon(
                    icon: Icons.delete_rounded,
                    color: AppColor.danger,
                    onTap: onDelete!,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (spotBrandLine(spot).isNotEmpty)
                        Text(
                          spotBrandLine(spot),
                          style: AppType.display(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            italic: false,
                            letterSpacing: 2,
                            color: AppColor.inkMuted,
                          ),
                        ),
                      Text(
                        spotModelLine(spot),
                        style: AppType.display(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: .9,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      spotRatingLabel(spot),
                      style: AppType.display(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: .9,
                        color: AppColor.gold,
                      ),
                    ),
                    Text(
                      spot.ratingCount == 1
                          ? '1 voto'
                          : '${spot.ratingCount} voti',
                      style:
                          AppType.text(fontSize: 12, color: AppColor.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({
    required this.icon,
    required this.onTap,
    this.color = AppColor.ink,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return HeatPressable(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: const ShapeDecoration(
          color: Color(0xCC0B0912),
          shape: SlantBorder(left: 8, right: 8),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}

class _VotePanel extends ConsumerWidget {
  const _VotePanel({
    required this.spotId,
    required this.mine,
    required this.pending,
    required this.onVote,
  });

  final String spotId;
  final bool mine;
  final int? pending;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = mine
        ? null
        : ref.watch(myRatingForSpotProvider(spotId)).valueOrNull?.rating;
    final current = pending ?? stored?.round() ?? 0;
    final hint = mine
        ? 'è il tuo spot'
        : current > 0
            ? 'hai votato $current/5'
            : 'tocca una stella';

    return HeatPanel(
      shape:
          const ChamferBorder(cut: 14, side: BorderSide(color: AppColor.line)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel('Il tuo voto', trailing: hint),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var v = 1; v <= 5; v++) ...[
                if (v > 1) const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: '$v stelle',
                    child: HeatPressable(
                      onTap: () => onVote(v),
                      child: Container(
                        height: 50,
                        color: AppColor.deep,
                        alignment: Alignment.center,
                        child: Icon(
                          v <= current
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 32,
                          color:
                              v <= current ? AppColor.gold : AppColor.inkFaint,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Comments extends ConsumerWidget {
  const _Comments({required this.spotId});

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(spotCommentsProvider(spotId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColor.inkMuted),
            ),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('commenti non disponibili.',
              style: AppType.text(fontSize: 14, color: AppColor.inkMuted)),
        ),
        data: (list) => list.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('nessun commento ancora. scrivi il primo.',
                    style:
                        AppType.text(fontSize: 14, color: AppColor.inkMuted)),
              )
            : Column(
                children: [for (final c in list) _CommentRow(comment: c)],
              ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final SpotComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.surfaceHigh)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '@${comment.authorUsername ?? 'pilota'} · ${spotAgo(comment.createdAt)}',
            style: AppType.text(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColor.inkMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(comment.content, style: AppType.text(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}

class _CommentBar extends StatelessWidget {
  const _CommentBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColor.line),
    );
    return Container(
      decoration: const BoxDecoration(
        color: AppColor.base,
        border: Border(top: BorderSide(color: AppColor.line)),
      ),
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, 10 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLength: 500,
              cursorColor: AppColor.ink,
              style: AppType.text(fontSize: 14),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                hintText: 'scrivi un commento…',
                hintStyle: AppType.text(fontSize: 14, color: AppColor.inkFaint),
                filled: true,
                fillColor: AppColor.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: AppColor.ink)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          HeatPressable(
            onTap: sending ? null : onSend,
            child: Container(
              width: 52,
              height: 48,
              decoration: ShapeDecoration(
                color: AppColor.accent,
                shape: const SlantBorder(left: 8, right: 8),
              ),
              child: sending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColor.onAccent),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      size: 22, color: AppColor.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColor.surfaceHigh,
      shape:
          const ChamferBorder(cut: 16, side: BorderSide(color: AppColor.line)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ELIMINARE QUESTO SPOT?',
              style: AppType.display(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              "L'azione non è reversibile.",
              style: AppType.text(fontSize: 14, color: AppColor.inkMuted),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: HeatGhostButton(
                    label: 'Annulla',
                    height: 48,
                    fontSize: 16,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: HeatButton(
                    label: 'Elimina',
                    icon: null,
                    height: 48,
                    fontSize: 18,
                    color: AppColor.danger,
                    glow: false,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
