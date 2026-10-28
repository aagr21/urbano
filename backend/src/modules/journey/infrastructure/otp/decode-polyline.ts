/**
 * Decodifica una Google Encoded Polyline (la que usa OTP2 en
 * `legGeometry.points`) en pares `[lon, lat]` (GeoJSON).
 * https://developers.google.com/maps/documentation/utilities/polylinealgorithm
 */
export function decodePolylineToGeoJSON(encoded: string): number[][] {
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

    coordinates.push([lon / 1e5, lat / 1e5]);
  }

  return coordinates;
}
