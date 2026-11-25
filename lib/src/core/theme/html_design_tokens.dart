/// Tokens de diseño extraídos de `inicio.html` y `sheet.html`.
///
/// Centraliza los colores hardcoded que vinieron de la migración HTML para que
/// un cambio de paleta se haga en un solo archivo. Cada token lleva el nombre
/// del color en inglés (Tailwind-like) para que sea claro sin importar el tema.
///
/// Los widgets de presentación importan este archivo en vez de usar literales
/// `Color(0xFF...)`. Si el HTML cambia un color, solo se actualiza aquí.
library;

import 'package:material_ui/material_ui.dart';

/// Paleta fija del diseño HTML de Urbano.
///
/// No depende del tema claro/oscuro: los widgets deciden cuándo usar cada token
/// y cómo adaptarlo al tema oscuro (con ternarios o `AppColors.legible`).
class HtmlDesignTokens {
  HtmlDesignTokens._();

  // ── Esmeralda (Emerald) ──

  /// `#10B981` — Esmeralda principal, usado en puntos vivos, gradientes y acentos.
  static const emerald500 = Color(0xFF10B981);

  /// `#059669` — Esmeralda oscuro, inicio de gradientes y bordes.
  static const emerald600 = Color(0xFF059669);

  /// `#047857` — Esmeralda más oscuro, texto sobre fondos claros.
  static const emerald700 = Color(0xFF047857);

  /// `#065F46` — Esmeralda muy oscuro, centros de ilustraciones.
  static const emerald800 = Color(0xFF065F46);

  /// `#064E3B` — Esmeralda fondo oscuro, píldoras semitransparentes.
  static const emerald900 = Color(0xFF064E3B);

  /// `#042F2E` — Esmeralda casi negro, fondos muy oscuros.
  static const emerald950 = Color(0xFF042F2E);

  /// `#34D399` — Esmeralda claro, puntos de estado y bordes suaves.
  static const emerald400 = Color(0xFF34D399);

  /// `#6EE7B7` — Esmeralda muy claro, texto sobre fondos oscuros.
  static const emerald300 = Color(0xFF6EE7B7);

  /// `#A7F3D0` — Esmeralda pálido, texto secundario sobre oscuro.
  static const emerald200 = Color(0xFFA7F3D0);

  /// `#D1FAE5` — Esmeralda fondo claro, fondos de íconos.
  static const emerald100 = Color(0xFFD1FAE5);

  /// `#ECFDF5` — Esmeralda fondo muy claro, tarjetas de íconos.
  static const emerald50 = Color(0xFFECFDF5);

  /// `#E6FFFA` — Esmeralda casi blanco, base de radar.
  static const emerald50Light = Color(0xFFE6FFFA);

  /// `#CCFBF1` — Esmeralda pálido, píldoras de "Ver todos".
  static const emerald100mid = Color(0xFFCCFBF1);

  // ── Teal ──

  /// `#14B8A6` — Teal, medio de gradientes esmeralda.
  static const teal500 = Color(0xFF14B8A6);

  /// `#0D9488` — Teal oscuro, conos de denuncias.
  static const teal600 = Color(0xFF0D9488);

  /// `#2DD4BF` — Teal claro, brillo ambiental del hero banner.
  static const teal300 = Color(0xFF2DD4BF);

  /// `#0F766E` — Teal más oscuro, bordes de parada.
  static const teal700 = Color(0xFF0F766E);

  /// `#044E46` — Teal muy oscuro, base de conos.
  static const teal800 = Color(0xFF044E46);

  /// `#042F2E` — Teal casi negro, fin de gradiente hero banner.
  static const teal950 = Color(0xFF042F2E);

  // ── Cyan ──

  /// `#22D3EE` — Cyan, fin de gradientes esmeralda.
  static const cyan400 = Color(0xFF22D3EE);

  /// `#06B6D4` — Cyan oscuro, pins de destino.
  static const cyan500 = Color(0xFF06B6D4);

  /// `#0369A1` — Cyan muy oscuro, base de pins.
  static const cyan700 = Color(0xFF0369A1);

  /// `#0EA5E9` — Sky blue, ondas de denuncias.
  static const sky500 = Color(0xFF0EA5E9);

  // ── Rosa (Rose) ──

  /// `#F43F5E` — Rosa, acento de destino y alertas.
  static const rose500 = Color(0xFFF43F5E);

