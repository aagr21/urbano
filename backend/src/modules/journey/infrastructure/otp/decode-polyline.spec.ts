import { decodePolylineToGeoJSON } from './decode-polyline';

describe('decodePolylineToGeoJSON', () => {
  // Ejemplo oficial de la docs de Google (lat/lon):
  // 38.5, -120.2 | 40.7, -120.95 | 43.252, -126.453
  it('decodifica la polyline de ejemplo de Google a pares [lon, lat]', () => {
    expect(decodePolylineToGeoJSON('_p~iF~ps|U_ulLnnqC_mqNvxq`@')).toEqual([
      [-120.2, 38.5],
      [-120.95, 40.7],
      [-126.453, 43.252],
    ]);
  });

  it('decodifica coordenadas de Santa Cruz a 5 decimales', () => {
    // -63.15, -17.78 (izquierda = lon, derecha = lat)
    expect(decodePolylineToGeoJSON('~sokBn~l`K')).toEqual([[-63.15, -17.78]]);
    expect(decodePolylineToGeoJSON('~sokBn~l`KzEnK')).toEqual([
      [-63.15, -17.78],
      [-63.152, -17.7811],
    ]);
  });

  it('devuelve vacío con input vacío', () => {
    expect(decodePolylineToGeoJSON('')).toEqual([]);
  });
});
