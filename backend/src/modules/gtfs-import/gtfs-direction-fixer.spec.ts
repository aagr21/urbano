import {
    CsvRow,
    DIRECTION_THRESHOLDS,
    DirectionStop,
    detectOrientation,
    haversineMeters,
    isRepairEffective,
    orientationMetrics,
    reverseShapeRows,
    reverseStopTimesRows,
    secToTime,
    timeToSec,
    toDirectionStops,
} from "./gtfs-direction-fixer";

/**
 * Geometría sintética: un corredor recto de `n` paradas separadas ~111 m por
 * latitud. `buildStops(offsetLon)` genera una dirección desplazada hacia el
 * este, simulando el carril de vuelta.
 */
const buildStops = (n: number, offsetLon: number, reverse = false): DirectionStop[] => {
    const stops: DirectionStop[] = [];
    for (let i = 0; i < n; i++) {
        stops.push({
            stopSequence: i + 1,
            lat: -17.75 + i * 0.001,
            lon: -63.18 + offsetLon,
            distM: i * 111,
            arrivalSec: 6 * 3600 + i * 30,
            departureSec: 6 * 3600 + i * 30,
        });
    }
    return reverse ? stops.reverse() : stops;
};

const row = (seq: number, stopId: string, arrival: string, departure: string, dist: string): CsvRow => ({
    trip_id: "T1",
    arrival_time: arrival,
    departure_time: departure,
    stop_id: stopId,
    stop_sequence: String(seq),
    pickup_type: "0",
    drop_off_type: "0",
    shape_dist_traveled: dist,
});

/** Fila de stop_times con coordenadas, para poder reejecutar el detector. */
const geoRow = (s: DirectionStop, i: number, prefix: string): CsvRow => ({
    trip_id: `T${prefix}`,
    arrival_time: secToTime(s.arrivalSec),
    departure_time: secToTime(s.departureSec),
    stop_id: `${prefix}${i}`,
    stop_sequence: String(i + 1),
    stop_lat: String(s.lat),
    stop_lon: String(s.lon),
    shape_dist_traveled: String(s.distM ?? 0),
});

const withCoords = (rows: CsvRow[]): DirectionStop[] => toDirectionStops(rows);