  /// `#FFEBEE` — Rosa fondo claro, ícono de destino.
  static const rose50 = Color(0xFFFFEBEE);

  /// `#FDA4AF` — Rosa claro, bordes suaves.
  static const rose300 = Color(0xFFFDA4AF);

  /// `#FB7185` — Rosa medio, gradientes.
  static const rose400 = Color(0xFFFB7185);

  /// `#FFF0F0` — Rosa muy pálido, fondos.
  static const rose50Light = Color(0xFFFFF0F0);

  // ── Naranja (Orange) ──

  /// `#FF9500` — Naranja vivo, botones de acción.
  static const orange500 = Color(0xFFFF9500);

  /// `#FF4D29` — Naranja rojizo, fin de gradientes de botón.
  static const orange600 = Color(0xFFFF4D29);

  /// `#FF5722` — Naranja intenso, campanas y franjas.
  static const orangeA700 = Color(0xFFFF5722);

  /// `#F97316` — Naranja medio, pins flotantes y ondas.
  static const orange400 = Color(0xFFF97316);

  /// `#EA580C` — Naranja oscuro, base de campanas.
  static const orange700 = Color(0xFFEA580C);

  // ── Ámbar (Amber) ──

  /// `#F59E0B` — Ámbar, waypoints y mango de campana.
  static const amber500 = Color(0xFFF59E0B);

  /// `#FCD34D` — Ámbar claro, mango superior.
  static const amber300 = Color(0xFFFCD34D);

  /// `#FBBF24` — Ámbar destello, brillos.
  static const amber400 = Color(0xFFFBBF24);

  /// `#FEF08A` — Ámbar muy claro, faros.
  static const amber200 = Color(0xFFFEF08A);

  /// `#FDBA74` — Ámbar pálido, gradientes de ruta.
  static const amber300Light = Color(0xFFFDBA74);

  /// `#FED7AA` — Ámbar muy pálido, fondos.
  static const amber200Light = Color(0xFFFED7AA);

  /// `#FFB703` — Ámbar intenso, franjas de micro.
  static const amberA500 = Color(0xFFFFB703);

  // ── Índigo (Indigo) ──

  /// `#4F46E5` — Índigo, paleta cíclica de destinos.
  static const indigo600 = Color(0xFF4F46E5);

  /// `#EEF2FF` — Índigo muy claro, fondo de la píldora del acceso Micros.
  static const indigo50 = Color(0xFFEEF2FF);

  /// `#8B5CF6` — Púrpura, paleta cíclica.
  static const purple500 = Color(0xFF8B5CF6);

  /// `#D946EF` — Fucsia, paleta cíclica.
  static const fuchsia500 = Color(0xFFD946EF);

  // ── Rojo (Red) ──

  /// `#EF4444` — Rojo, luces traseras y alertas.
  static const red500 = Color(0xFFEF4444);

  /// `#F43F5E` — Rosa rojizo, destellos.
  static const roseA500 = Color(0xFFF43F5E);

  /// `#DB4437` — Rojo Google, errores.
  static const redGoogle = Color(0xFFDB4437);

  /// `#E53935` — Rojo material, errores.
  static const redMaterial = Color(0xFFE53935);

  /// `#C62828` — Rojo oscuro, errores graves.
  static const redDark = Color(0xFFC62828);

  /// `#E11D48` — Rosa rojo, acentos.
  static const roseRed = Color(0xFFE11D48);

  // ── Verde (Green) ──

  /// `#4ADE80` — Verde brillante, display de micro.
  static const green400 = Color(0xFF4ADE80);

  /// `#2E7D32` — Verde oscuro, estado activo.
  static const greenDark = Color(0xFF2E7D32);

  /// `#C8E6C9` — Verde pálido, fondos.
  static const green100 = Color(0xFFC8E6C9);

  /// `#E8F5E9` — Verde muy pálido, fondos claros.
  static const green50 = Color(0xFFE8F5E9);

  // ── Azul (Blue) ──

  /// `#0284C7` — Azul, fin de gradientes de ruta.
  static const blue600 = Color(0xFF0284C7);

  /// `#3B82F6` — Azul vivo, paleta cíclica.
  static const blue500 = Color(0xFF3B82F6);

