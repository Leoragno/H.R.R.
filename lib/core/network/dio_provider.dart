import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_provider.g.dart';

/// Client HTTP condiviso per le chiamate a servizi esterni (Overpass, Waze
/// — vedi lib/features/radar/). Un solo Dio per tutta l'app, stesso
/// principio del [supabaseClientProvider] unico.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