describe("gtfs-direction-fixer (lógica pura)", () => {
    describe("haversineMeters", () => {
        it("0 m entre puntos idénticos", () => {
            expect(haversineMeters(-17.75, -63.18, -17.75, -63.18)).toBeCloseTo(0, 6);
        });
        it("~111 m por 0.001° de latitud", () => {
            expect(haversineMeters(-17.75, -63.18, -17.751, -63.18)).toBeGreaterThan(100);
            expect(haversineMeters(-17.75, -63.18, -17.751, -63.18)).toBeLessThan(120);
        });
    });

    describe("timeToSec / secToTime", () => {
        it("parsea HH:mm:ss", () => {
            expect(timeToSec("07:18:34")).toBe(7 * 3600 + 18 * 60 + 34);
            expect(timeToSec("06:00:00")).toBe(21600);
        });
        it("acepta horas > 24 (convención GTFS para viajes de madrugada)", () => {
            expect(timeToSec("25:05:00")).toBe(25 * 3600 + 300);
            expect(secToTime(25 * 3600 + 300)).toBe("25:05:00");
        });
        it("es inverso", () => {
            expect(secToTime(timeToSec("06:48:58"))).toBe("06:48:58");
        });
    });

    describe("detectOrientation", () => {
        it("clasifica como OK una vuelta espejo de la ida", () => {
            const ida = buildStops(60, 0);
            const vuelta = buildStops(60, 0.0004, true);
            const verdict = detectOrientation(ida, vuelta);
            expect(verdict.status).toBe("ok");
            if (verdict.metrics) {
                expect(verdict.metrics.mirrorOrderM).toBeLessThan(verdict.metrics.sameOrderM);
            }
        });

        it("detecta la vuelta duplicada en el mismo orden (defecto de la 75)", () => {
            const ida = buildStops(60, 0);
            // Mismo orden, apenas desplazada lateralmente: es el patrón defectuoso.
            const vuelta = buildStops(60, 0.0002);
            const verdict = detectOrientation(ida, vuelta);
            expect(verdict.status).toBe("reversed");
            if (verdict.status === "reversed") {
                expect(verdict.metrics.sameOrderM).toBeLessThanOrEqual(DIRECTION_THRESHOLDS.maxSameOrderM);
            }
        });

        it("es ambiguo cuando ningún orden coincide (corredores distintos)", () => {
            const ida = buildStops(40, 0);
            // Vuelta en una transversal muy lejana en longitud: ni espejo ni igual.
            const vuelta = buildStops(40, 0.05);
            expect(detectOrientation(ida, vuelta).status).not.toBe("reversed");
        });

        it("no decide con viajes de menos de 2 paradas", () => {
            expect(detectOrientation(buildStops(1, 0), buildStops(30, 0.0002)).status).toBe("incomplete");
        });

        it("orientationMetrics promuestra a 25 muestras como máximo", () => {
            expect(orientationMetrics(buildStops(200, 0), buildStops(200, 0.0002))?.samples).toBe(25);
        });
    });

    describe("reverseStopTimesRows", () => {
        const rows = [
            row(1, "A", "06:00:00", "06:00:00", "100.0"),
            row(2, "B", "06:30:00", "06:30:20", "5000.0"),
            row(3, "C", "07:00:00", "07:00:00", "9900.0"),
        ];
        const reversed = reverseStopTimesRows(rows);

        it("invierte el orden de las paradas y renumera stop_sequence", () => {
            expect(reversed.map(r => r["stop_id"])).toEqual(["C", "B", "A"]);
            expect(reversed.map(r => r["stop_sequence"])).toEqual(["1", "2", "3"]);
        });

        it("conserva la ventana horaria: arranca a la hora original y dura lo mismo", () => {
            expect(reversed[0]["arrival_time"]).toBe("06:00:00");
            expect(reversed[reversed.length - 1]["arrival_time"]).toBe("07:00:00");
        });

        it("espeja los tiempos intermedios respetando el dwell", () => {
            // B estaba a mitad de recorrido (salía 06:30:20) → sigue a mitad.
            expect(reversed[1]["arrival_time"]).toBe("06:29:40");
            expect(reversed[1]["departure_time"]).toBe("06:30:00");
        });

        it("refleja shape_dist_traveled manteniéndola monótona creciente", () => {
            // anchor = dist(primera) = 100, total = 9900 → 100+9900-old.
            const dists = reversed.map(r => Number(r["shape_dist_traveled"]));
            expect(dists).toEqual([100, 5000, 9900]);
            expect(dists.every((d, i) => i === 0 || d >= dists[i - 1])).toBe(true);
            // Los extremos conservan su valor original.
            expect(dists[0]).toBe(Number(rows[0]["shape_dist_traveled"]));
            expect(dists[dists.length - 1]).toBe(Number(rows[rows.length - 1]["shape_dist_traveled"]));
        });

        it("no muta las filas de entrada", () => {
            expect(rows[0]["stop_id"]).toBe("A");
            expect(rows[0]["stop_sequence"]).toBe("1");
        });

        it("tolera filas sin shape_dist_traveled", () => {
            const sinDist = rows.map(r => {
                const copy = { ...r };
                delete copy["shape_dist_traveled"];
                return copy;
            });
            const out = reverseStopTimesRows(sinDist);
            expect(out.map(r => r["stop_id"])).toEqual(["C", "B", "A"]);
            expect(out[0]["shape_dist_traveled"]).toBeUndefined();
        });

        it("los tipos de subida/bajada viajan con su parada", () => {
            const conTipos: CsvRow[] = [
                { ...row(1, "A", "06:00:00", "06:00:00", "0"), drop_off_type: "1" },
                { ...row(2, "B", "06:30:00", "06:30:00", "5000"), pickup_type: "1" },
            ];
            const out = reverseStopTimesRows(conTipos);
            expect(out[0]["stop_id"]).toBe("B");
            expect(out[0]["pickup_type"]).toBe("1");
            expect(out[1]["stop_id"]).toBe("A");
            expect(out[1]["drop_off_type"]).toBe("1");
        });
    });

    describe("reverseShapeRows", () => {
        const shape: CsvRow[] = [
            { shape_id: "SH1", shape_pt_lat: "-17.75", shape_pt_lon: "-63.18", shape_pt_sequence: "1" },
            { shape_id: "SH1", shape_pt_lat: "-17.76", shape_pt_lon: "-63.17", shape_pt_sequence: "2" },
            { shape_id: "SH1", shape_pt_lat: "-17.77", shape_pt_lon: "-63.16", shape_pt_sequence: "3" },
        ];

        it("renumera shape_pt_sequence al revés sin tocar coordenadas", () => {
            const out = reverseShapeRows(shape);
            expect(out.map(r => r["shape_pt_sequence"])).toEqual(["1", "2", "3"]);
            expect(out[0]["shape_pt_lat"]).toBe("-17.77");
            expect(out[2]["shape_pt_lat"]).toBe("-17.75");
        });

        it("mantiene el shape_id", () => {
            expect(reverseShapeRows(shape).every(r => r["shape_id"] === "SH1")).toBe(true);
        });
    });

    describe("isRepairEffective", () => {
        it("la inversión de una vuelta duplicada la convierte en espejo", () => {
            const idaStops = buildStops(60, 0);
            const vueltaStops = buildStops(60, 0.0002);
            const vueltaRows = vueltaStops.map((s, i) => geoRow(s, i, "V"));
            const after = withCoords(reverseStopTimesRows(vueltaRows));
            expect(detectOrientation(idaStops, vueltaStops).status).toBe("reversed");
            expect(detectOrientation(idaStops, after).status).toBe("ok");
            expect(isRepairEffective(idaStops, vueltaStops, after)).toBe(true);
        });

        it("invertir dos veces devuelve las filas originales", () => {
            const rows: CsvRow[] = buildStops(30, 0.0002).map((s, i) => geoRow(s, i, "V"));
            const doble = reverseStopTimesRows(reverseStopTimesRows(rows));
            expect(doble.map(r => r["stop_id"])).toEqual(rows.map(r => r["stop_id"]));
            expect(doble.map(r => r["arrival_time"])).toEqual(rows.map(r => r["arrival_time"]));
            expect(doble.map(r => r["shape_dist_traveled"])).toEqual(rows.map(r => r["shape_dist_traveled"]));
        });
    });
});
