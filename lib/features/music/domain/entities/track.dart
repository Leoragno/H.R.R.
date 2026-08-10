import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Traccia della coda musicale. `url` punta a un file audio reale
/// (streaming diretto via just_audio, nessun download/cache locale).
class Track extends Equatable {
  final String title;
  final String artist;
  final String url;
  final List<Color> artGradient;

  const Track({
    required this.title,
    required this.artist,
    required this.url,
    required this.artGradient,
  });

  @override
  List<Object?> get props => [title, artist, url];
}
