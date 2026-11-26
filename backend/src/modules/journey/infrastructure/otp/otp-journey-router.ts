import { Injectable, Logger } from '@nestjs/common';
import { AppConfigService } from '../../../../core/config/app-config.service';
import { JourneyOption } from '../../domain/journey.model';
import {
  JourneyRouterPort,
  JourneyRouterQuery,
} from '../../domain/journey-router.port';
import {
  OtpItinerary,
  laPazIsoFromTimeSec,
  mapItinerary,
} from './otp-itinerary.mapper';

/**
 * Re-export: el mapeo puro vive en `otp-itinerary.mapper`; se sigue
 * ofreciendo desde aquí para quien lo importaba.
 */
export * from './otp-itinerary.mapper';

interface OtpGraphQlResponse {
  data?: {
    planConnection?: {
      edges?: { node?: OtpItinerary | null }[] | null;
    } | null;
  } | null;
  errors?: { message?: string }[] | null;
}

const PLAN_QUERY = `
query Plan($from: PlanLabeledLocationInput!, $to: PlanLabeledLocationInput!, $dateTime: PlanDateTimeInput, $first: Int!) {
  planConnection(
    origin: $from
    destination: $to
    dateTime: $dateTime
    first: $first
    modes: { direct: [WALK], transit: { transit: [{ mode: BUS }] } }
  ) {
    edges {
      node {
        start
        end
        legs {
          mode
          startTime
          endTime
          distance
          intermediateStops { gtfsId }
          legGeometry { points }
          from { name lat lon stop { gtfsId } }
          to { name lat lon stop { gtfsId } }
          route { gtfsId shortName longName color }
          trip { gtfsId }
        }
      }
    }
  }
}`;

/**
 * Adaptador del motor OpenTripPlanner 2 (GTFS + OSM): resuelve itinerarios
 * puerta a puerta con las caminatas trazadas por la red viaria y los mapea
 * al modelo de dominio. Cualquier fallo (red, timeout, respuesta inválida)
 * devuelve `null` para que el servicio degrade al planner interno.
 */
@Injectable()
export class OtpJourneyRouter implements JourneyRouterPort {
  private readonly logger = new Logger(OtpJourneyRouter.name);

  constructor(private readonly config: AppConfigService) {}

  async plan(query: JourneyRouterQuery): Promise<JourneyOption[] | null> {
    const base = this.config.otpUrl;
    if (!base) return null;

    const body = {
      query: PLAN_QUERY,
      variables: {
        from: {
          location: {
            coordinate: {
              latitude: query.originLat,
              longitude: query.originLon,
            },
          },
        },
        to: {
          location: {
            coordinate: { latitude: query.destLat, longitude: query.destLon },
          },
        },
        dateTime: { earliestDeparture: laPazIsoFromTimeSec(query.timeSec) },
        first: query.maxResults,
      },
    };

    let json: OtpGraphQlResponse;
    try {
      const controller = new AbortController();
      const timer = setTimeout(
        () => controller.abort(),
        this.config.otpTimeoutMs
      );
      try {
        const res = await fetch(`${base.replace(/\/$/, '')}/index/graphql`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
          signal: controller.signal,
        });
        if (!res.ok) {
          this.logger.warn(
            `OTP respondió HTTP ${res.status}; uso el planner interno`
          );
          return null;
        }
        json = (await res.json()) as OtpGraphQlResponse;
      } finally {
        clearTimeout(timer);
      }
    } catch (err) {
      this.logger.warn(
        `OTP no disponible (${(err as Error).message}); uso el planner interno`
      );
      return null;
    }

    if (json.errors?.length) {
      this.logger.warn(
        `OTP devolvió errores GraphQL: ${json.errors.map((e) => e.message).join('; ')}`
      );
      return null;
    }

    const nodes = json.data?.planConnection?.edges ?? [];
    const options = nodes
      .map((edge) => edge?.node)
      .filter((node): node is OtpItinerary => !!node)
      .map((node) => mapItinerary(node))
      .filter((option): option is JourneyOption => option !== null);

    // SOLO mapea: el ORDEN y el recorte a maxResults son política de domain
    // (rankAndCut en journey-planner) y los aplica el servicio sobre el
    // resultado de CUALQUIER motor. El adapter no rankea.
    return options;
  }
}
