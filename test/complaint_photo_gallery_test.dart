import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/complaints/presentation/widgets/complaint_photo.dart';
import 'package:urbano/src/features/complaints/presentation/widgets/complaint_photo_gallery.dart';
import 'package:urbano/src/features/complaints/presentation/widgets/complaint_photo_viewer.dart';

/// Las adjuntas de una queja se pueden ver TODAS.
///
/// Regresión del bug «el detalle solo pintaba `photoUrls.first`»: aquí se fija
/// que las miniaturas existen, que la foto principal cambia al tocarlas y que
/// el visor a pantalla completa recorre la lista completa con el gesto.
///
/// Bajo `flutter test` la red nunca se intenta de verdad: `Image.network`
/// recibe la respuesta 400 del client simulado y cae en su `errorBuilder`, así
/// que las cajas existen y son tactables sin depender de un blob.
void main() {
  const urls = [
    'https://blob.test/foto-1.jpg',
    'https://blob.test/foto-2.jpg',
    'https://blob.test/foto-3.jpg',
  ];

  Widget host(List<String> photos) => MaterialApp(
    home: Scaffold(
      body: ListView(children: [ComplaintPhotoGallery(urls: photos)]),
    ),
  );

  final main = find.byKey(const ValueKey('complaint-photo-main'));
  Finder thumb(int index) =>
      find.byKey(ValueKey('complaint-photo-thumb-$index'));

  /// URL que está pintando la foto principal (no la primera del arreglo).
  String mainPhotoUrl(WidgetTester tester) => tester
      .widget<ComplaintPhoto>(
        find.descendant(of: main, matching: find.byType(ComplaintPhoto)).first,
      )
      .url;

  /// Foto del visor que pinta ese enlace (el visor puede tener la vecina en
  /// caché, así que se afirma por enlace, no por posición en el árbol).
  Finder photoInViewer(Finder viewer, String url) => find.descendant(
    of: viewer,
    matching: find.byWidgetPredicate(
      (widget) => widget is ComplaintPhoto && widget.url == url,
    ),
  );

  testWidgets('una queja con varias fotos expone una miniatura por adjunto', (
    tester,
  ) async {
    await tester.pumpWidget(host(urls));
    await tester.pumpAndSettle();

    expect(main, findsOneWidget);
    for (var i = 0; i < urls.length; i++) {
      expect(thumb(i), findsOneWidget, reason: 'falta la miniatura $i');
    }
    // contador de la principal + texto «N fotos adjuntas» del post.
    expect(find.text('1/${urls.length}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar una miniatura cambia la foto principal', (tester) async {
    await tester.pumpWidget(host(urls));
    await tester.pumpAndSettle();

    expect(mainPhotoUrl(tester), urls.first);

    await tester.tap(thumb(1));
    await tester.pumpAndSettle();

    expect(mainPhotoUrl(tester), urls[1]);
    expect(find.text('2/${urls.length}'), findsOneWidget);

    // Y la miniatura ya elegida es la que abre el visor en ESA foto.
    await tester.tap(thumb(1));
    await tester.pumpAndSettle();
    expect(find.byType(ComplaintPhotoViewerScreen), findsOneWidget);
    expect(find.text('2 de ${urls.length}'), findsOneWidget);
  });

  testWidgets('la foto principal abre el visor y se desliza por todas', (
    tester,
  ) async {
    await tester.pumpWidget(host(urls));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(main));
    await tester.pumpAndSettle();

    final viewer = find.byType(ComplaintPhotoViewerScreen);
    expect(viewer, findsOneWidget);
    // El visor es una galería de páginas, no una foto suelta.
    final pages = find.descendant(of: viewer, matching: find.byType(PageView));
    expect(pages, findsOneWidget);
    expect(photoInViewer(viewer, urls[0]), findsWidgets);
    expect(find.text('1 de ${urls.length}'), findsOneWidget);

    // Más de media página: el drag del test termina sin velocidad, así que el
    // `PageView` solo se pasa de foto si el gesto cruza la mitad del encuadre.
    await tester.drag(pages, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(photoInViewer(viewer, urls[1]), findsWidgets);
    expect(find.text('2 de ${urls.length}'), findsOneWidget);

    await tester.drag(pages, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(photoInViewer(viewer, urls[2]), findsWidgets);
    expect(find.text('3 de ${urls.length}'), findsOneWidget);
    // El último no puede pasar de la última foto.
    await tester.drag(pages, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('3 de ${urls.length}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el visor cierra con la ✕ y tocando la foto', (tester) async {
    await tester.pumpWidget(host(urls));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(main));
    await tester.pumpAndSettle();

    final viewer = find.byType(ComplaintPhotoViewerScreen);
    expect(viewer, findsOneWidget);

    await tester.tap(
      find
          .descendant(of: viewer, matching: find.byIcon(Icons.close_rounded))
          .first,
    );
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);
    expect(main, findsOneWidget);

    await tester.tapAt(tester.getCenter(main));
    await tester.pumpAndSettle();
    expect(viewer, findsOneWidget);

    // Tocar la foto también cierra (el pie/puntos son IgnorePointer).
    await tester.tapAt(tester.getCenter(viewer));
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);
  });

  testWidgets('a ancho de móvil la galería cabe y sigue tactable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(urls));
    await tester.pumpAndSettle();

    // Un `RenderFlex` que desborda se reporta como excepción: aquí no puede
    // haber ninguna (la tira de miniaturas y el Stack de la principal viven del
    // ancho del post).
    expect(tester.takeException(), isNull);
    expect(thumb(0), findsOneWidget);

    await tester.tap(thumb(2));
    await tester.pumpAndSettle();
    expect(find.text('3/${urls.length}'), findsOneWidget);
  });

  testWidgets('con una sola foto no hay miniaturas ni contador', (
    tester,
  ) async {
    await tester.pumpWidget(host([urls.first]));
    await tester.pumpAndSettle();

    expect(main, findsOneWidget);
    expect(thumb(0), findsNothing);
    expect(find.text('1/1'), findsNothing);

    await tester.tapAt(tester.getCenter(main));
    await tester.pumpAndSettle();
    expect(find.byType(ComplaintPhotoViewerScreen), findsOneWidget);
    // Sin contador: no hay nada que deslizar, pero sí el pie de la foto.
    expect(find.text('Foto de la queja'), findsOneWidget);
  });
}
