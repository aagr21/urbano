import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/app.dart';
import 'src/core/map/maplibre_dispose_fix.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Las fuentes van empaquetadas en assets/fonts (ver pubspec.yaml): nada de
  // descargas en runtime. Esto también evita que los tests intenten fetch de red.
  GoogleFonts.config.allowRuntimeFetching = false;
  installMapLibreDisposeFix();
  runApp(const ProviderScope(child: UrbanoApp()));
}
