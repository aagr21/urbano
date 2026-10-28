import 'package:flutter/material.dart';

/// Hito o lugar de interés común en Santa Cruz de la Sierra.
class SantaCruzPoi {
  const SantaCruzPoi({
    required this.name,
    required this.category,
    required this.lat,
    required this.lon,
    required this.icon,
    this.ringOrZone,
  });

  final String name;
  final String category;
  final double lat;
  final double lon;
  final IconData icon;
  final String? ringOrZone;
}

/// Catálogo representativo de lugares populares y de alta afluencia en
/// Santa Cruz de la Sierra (mercados, universidades, centros comerciales,
/// plazas y terminales).
const List<SantaCruzPoi> kSantaCruzPopularPlaces = [
  SantaCruzPoi(
    name: 'Plaza 24 de Septiembre',
    category: 'Centro histórico',
    ringOrZone: 'Casco Viejo',
    lat: -17.7833,
    lon: -63.1821,
    icon: Icons.account_balance_rounded,
  ),
  SantaCruzPoi(
    name: 'El Cristo Redentor',
    category: 'Monumento / Concurrencia',
    ringOrZone: '2do Anillo · Av. Monseñor Rivero',
    lat: -17.7698,
    lon: -63.1829,
    icon: Icons.place_rounded,
  ),
  SantaCruzPoi(
    name: 'Ventura Mall',
    category: 'Centro comercial',
    ringOrZone: '4to Anillo · Equipetrol Norte',
    lat: -17.7548,
    lon: -63.1974,
    icon: Icons.shopping_bag_rounded,
  ),
  SantaCruzPoi(
    name: 'Las Brisas Centro Comercial',
    category: 'Centro comercial',
    ringOrZone: '4to Anillo · Av. Banzer',
    lat: -17.7534,
    lon: -63.1751,
    icon: Icons.shopping_cart_rounded,
  ),
  SantaCruzPoi(
    name: 'UAGRM · Campus Módulos',
    category: 'Universidad',
    ringOrZone: '2do Anillo · Av. Busch',
    lat: -17.7761,
    lon: -63.1947,
    icon: Icons.school_rounded,
  ),
  SantaCruzPoi(
    name: 'Terminal Bimodal',
    category: 'Transporte interprovincial/nacional',
    ringOrZone: '3er Anillo Interno · Av. Montes',
    lat: -17.7898,
    lon: -63.1631,
    icon: Icons.directions_bus_rounded,
  ),
  SantaCruzPoi(
    name: 'Mercado Abasto Antiguo',
    category: 'Mercado popular',
    ringOrZone: '3er Anillo Interno · Av. Piraí',
    lat: -17.7986,
    lon: -63.2030,
    icon: Icons.storefront_rounded,
  ),
  SantaCruzPoi(
    name: 'Mercado Los Pozos',
    category: 'Mercado popular',
    ringOrZone: '1er Anillo · Casco Viejo',
    lat: -17.7788,
    lon: -63.1754,
    icon: Icons.storefront_rounded,
  ),
  SantaCruzPoi(
    name: 'Mercado La Ramada',
    category: 'Mercado popular',
    ringOrZone: '1er Anillo · Av. Grigotá',
    lat: -17.7946,
    lon: -63.1866,
    icon: Icons.storefront_rounded,
  ),
  SantaCruzPoi(
    name: 'Mercado Mutualista',
    category: 'Mercado popular',
    ringOrZone: '3er Anillo Interno · Av. Mutualista',
    lat: -17.7656,
    lon: -63.1594,
    icon: Icons.storefront_rounded,
  ),
  SantaCruzPoi(
    name: 'Cine Center Santa Cruz',
    category: 'Entretenimiento',
    ringOrZone: '2do Anillo · El Trompillo',
    lat: -17.8016,
    lon: -63.1802,
    icon: Icons.movie_rounded,
  ),
  SantaCruzPoi(
    name: 'Hospital Japonés',
    category: 'Salud',
    ringOrZone: '3er Anillo Interno · Av. Japón',
    lat: -17.7735,
    lon: -63.1553,
    icon: Icons.local_hospital_rounded,
  ),
  SantaCruzPoi(
    name: 'Hospital San Juan de Dios',
    category: 'Salud',
    ringOrZone: 'Centro · Calle España',
    lat: -17.7865,
    lon: -63.1852,
    icon: Icons.local_hospital_rounded,
  ),
  SantaCruzPoi(
    name: 'Parque Urbano Central',
    category: 'Área verde / Recreación',
    ringOrZone: '2do Anillo · Av. Argandoña',
    lat: -17.7885,
    lon: -63.1718,
    icon: Icons.park_rounded,
  ),
  SantaCruzPoi(
    name: 'Parque El Arenal',
    category: 'Paseo tradicional',
    ringOrZone: 'Centro · Calle Beni',
    lat: -17.7780,
    lon: -63.1805,
    icon: Icons.park_rounded,
  ),
  SantaCruzPoi(
    name: 'Aeropuerto El Trompillo',
    category: 'Transporte aéreo',
    ringOrZone: 'Av. Santos Dumont',
    lat: -17.8080,
    lon: -63.1780,
    icon: Icons.flight_takeoff_rounded,
  ),
  SantaCruzPoi(
    name: 'Cambódromo',
    category: 'Eventos y desfiles',
    ringOrZone: '4to al 8vo Anillo · Mutualista',
    lat: -17.7470,
    lon: -63.1490,
    icon: Icons.festival_rounded,
  ),
];