  /// `#0C4A6E` — Azul muy oscuro, fondos.
  static const blue900 = Color(0xFF0C4A6E);

  /// `#E0F2FE` — Azul muy claro, ventanas de micro.
  static const blue50 = Color(0xFFE0F2FE);

  /// `#BAE6FD` — Azul claro, ventanas mini micro.
  static const blue100 = Color(0xFFBAE6FD);

  /// `#7DD3FC` — Azul medio claro, ventanas de micro.
  static const blue200 = Color(0xFF7DD3FC);

  /// `#B2EBF2` — Cyan claro, fondos.
  static const cyan100 = Color(0xFFB2EBF2);

  /// `#E0F7FA` — Cyan muy claro, fondos.
  static const cyan50 = Color(0xFFE0F7FA);

  // ── Slate (Grises) ──

  /// `#0F172A` — Slate casi negro, texto principal oscuro.
  static const slate900 = Color(0xFF0F172A);

  /// `#1E293B` — Slate oscuro, ruedas de micro.
  static const slate800 = Color(0xFF1E293B);

  /// `#334155` — Slate medio oscuro, texto secundario.
  static const slate700 = Color(0xFF334155);

  /// `#475569` — Slate medio, íconos secundarios.
  static const slate600 = Color(0xFF475569);

  /// `#64748B` — Slate claro, texto terciario.
  static const slate500 = Color(0xFF64748B);

  /// `#94A3B8` — Slate pálido, texto deshabilitado.
  static const slate400 = Color(0xFF94A3B8);

  /// `#CBD5E1` — Slate muy pálido, bordes.
  static const slate300 = Color(0xFFCBD5E1);

  /// `#E2E8F0` — Slate borde, separadores.
  static const slate200 = Color(0xFFE2E8F0);

  /// `#F1F5F9` — Slate fondo, píldoras grises.
  static const slate100 = Color(0xFFF1F5F9);

  /// `#F8FAFC` — Slate casi blanco, contenedores.
  static const slate50 = Color(0xFFF8FAFC);

  /// `#F8FFFE` — Blanco azulado, fondos muy claros.
  static const whiteBlue = Color(0xFFF8FFFE);

  // ── Blanco ──

  /// `#FFFFFF` — Blanco puro, fondos y texto sobre oscuro.
  static const white = Color(0xFFFFFFFF);

  // ── Negro ──

  /// `#18181B` — Negro suave, display de micro.
  static const blackSoft = Color(0xFF18181B);

  // ── Fondos oscuros del HTML ──

  /// `#065343` — Fondo oscuro inicio de degradado.
  static const darkBgStart = Color(0xFF065343);

  /// `#054336` — Fondo oscuro medio de degradado.
  static const darkBgMid = Color(0xFF054336);

  /// `#012A21` — Fondo oscuro fin de degradado.
  static const darkBgEnd = Color(0xFF012A21);

  /// `#084236` — Verde oscuro, wordmark del header.
  static const darkWordmark = Color(0xFF084236);

  // ── Colores de micro (HTML) ──

  /// `#00C49F` — Verde turquesa, cuerpo del micro.
  static const microBodyStart = Color(0xFF00C49F);

  /// `#069670` — Verde medio, cuerpo del micro.
  static const microBodyMid = Color(0xFF069670);

  /// `#025C44` — Verde oscuro, cuerpo del micro.
  static const microBodyEnd = Color(0xFF025C44);

  /// `#0000897B` — Verde muy oscuro, detalles del micro.
  static const microDark = Color(0xFF00897B);

  /// `#0000695C` — Verde casi negro, detalles profundos.
  static const microDarker = Color(0xFF00695C);

  // ── Púrpura (Purple) ──

  /// `#EC4899` — Rosa vivo, paleta cíclica.
  static const pink500 = Color(0xFFEC4899);

  // ── Amarillo (Yellow) ──

  /// `#FFF8E1` — Amarillo muy pálido, fondos.
  static const yellow50 = Color(0xFFFFF8E1);

  /// `#FFF3E0` — Naranja muy pálido, fondos.
  static const orange50 = Color(0xFFFFF3E0);

  /// `#FFE0B2` — Naranja pálido, fondos.
  static const orange100 = Color(0xFFFFE0B2);

  /// `#FFCDD2` — Rojo pálido, fondos.
  static const red50 = Color(0xFFFFCDD2);
}
