import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/identity/passenger_identity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../application/passenger_controller.dart';
import 'passenger_avatar.dart';

/// Hoja para ver y editar el apodo con el que el dispositivo participa en el
/// feed. El color de avatar es fijo (deriva de la clave de dispositivo) para
/// que la identidad sea estable; sólo cambia el nombre visible.
Future<void> showPassengerNameSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PassengerNameSheet(),
  );
}

class _PassengerNameSheet extends ConsumerStatefulWidget {
  const _PassengerNameSheet();

  @override
  ConsumerState<_PassengerNameSheet> createState() =>
      _PassengerNameSheetState();
}

class _PassengerNameSheetState extends ConsumerState<_PassengerNameSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(passengerControllerProvider).valueOrNull;
    _controller = TextEditingController(text: current?.nickname ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(passengerControllerProvider.notifier)
          .rename(_controller.text);
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError {
      if (mounted) {
        context.showSnack('El apodo no puede quedar vacío.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final identity = ref.watch(passengerControllerProvider).valueOrNull;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.lg,
        right: AppSpace.lg,
        top: AppSpace.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (identity != null)
                PassengerAvatar.from(identity, size: 44)
              else
                const SizedBox(width: 44, height: 44),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  'Tu identidad en el feed',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _controller,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Apodo',
              hintText: identity == null
                  ? 'Generando apodo…'
                  : PassengerNames.nicknameFor(identity.deviceKey),
              helperText: 'Así te verán los demás al comentar.',
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Guardando…' : 'Guardar apodo'),
          ),
        ],
      ),
    );
  }
}
