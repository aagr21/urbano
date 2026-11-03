import 'package:flutter/material.dart';

import '../../../../core/identity/passenger_identity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';

/// Avatar circular de un pasajero: color de su identidad (hex sin `#`) con las
/// iniciales legibles encima. Es la única forma en que la app pinta un color
/// arbitrario de avatar, así que el texto usa [AppColors.onColor] sobre el
/// relleno real (nunca blanco/negro fijos).
class PassengerAvatar extends StatelessWidget {
  const PassengerAvatar({
    super.key,
    required this.colorHex,
    required this.initials,
    this.size = 40,
  });

  PassengerAvatar.from(PassengerIdentity identity, {super.key, this.size = 40})
    : colorHex = identity.avatarColorHex,
      initials = identity.initials;

  final String colorHex;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.fromHex(colorHex);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.surface, width: size * 0.06),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.onColor(fill),
          fontWeight: FontWeight.w900,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
