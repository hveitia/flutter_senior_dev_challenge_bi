import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Every component in every state that changes its layout or colors.
///
/// The accessibility suite runs each entry through the same checks, so a new
/// component or state is covered by adding one line here.
Map<String, Widget> componentCatalog() {
  void noop() {}

  return {
    'AppButton primary': AppButton(label: 'Continuar', onPressed: noop),
    'AppButton secondary': AppButton(
      label: 'Ya soy cliente',
      variant: AppButtonVariant.secondary,
      onPressed: noop,
    ),
    'AppButton text': AppButton(
      label: 'Olvidé mi contraseña',
      variant: AppButtonVariant.text,
      onPressed: noop,
    ),
    'AppButton with icon': AppButton(
      label: 'Compartir comprobante',
      icon: Icons.ios_share,
      onPressed: noop,
    ),
    'AppButton loading': AppButton(
      label: 'Confirmar transferencia',
      isLoading: true,
      onPressed: noop,
    ),
    'AppButton disabled': const AppButton(label: 'Continuar', onPressed: null),
    'AppTextField': const AppTextField(
      label: 'Correo electrónico',
      hintText: 'nombre@ejemplo.com',
      helperText: 'Lo usamos para enviarte tus comprobantes',
    ),
    'AppTextField error': const AppTextField(
      label: 'Cédula',
      errorText: 'Ingresa una cédula válida de 10 dígitos',
    ),
    'AppTextField disabled': const AppTextField(
      label: 'Nombres y apellidos',
      enabled: false,
    ),
    'AppChip': Wrap(
      spacing: AppSpacing.x2,
      children: [
        AppChip(label: 'Ahorrar', selected: true, onSelected: (_) {}),
        AppChip(label: 'Pagar servicios', selected: false, onSelected: (_) {}),
        const AppChip(label: 'Mi negocio', selected: false, onSelected: null),
      ],
    ),
    'StatusChip': const Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: [
        StatusChip(label: 'Completado', tone: AppTone.success),
        StatusChip(label: 'En cola', tone: AppTone.warning),
        StatusChip(label: 'Fallido', tone: AppTone.danger),
        StatusChip(label: 'Aliado', tone: AppTone.info),
      ],
    ),
    'StatusBanner offline': const StatusBanner(kind: StatusBannerKind.offline),
    'StatusBanner slow': const StatusBanner(kind: StatusBannerKind.slow),
    'StatusBanner restored': const StatusBanner(
      kind: StatusBannerKind.restored,
    ),
    'SkeletonBlock': const SkeletonBlock(height: 146),
    'InlineError': InlineError(
      message: 'No pudimos cargar tus movimientos',
      onRetry: noop,
    ),
    'InlineError retrying': InlineError(
      message: 'No pudimos cargar tus movimientos',
      isRetrying: true,
      onRetry: noop,
    ),
    'EmptyState': EmptyState(
      icon: Icons.cloud_off,
      title: 'No pudimos conectarnos',
      message: 'Lo intentamos 3 veces sin éxito.',
      primaryActionLabel: 'Reintentar',
      onPrimaryAction: noop,
      secondaryActionLabel: 'Ver datos guardados',
      onSecondaryAction: noop,
      footnote: 'Intento 3 de 3',
    ),
    'AmountText': const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AmountText(cents: 2942035, size: AmountTextSize.display),
        AmountText(cents: 357035),
        AmountText(
          cents: 185000,
          size: AmountTextSize.body,
          signDisplay: AmountSignDisplay.always,
        ),
        AmountText(
          cents: -6480,
          size: AmountTextSize.body,
          signDisplay: AmountSignDisplay.always,
        ),
      ],
    ),
    'ModuleContainer': ModuleContainer(
      title: 'Últimos movimientos',
      actionLabel: 'Ver todos',
      onAction: noop,
      footnote: 'Actualizado hace 8 min',
      child: const SkeletonBlock(height: 72),
    ),
    'StepIndicator': const StepIndicator(current: 2, total: 3),
    'RadioCard': Column(
      spacing: AppSpacing.x2,
      children: [
        RadioCard(label: 'Estoy empezando', selected: true, onSelected: noop),
        RadioCard(label: 'Familia', selected: false, onSelected: noop),
        const RadioCard(label: 'Patrimonio', selected: false, onSelected: null),
      ],
    ),
  };
}
