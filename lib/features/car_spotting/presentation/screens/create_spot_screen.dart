import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../providers/car_spotting_controller.dart';

enum _Step { photo, details, preview, publishing }

/// Flusso di pubblicazione a 4 step: foto -> dati auto -> anteprima ->
/// pubblica. Nessun riconoscimento automatico: marca/modello/anno sono
/// inseriti a mano (AI/TFLite predisposta ma non collegata in questo giro).
/// Restyle secondo "HRR Car Spotting.dc.html" righe 248-311.
class CreateSpotScreen extends ConsumerStatefulWidget {
  const CreateSpotScreen({super.key});

  @override
  ConsumerState<CreateSpotScreen> createState() => _CreateSpotScreenState();
}

class _CreateSpotScreenState extends ConsumerState<CreateSpotScreen> {
  _Step _step = _Step.photo;
  XFile? _photo;
  Uint8List? _photoBytes;
  String? _publishError;

  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Il pulsante AVANTI dipende da marca/modello: senza questi listener
    // digitare non ricostruisce lo State (TextEditingController non lo fa
    // da solo) e _canLeaveDetailsStep resta bloccato al valore iniziale
    // (vuoto), impedendo di proseguire.
    _makeController.addListener(_onDetailsChanged);
    _modelController.addListener(_onDetailsChanged);
  }

  void _onDetailsChanged() => setState(() {});

  @override
  void dispose() {
    _makeController.removeListener(_onDetailsChanged);
    _modelController.removeListener(_onDetailsChanged);
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    // Bytes (non File/dart:io) così l'anteprima funziona anche su Flutter
    // Web, dove Image.file non è supportato.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = picked;
      _photoBytes = bytes;
    });
  }

  bool get _canLeavePhotoStep => _photo != null;
  bool get _canLeaveDetailsStep =>
      _makeController.text.trim().isNotEmpty &&
      _modelController.text.trim().isNotEmpty;

  Future<void> _publish() async {
    setState(() {
      _step = _Step.publishing;
      _publishError = null;
    });

    try {
      final year = int.tryParse(_yearController.text.trim());
      final result =
          await ref.read(carSpottingControllerProvider.notifier).publishSpot(
                photo: _photo!,
                make: _makeController.text.trim(),
                model: _modelController.text.trim(),
                year: year,
                caption: _captionController.text.trim().isEmpty
                    ? null
                    : _captionController.text.trim(),
                locationLabel: _locationController.text.trim().isEmpty
                    ? null
                    : _locationController.text.trim(),
              );

      if (!mounted) return;
      if (result == null) {
        setState(() => _publishError = 'Pubblicazione non riuscita. Riprova.');
      } else {
        context.go(AppRoutes.carSpotting);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishError = 'Pubblicazione non riuscita: $e');
    }
  }

  void _next() {
    setState(() {
      _step = switch (_step) {
        _Step.photo => _Step.details,
        _Step.details => _Step.preview,
        _Step.preview => _Step.preview,
        _Step.publishing => _Step.publishing,
      };
    });
  }

  void _back() {
    setState(() {
      _step = switch (_step) {
        _Step.photo => _Step.photo,
        _Step.details => _Step.photo,
        _Step.preview => _Step.details,
        _Step.publishing => _Step.preview,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.guidaBg2,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Nuovo Spot',
                      textAlign: TextAlign.center,
                      style: AppTheme.chakraPetch(
                          fontSize: 22, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 46),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: switch (_step) {
                  _Step.photo =>
                    _PhotoStep(photoBytes: _photoBytes, onPick: _pickPhoto),
                  _Step.details => _DetailsStep(
                      makeController: _makeController,
                      modelController: _modelController,
                      yearController: _yearController,
                      captionController: _captionController,
                      locationController: _locationController,
                    ),
                  _Step.preview => _PreviewStep(
                      photoBytes: _photoBytes!,
                      make: _makeController.text.trim(),
                      model: _modelController.text.trim(),
                      year: _yearController.text.trim(),
                      caption: _captionController.text.trim(),
                      locationLabel: _locationController.text.trim(),
                    ),
                  _Step.publishing =>
                    _PublishingStep(error: _publishError, onRetry: _publish),
                },
              ),
              if (_step != _Step.publishing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_step != _Step.photo) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _back,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            side: const BorderSide(color: Color(0x33A0AAFF)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Indietro'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: NeonCtaButton(
                        label:
                            _step == _Step.preview ? 'Pubblica Spot' : 'Avanti',
                        minHeight: 56,
                        onPressed: switch (_step) {
                          _Step.photo => _canLeavePhotoStep ? _next : null,
                          _Step.details => _canLeaveDetailsStep ? _next : null,
                          _Step.preview => _publish,
                          _Step.publishing => null,
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoStep extends StatelessWidget {
  final Uint8List? photoBytes;
  final ValueChanged<ImageSource> onPick;
  const _PhotoStep({required this.photoBytes, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x33A0AAFF)),
                  color: const Color(0xFF0A0F19),
                ),
                clipBehavior: Clip.antiAlias,
                width: double.infinity,
                child: photoBytes != null
                    ? Image.memory(photoBytes!, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(Icons.directions_car_rounded,
                            size: 64, color: AppColors.textDisabled),
                      ),
              ),
              if (photoBytes == null)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xB20A0E12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x29FFFFFF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFFFF4444), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text('LIVE',
                            style: AppTheme.archivo(
                                fontSize: 12, color: const Color(0xFF9DD4FF))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: NeonCtaButton(
                label: 'Scatta',
                icon: Icons.camera_alt_rounded,
                minHeight: 54,
                fontSize: 15,
                onPressed: () => onPick(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Galleria'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.guidaCyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0x33A0AAFF)),
                  backgroundColor: const Color(0xE50C1120),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailsStep extends StatelessWidget {
  final TextEditingController makeController;
  final TextEditingController modelController;
  final TextEditingController yearController;
  final TextEditingController captionController;
  final TextEditingController locationController;

  const _DetailsStep({
    required this.makeController,
    required this.modelController,
    required this.yearController,
    required this.captionController,
    required this.locationController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _field(makeController, 'Marca *', hint: 'es. BMW'),
        _field(modelController, 'Modello *', hint: 'es. M3 E46'),
        _field(yearController, 'Anno (opzionale)',
            hint: 'es. 2004', keyboardType: TextInputType.number),
        _field(captionController, 'Descrizione (opzionale)', maxLines: 3),
        _field(locationController, 'Posizione generale (opzionale)',
            hint: 'es. Milano'),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: AppTheme.archivo(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTheme.archivo(color: AppColors.guidaTextSecondary),
          hintText: hint,
          filled: true,
          fillColor: const Color(0xE50C1120),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x33A0AAFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x33A0AAFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.guidaCyan),
          ),
        ),
      ),
    );
  }
}

class _PreviewStep extends StatelessWidget {
  final Uint8List photoBytes;
  final String make;
  final String model;
  final String year;
  final String caption;
  final String locationLabel;

  const _PreviewStep({
    required this.photoBytes,
    required this.make,
    required this.model,
    required this.year,
    required this.caption,
    required this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.memory(photoBytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        Text('$make $model'.trim(),
            style: AppTheme.chakraPetch(
                fontSize: 22, color: AppColors.textPrimary)),
        if (year.isNotEmpty)
          Text(year,
              style: AppTheme.archivo(color: AppColors.guidaTextSecondary)),
        if (locationLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(locationLabel,
                style:
                    AppTheme.archivo(color: AppColors.guidaCyan, fontSize: 13)),
          ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(caption,
                style: AppTheme.archivo(
                    color: AppColors.textPrimary, fontSize: 14)),
          ),
      ],
    );
  }
}

class _PublishingStep extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _PublishingStep({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(error!,
                textAlign: TextAlign.center,
                style: AppTheme.archivo(color: AppColors.guidaTextSecondary)),
            const SizedBox(height: 20),
            NeonCtaButton(label: 'Riprova', minHeight: 52, onPressed: onRetry),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.guidaCyan),
          const SizedBox(height: 16),
          Text('Pubblicazione in corso…',
              style: AppTheme.archivo(color: AppColors.guidaTextSecondary)),
        ],
      ),
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
      color: const Color(0xE50C1120),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}
