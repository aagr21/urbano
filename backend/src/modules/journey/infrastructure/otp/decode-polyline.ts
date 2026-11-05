/**
 * Decodifica una Google Encoded Polyline (la que usa OTP2 en
 * `legGeometry.points`) en pares `[lon, lat]` (GeoJSON).
 * https://developers.google.com/maps/documentation/utilities/polylinealgorithm
 *
 * `scale` es la precisión de la codificación: 1e5 (default, OTP/Google) o
 * 1e6 (polyline6, la que devuelve Valhalla por defecto).
 */
export function decodePolylineToGeoJSON(
  encoded: string,
  scale = 1e5
): number[][] {
  const coordinates: number[][] = [];
  let index = 0;
  // Acumuladores en ENTEROS (exactos); la escala se aplica al publicar para
  // evitar errores de coma flotante por suma sucesiva.
  let lat = 0;
  let lon = 0;

  while (index < encoded.length) {
    let result = 1;
    let shift = 0;
    let b: number;
    do {
      b = encoded.charCodeAt(index++) - 63 - 1;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lat += result & 1 ? ~(result >> 1) : result >> 1;

    result = 1;
    shift = 0;
    do {
      b = encoded.charCodeAt(index++) - 63 - 1;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lon += result & 1 ? ~(result >> 1) : result >> 1;

    coordinates.push([lon / scale, lat / scale]);
  }

  return coordinates;
}
