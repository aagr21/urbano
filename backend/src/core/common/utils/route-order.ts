/**
 * Columnas de orden natural para `route_short_name`.
 *
 * El feed mezcla líneas como "9", "60 ROJO", "104 C" o "133 LA GUARDIA". Un
 * `ORDER BY route_short_name` las ordena como texto (1, 10, 100, 104 C, 105…),
 * así que aquí se ordena primero por el **número** ("60 ROJO" va junto al 60,
 * no junto al 6) y, entre líneas del mismo número, por el **sufijo alfabético**
 * ("60 ROJO" < "60 VERDE"; el número solo, sin sufijo, va antes que sus
 * variantes). Las líneas sin número quedan al final (NULLS LAST implícito en
 * `ASC`).
 *
 * Esperan el alias `r` para la tabla `route`. La tercera columna es el nombre
 * literal y sirve de desempate final; el llamador puede añadir `r.route_id`
 * para que la paginación sea determinista.
 */
export const ROUTE_NATURAL_ORDER_COLUMNS = [
  `NULLIF(substring(r.route_short_name from '^[0-9]+'), '')::int`,
  `COALESCE(btrim(regexp_replace(r.route_short_name, '^[0-9]+', '')), '')`,
  'r.route_short_name',
] as const;
