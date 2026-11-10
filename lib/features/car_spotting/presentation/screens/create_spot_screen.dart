import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../providers/car_spotting_controller.dart';
import '../widgets/spot_heat_parts.dart';

/// NUOVO SPOT (HEAT, handoff §13): 3 step con barre inclinate in alto —
/// foto → dati auto → anteprima — e un'unica CTA in basso (AVANTI /
/// PUBBLICA SPOT). La validazione avviene al tocco di AVANTI con un
/// messaggio d'errore, come nel prototipo, invece di disabilitare il bottone.
///
/// Il design promette "+15 REP": lato server pubblicare non dà REP (la REP
/// arriva solo dai voti degli altri, migrazione 0025), quindi l'anteprima
/// dice questo invece di un premio che non arriverebbe.
class CreateSpotScreen extends ConsumerStatefulWidget {
  const CreateSpotScreen({super.key});

  @override
  ConsumerState<CreateSpotScreen> createState() => _CreateSpotScreenState();
}

class _CreateSpotScreenState extends ConsumerState<CreateSpotScreen> {
  int _step = 0;
  XFile? _photo;
  Uint8List? _photoBytes;
  String? _error;
  bool _busy = false;

  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _place = TextEditingController();
  final _caption = TextEditingController();

  @override
  void dispose() {
    for (final c in [_make, _model, _year, _place, _caption]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (picked == null) return;
      // Bytes (non File) così l'anteprima funziona anche su Web.
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = picked;
        _photoBytes = bytes;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = 'impossibile aprire la fotocamera o la galleria.');
    }
  }

  String? _validate() {
    switch (_step) {
      case 0:
        return _photo == null ? 'scatta o scegli una foto dell\'auto.' : null;
      case 1:
        if (_make.text.trim().isEmpty || _model.text.trim().isEmpty) {
          return 'marca e modello sono obbligatori.';
        }
        final y = _year.text.trim();
        if (y.isNotEmpty) {
          final n = int.tryParse(y);
          if (n == null || n < 1886 || n > DateTime.now().year + 1) {
            return 'anno non valido.';
          }
        }
        return null;
    }
    return null;
  }

  void _next() {
    if (_busy) return;
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    FocusScope.of(context).unfocus();
    if (_step < 2) {
      setState(() {
        _step++;
        _error = null;
      });
    } else {
      _publish();
    }
  }

  void _back() {
    if (_busy) return;
    if (_step == 0) {
      context.canPop() ? context.pop() : context.go(AppRoutes.carSpotting);
    } else {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  String? _opt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final spot =
          await ref.read(carSpottingControllerProvider.notifier).publishSpot(
                photo: _photo!,
                make: _make.text.trim(),
                model: _model.text.trim(),
                year: int.tryParse(_year.text.trim()),
                caption: _opt(_caption),
                locationLabel: _opt(_place),
              );
      if (!mounted) return;
      if (spot == null) {
        setState(() {
          _busy = false;
          _error = 'pubblicazione non riuscita. riprova.';
        });
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('spot pubblicato')));
      // Come nel prototipo: dopo la pubblicazione si apre il dettaglio.
      context.pushReplacement(
          AppRoutes.spotDetail.replaceFirst(':spotId', spot.id));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'pubblicazione non riuscita. controlla la connessione e riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColor.base,
        body: HeatBackground(
          glow: false,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppColor.ink),
                      ),
                      const Spacer(),
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        SizedBox(
                          width: 30,
                          // Step fatti/attuale in inchiostro: l'accento è
                          // della CTA in basso.
                          child: SkewBar(
                            value: i <= _step ? 1 : 0,
                            color: AppColor.ink,
                          ),
                        ),
                      ],
                      const SizedBox(width: 14),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: ScreenTitle('Nuovo spot', fontSize: 48),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                    children: [
                      ...switch (_step) {
                        0 => [
                            _PhotoBox(bytes: _photoBytes),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: HeatGhostButton(
                                    label: 'Scatta',
                                    icon: Icons.photo_camera_rounded,
                                    height: 54,
                                    onPressed: () => _pick(ImageSource.camera),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: HeatGhostButton(
                                    label: 'Galleria',
                                    icon: Icons.photo_library_rounded,
                                    height: 54,
                                    onPressed: () => _pick(ImageSource.gallery),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        1 => [
                            _Field(_make, 'marca * · es. BMW',
                                caps: TextCapitalization.characters),
                            _Field(_model, 'modello * · es. M3 E46',
                                caps: TextCapitalization.characters),
                            _Field(_year, 'anno (opzionale)',
                                keyboard: TextInputType.number),
                            _Field(_place, 'posizione generale · es. Milano',
                                caps: TextCapitalization.words),
                            _Field(_caption, 'descrizione (opzionale)',
                                lines: 3),
                          ],
                        _ => [
                            _Preview(
                              bytes: _photoBytes!,
                              brand: [
                                _make.text.trim().toUpperCase(),
                                _year.text.trim(),
                              ].where((e) => e.isNotEmpty).join(' · '),
                              model: _model.text.trim().toUpperCase(),
                              caption: _caption.text.trim(),
                              place: _place.text.trim(),
                            ),
                          ],
                      },
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.error_rounded,
                                size: 16, color: AppColor.danger),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: AppType.text(
                                    fontSize: 13, color: AppColor.danger),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: HeatButton(
                    label: _step < 2
                        ? 'Avanti'
                        : _busy
                            ? 'Pubblicazione…'
                            : 'Pubblica spot',
                    icon: _busy
                        ? null
                        : Icons.keyboard_double_arrow_right_rounded,
                    height: 58,
                    fontSize: 23,
                    onPressed: _busy ? null : _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return SizedBox(
        height: 300,
        child: Image.memory(bytes!, fit: BoxFit.cover),
      );
    }
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: AppColor.line),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          spotPhotoFallback,
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_rounded,
                  size: 46, color: AppColor.inkFaint),
              const SizedBox(height: 10),
              Text(
                'FOTO DELL\'AUTO',
                style: AppType.display(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  italic: false,
                  letterSpacing: 2,
                  color: AppColor.inkFaint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(
    this.controller,
    this.hint, {
    this.keyboard,
    this.lines = 1,
    this.caps = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final int lines;
  final TextCapitalization caps;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColor.line),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        textCapitalization: caps,
        cursorColor: AppColor.ink,
        style: AppType.text(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppType.text(fontSize: 15, color: AppColor.inkFaint),
          filled: true,
          fillColor: AppColor.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColor.ink)),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.bytes,
    required this.brand,
    required this.model,
    required this.caption,
    required this.place,
  });

  final Uint8List bytes;
  final String brand;
  final String model;
  final String caption;
  final String place;

  static const _shape = ChamferBorder(
    cut: 18,
    bottomLeft: true,
    side: BorderSide(color: AppColor.line),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecoration(color: AppColor.surface, shape: _shape),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: _shape),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 230,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes, fit: BoxFit.cover),
                  Positioned(
                    left: 0,
                    right: 40,
                    bottom: 14,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SpotPlate(brand: brand, model: model),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.isEmpty ? 'posizione nascosta' : place,
                    style:
                        AppType.text(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(caption,
                        style: AppType.text(fontSize: 14, height: 1.4)),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'anteprima · così lo vedranno gli altri piloti. '
                    'la REP arriva dai loro voti.',
                    style: AppType.text(fontSize: 13, color: AppColor.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
