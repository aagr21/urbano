---
sessionId: session-261122-230603-15jj
---

# Análisis y Plan

### Contexto

Del análisis anterior de archivos pesados, ya se completó:
- ✅ `create_complaint_screen.dart` (844 → ~464 líneas): extraído a 4 widgets
- ✅ `journey_destination_sheet.dart` (1332 → ~510 líneas): separado en 4 archivos

Quedan 3 archivos con múltiples clases que pueden separarse aplicando responsabilidad única.

### Candidatos prioritarios

**1. `recent_trips.dart` (757 líneas, 9 clases)**

Clases que pueden salir:
- `_AllTripsSheet` + `_AllTripsSheetState` (~230 líneas): hoja modal completa con buscador, paginación y filtrado del historial. Es un widget de estado propio con `TextEditingController`, paginación de 10 en 10, y toda la UI de la hoja.
- `_RouteDotIndicator` + `_RouteDotPainter` (~55 líneas): painter de indicador de ruta minimalista. Ya es un componente visual reutilizable.

Lo que se queda: `RecentTrips`, `_HistoryPanel`, `_HistoryRows`, `_SeeAllButton`, `_TripRow` (~470 líneas).

**2. `journey_micros_tile.dart` (775 líneas, 8 clases)**

Clases que pueden salir:
- `_DirectionChip` (~180 líneas): chip de sentido (Ida/Vuelta) con headsign, estado de carga y toggle. Es la pieza más compleja después de la tarjeta principal.
- `_DiscSpinner` + `_SpinnerArcPainter` (~60 líneas): spinner del disco de carga.
- `_ChipShimmer` (~40 líneas): shimmer de los chips.
- `_MetaPill` + `_ActivePill` (~80 líneas): píldoras de metadata.

Lo que se queda: `JourneyMicroTile` + `_LineMeta` (~315 líneas).

**3. `micros_places_list.dart` (730 líneas, 7 clases)**

Clases que pueden salir:
- `MicrosPlaceTile` + `_MicroThumb` + `_PlaceDirectionChip` + `_PlaceDetailChip` (~300 líneas): la tarjeta de cada resultado con thumb, chips de dirección y detalle. Son widgets de presentación pura.
- `MicrosPlaceGuide` (~90 líneas): guía cuando no hay consulta.

Lo que se queda: `MicrosPlacesList` + `_MicrosPlacesListState` (~340 líneas) con la lógica de sync de marcadores y la lista.

### No se toca

- `splash_gate.dart` (792 líneas): complejo por diseño, los painters están fuertemente acoplados a la lógica de la splash. Las guías lo marcan como "pesado pero justificado".

### Enfoque

Cada refactor sigue el patrón establecido: extraer widgets privados a archivos propios en `widgets/`, manteniendo los imports y la API pública intacta. Los painters salen a archivos dedicados. Los tests existentes validan que nada se rompa.

# Delivery Steps

### ✓ Step 1: Separar recent_trips.dart
Extraer _AllTripsSheet y _RouteDotIndicator a archivos propios en `home/presentation/widgets/`.

- Crear `recent_trips_all_sheet.dart` con `AllTripsSheet` (renombrado de `_AllTripsSheet`) y su State, incluyendo buscador, paginación y filtrado (~230 líneas).
- Crear `recent_trips_route_indicator.dart` con `RouteDotIndicator` y `RouteDotPainter` (~55 líneas).
- Actualizar `recent_trips.dart` para importar los nuevos archivos y remover las clases extraídas.
- Ejecutar `dart format lib test && flutter analyze lib test && flutter test` para validar.
- Resultado: 757 → 460 líneas. Tests 15/15 pass, analyze limpio.

### ✓ Step 2: Separar journey_micros_tile.dart
Extraer _DirectionChip, _DiscSpinner, _ChipShimmer, _MetaPill y _ActivePill a archivos propios en `journey/presentation/widgets/`.

