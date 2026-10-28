/// Estilos de tiles de Urbano (MapTiler).
///
/// - **Claro**: estilo vectorial MapTiler *OpenStreetMap* (línea base OSM
///   limpia y moderna).
/// - **Oscuro**: estilo vectorial MapTiler *dataviz-dark* (fondo gris oscuro
///   neutro y etiquetas discretas: más suave y agradable que *darkmatter*,
///   que rayaba el negro con etiquetas brillantes).
///
/// Ambos usan la misma API key de MapTiler y se piden como `style.json`,
/// que es el formato que consume `maplibre_gl` directamente.
abstract class UrbanoMapStyles {
  /// API key de MapTiler (clave de estilo compartida por claro y oscuro).
  static const String _key = 'KO9LncNjixmZA2wW5OCK';

  /// Tema claro (vectorial, MapTiler OpenStreetMap).
  static const String light =
      'https://api.maptiler.com/maps/openstreetmap/style.json?key=$_key';

  /// Tema oscuro (vectorial, MapTiler dataviz-dark).
  static const String dark =
      'https://api.maptiler.com/maps/dataviz-dark/style.json?key=$_key';

  /// Texto de atribución de la superficie simulada (el motor real muestra el
  /// control de atribución nativo de MapLibre, que lee la atribución del
  /// estilo).
  static String attribution({required bool dark}) =>
      '© OpenStreetMap · © MapTiler';

  /// Fondo del mapa según el tema (para la carga nativa y el simulado).
  ///
  /// El oscuro replica el `background` de *dataviz-dark*: `hsl(0, 0%, 16%)`
  /// = `#292929`, así la carga nativa funde sin destello con el estilo.
  static String backgroundHex({required bool dark}) =>
      dark ? '#292929' : '#E8EEF5';
}
