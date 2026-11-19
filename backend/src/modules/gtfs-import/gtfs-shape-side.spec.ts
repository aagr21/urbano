import {
    LatLon,
    OneWaySegment,
    buildOneWayIndex,
    decideShapeSwap,
    scoreDirection,
    shapeFollowsStopOrder,
} from "./gtfs-shape-side";

/**
 * Geometría sintética: una avenida norte-sur de doble calzada separada ~12 m.
 * La calzada ESTE es de un solo sentido hacia el norte y la OESTE hacia el sur
 * (circulación por la derecha). Los puntos van de sur a norte para que el orden
 * de cada polilínea sea fácil de leer.
 */
const SOUTH = -17.76;
const NORTH = -17.70;
const WEST_LON = -63.18;
const EAST_LON = -63.18 + 12 / (111_320 * Math.cos((17.73 * Math.PI) / 180));

const line = (lon: number, from: number, to: number, steps = 40): LatLon[] =>
    Array.from({ length: steps + 1 }, (_, i) => ({ lat: from + ((to - from) * i) / steps, lon }));

/** Calzada oeste recorrida de norte a sur (su sentido permitido). */
const WEST_NORTH_TO_SOUTH = line(WEST_LON, NORTH, SOUTH);
/** Calzada este recorrida de sur a norte (su sentido permitido). */
const EAST_SOUTH_TO_NORTH = line(EAST_LON, SOUTH, NORTH);

const oneWays = (): OneWaySegment[] => {
    const segments: OneWaySegment[] = [];
    for (let i = 1; i < WEST_NORTH_TO_SOUTH.length; i++) {
        segments.push({ a: WEST_NORTH_TO_SOUTH[i - 1], b: WEST_NORTH_TO_SOUTH[i] });
    }
    for (let i = 1; i < EAST_SOUTH_TO_NORTH.length; i++) {
        segments.push({ a: EAST_SOUTH_TO_NORTH[i - 1], b: EAST_SOUTH_TO_NORTH[i] });
    }
    return segments;
};

/** Paradas sobre el eje de la avenida, en el orden del viaje. */
const stopsAlong = (from: number, to: number): LatLon[] =>
    Array.from({ length: 12 }, (_, i) => ({ lat: from + ((to - from) * i) / 11, lon: WEST_LON + 0.0000565 }));

/** Ida: viaja al sur. Vuelta: viaja al norte. */
const IDA_STOPS = stopsAlong(NORTH, SOUTH);
const VUELTA_STOPS = stopsAlong(SOUTH, NORTH);

describe("scoreDirection", () => {
    const index = buildOneWayIndex(oneWays());

    it("puntúa 100% la calzada recorrida en su sentido permitido", () => {
        expect(scoreDirection(index, WEST_NORTH_TO_SOUTH).percent).toBe(100);
        expect(scoreDirection(index, EAST_SOUTH_TO_NORTH).percent).toBe(100);
    });

    it("puntúa 0% la calzada recorrida al revés", () => {
        expect(scoreDirection(index, [...WEST_NORTH_TO_SOUTH].reverse()).percent).toBe(0);
        expect(scoreDirection(index, [...EAST_SOUTH_TO_NORTH].reverse()).percent).toBe(0);
    });

    it("devuelve null si el trazado no pasa cerca de ninguna calle de un solo sentido", () => {
        const lejos = line(-63.3, SOUTH, NORTH);
        expect(scoreDirection(index, lejos).percent).toBeNull();
    });
});

describe("shapeFollowsStopOrder", () => {
    /** Circuito cerrado de 4 esquinas (empieza y acaba en el mismo punto). */
    const loop: LatLon[] = [
        { lat: -17.70, lon: -63.18 },
        { lat: -17.70, lon: -63.17 },
        { lat: -17.71, lon: -63.17 },
        { lat: -17.71, lon: -63.18 },
        { lat: -17.70, lon: -63.18 },
    ];

    it("reconoce el sentido de un circuito cerrado", () => {
        const forward = [
            { lat: -17.7, lon: -63.18 },
            { lat: -17.7, lon: -63.17 },
            { lat: -17.71, lon: -63.17 },
            { lat: -17.71, lon: -63.18 },
        ];
        expect(shapeFollowsStopOrder(loop, forward)).toBe(true);
        expect(shapeFollowsStopOrder(loop, [...forward].reverse())).toBe(false);
    });

    it("no invierte un shape que ya sigue a sus paradas", () => {
        expect(shapeFollowsStopOrder(WEST_NORTH_TO_SOUTH, IDA_STOPS)).toBe(true);
    });
});

describe("decideShapeSwap", () => {
    const index = buildOneWayIndex(oneWays());

    it("mantiene la asignación cuando cada viaje lleva la calzada de su sentido", () => {
        const decision = decideShapeSwap(
            { shape: WEST_NORTH_TO_SOUTH, stops: IDA_STOPS },
            { shape: EAST_SOUTH_TO_NORTH, stops: VUELTA_STOPS },
            index,
        );
        expect(decision.status).toBe("keep");
        expect(decision.current).toEqual({ ida: 100, vuelta: 100 });
        expect(decision.swapped.ida).toBe(0);
        expect(decision.swapped.vuelta).toBe(0);
    });

    it("intercambia los shapes cuando cada viaje lleva la calzada contraria", () => {
        // Es el caso del feed: la ida (sur) va por la calzada este y la vuelta
        // (norte) por la oeste.
        const decision = decideShapeSwap(
            { shape: EAST_SOUTH_TO_NORTH, stops: IDA_STOPS },
            { shape: WEST_NORTH_TO_SOUTH, stops: VUELTA_STOPS },
            index,
        );
        expect(decision.status).toBe("swapped");
        expect(decision.current).toEqual({ ida: 0, vuelta: 0 });
        expect(decision.swapped).toEqual({ ida: 100, vuelta: 100 });
    });

    it("es idempotente: sobre el feed ya reparado no vuelve a intercambiar", () => {
        const swapped = decideShapeSwap(
            { shape: EAST_SOUTH_TO_NORTH, stops: IDA_STOPS },
            { shape: WEST_NORTH_TO_SOUTH, stops: VUELTA_STOPS },
            index,
        );
        expect(swapped.status).toBe("swapped");

        // Tras aplicar el intercambio, la ida lleva la calzada oeste y la
        // vuelta la este, pero cada shape conserva su orden de puntos.
        const again = decideShapeSwap(
            { shape: WEST_NORTH_TO_SOUTH, stops: IDA_STOPS },
            { shape: EAST_SOUTH_TO_NORTH, stops: VUELTA_STOPS },
            index,
        );
        expect(again.status).toBe("keep");
    });

    it("no concluye cuando el trazado no pasa por calles de un solo sentido", () => {
        const lejos = line(-63.3, SOUTH, NORTH);
        const decision = decideShapeSwap(
            { shape: lejos, stops: IDA_STOPS },
            { shape: lejos, stops: VUELTA_STOPS },
            index,
        );
        expect(decision.status).toBe("inconclusive");
        expect(decision.reason).toBe("no-street-samples");
    });
});