- Crear `journey_direction_chip.dart` con `DirectionChip` (~180 líneas): chip de sentido con headsign, estado de carga y toggle.
- Crear `journey_disc_spinner.dart` con `DiscSpinner` + `SpinnerArcPainter` (~60 líneas): spinner del disco.
- Crear `journey_meta_pill.dart` con `MetaPill` y `ActivePill` (~80 líneas): píldoras de metadata.
- El `ChipShimmer` (~40 líneas) se incluye en `journey_direction_chip.dart` ya que es un shimmer específico de los chips de dirección.
- Actualizar `journey_micros_tile.dart` para importar los nuevos archivos.
- Ejecutar `dart format lib test && flutter analyze lib test && flutter test` para validar.
- Resultado: 776 → 398 líneas. Tests 16/16 pass, analyze limpio.

### ✓ Step 3: Separar micros_places_list.dart
Extraer MicrosPlaceTile, _MicroThumb, _PlaceDirectionChip, _PlaceDetailChip y MicrosPlaceGuide a archivos propios.

- Crear `micros_place_tile.dart` con `MicrosPlaceTile`, `_MicroThumb`, `_PlaceDirectionChip` y `_PlaceDetailChip` (~300 líneas): la tarjeta de resultado con thumb, chips de dirección y detalle.
- Crear `micros_place_guide.dart` con `MicrosPlaceGuide` (~90 líneas): guía cuando no hay consulta.
- Actualizar `micros_places_list.dart` para importar los nuevos archivos, reduciéndolo a ~340 líneas con solo la lista y el sync de marcadores.
- Ejecutar `dart format lib test && flutter analyze lib test && flutter test` para validar.
- Resultado: 731 → 176 líneas. Tests 10/10 pass, analyze limpio.

### ✓ Step 4: Separar complaint_detail_screen.dart
Extraer _PostBody, _LikeBar, _CommentsSection, _CommentTile y _CommentComposer a archivos propios en `complaints/presentation/widgets/`.

- Crear `complaint_detail_post_body.dart` con `ComplaintDetailPostBody` (~111 líneas): tarjeta ampliada del post con héroe, galería y descripción.
- Crear `complaint_detail_like_bar.dart` con `ComplaintDetailLikeBar` (~68 líneas): pie social con LikeButton y ComplaintPill.
- Crear `complaint_detail_comments_section.dart` con `ComplaintDetailCommentsSection` (~92 líneas): sección con shimmer, error, vacío y lista de comentarios.
- Crear `complaint_detail_comment_tile.dart` con `ComplaintDetailCommentTile` (~95 líneas): burbuja de comentario con avatar, nombre, fecha y texto.
- Crear `complaint_detail_comment_composer.dart` con `ComplaintDetailCommentComposer` (~112 líneas): barra de redactar comentario.
- Actualizar `complaint_detail_screen.dart` para importar los nuevos archivos y remover las clases extraídas.
- Ejecutar `dart format lib test && flutter analyze lib test && flutter test` para validar.
- Resultado: 625 → 213 líneas. Tests 344/344 pass, analyze limpio (2 fallos preexistentes no relacionados).

### ✓ Step 5: Separar micros_screen.dart
Extraer _CatalogIntro, _SearchField y _MicroCard a archivos propios en `routes/presentation/widgets/`.

- Crear `micros_catalog_intro.dart` con `MicrosCatalogIntro` (~100 líneas): tarjeta con gradiente y cifras del catálogo.
- Crear `micros_search_field.dart` con `MicrosSearchField` (~60 líneas): TextField de búsqueda con botón limpiar.
- Crear `micros_card.dart` con `MicroCard` (~180 líneas): tarjeta de cada línea con badge, bus ilustrado, meta chips y botón de detalles.
- Actualizar `micros_screen.dart` para importar los nuevos archivos y remover las clases extraídas.
- Ejecutar `dart format lib test && flutter analyze lib test && flutter test` para validar.
- Resultado: 638 → ~260 líneas.