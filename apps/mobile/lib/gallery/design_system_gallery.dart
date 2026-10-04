import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Standalone app that shows the design system. See `main_gallery.dart`.
class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de diseño',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const DesignSystemGallery(),
    );
  }
}

/// Every token and component of the design system on one scrollable screen,
/// for visual review on a real device.
class DesignSystemGallery extends StatefulWidget {
  const DesignSystemGallery({super.key});

  @override
  State<DesignSystemGallery> createState() => _DesignSystemGalleryState();
}

class _DesignSystemGalleryState extends State<DesignSystemGallery> {
  static const List<String> _interests = [
    'Ahorrar',
    'Invertir',
    'Viajar',
    'Pagar servicios',
  ];

  static const List<String> _segments = [
    'Estoy empezando',
    'Familia',
    'Patrimonio',
  ];

  static const List<AppBottomNavigationItem> _destinations = [
    AppBottomNavigationItem(label: 'Inicio', icon: Icons.home_outlined),
    AppBottomNavigationItem(
      label: 'Cuentas',
      icon: Icons.account_balance_wallet_outlined,
    ),
    AppBottomNavigationItem(label: 'Servicios', icon: Icons.grid_view),
    AppBottomNavigationItem(label: 'Perfil', icon: Icons.person_outline),
  ];

  final Set<String> _selectedInterests = {'Ahorrar'};
  int _destination = 1;
  String _segment = _segments.first;
  bool _biometricUnlock = true;
  bool _termsAccepted = false;
  bool _isBusy = false;
  String _typedAmount = '1250.5';

  void _typeAmount(String typed) => setState(() => _typedAmount = typed);

  void _toggleInterest(String interest, {required bool selected}) {
    setState(() {
      if (selected) {
        _selectedInterests.add(interest);
      } else {
        _selectedInterests.remove(interest);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sistema de diseño')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: context.metrics.screenMargin,
          vertical: context.metrics.moduleGap,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              title: 'Color',
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    _Swatch('brand/500', colors.brandFill),
                    _Swatch('brand/700', colors.link),
                    _Swatch('brand/50', colors.brandTint),
                    _Swatch('ink/900', scheme.onSurface),
                    _Swatch('text/secondary', colors.textSecondary),
                    _Swatch('surface/0', scheme.surface),
                    _Swatch('surface/2', colors.surfaceInset),
                    for (final tone in AppTone.values) ...[
                      _Swatch('${tone.name}/500', colors.foreground(tone)),
                      _Swatch('${tone.name}/tint', colors.tint(tone)),
                    ],
                  ],
                ),
              ],
            ),
            const _Section(
              title: 'Tipografía',
              children: [
                _TypeSample('Display 28/34', AppTypography.display),
                _TypeSample('Title 22/28', AppTypography.title),
                _TypeSample('Subtitle 17/24', AppTypography.subtitle),
                _TypeSample('Body 15/22', AppTypography.body),
                _TypeSample('Body strong 15/22', AppTypography.bodyStrong),
                _TypeSample('Caption 13/18', AppTypography.caption),
                _TypeSample('OVERLINE 11/16', AppTypography.overline),
              ],
            ),
            const _Section(
              title: 'Importes',
              children: [
                AmountText(cents: 482035, size: AmountTextSize.display),
                AmountText(cents: 357035),
                AmountText(cents: 125000, size: AmountTextSize.subtitle),
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
            _Section(
              title: 'Ingreso de importes',
              children: [
                Center(child: AmountEntryText(typed: _typedAmount)),
                NumericKeypad(
                  onDigit: (digit) => _typeAmount(
                    TypedAmount.withDigit(_typedAmount, digit),
                  ),
                  onDecimalPoint: () => _typeAmount(
                    TypedAmount.withDecimalPoint(_typedAmount),
                  ),
                  onDelete: () => _typeAmount(
                    TypedAmount.withoutLast(_typedAmount),
                  ),
                  onClear: () => _typeAmount(''),
                ),
              ],
            ),
            _Section(
              title: 'Botones',
              children: [
                AppButton(label: 'Continuar', onPressed: () {}),
                AppButton(
                  label: 'Ya soy cliente',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Volver al inicio',
                  variant: AppButtonVariant.text,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Confirmar transferencia',
                  isLoading: _isBusy,
                  onPressed: () => setState(() => _isBusy = true),
                ),
                AppButton(
                  label: 'Detener carga',
                  variant: AppButtonVariant.text,
                  onPressed: _isBusy
                      ? () => setState(() => _isBusy = false)
                      : null,
                ),
                const AppButton(label: 'Deshabilitado', onPressed: null),
              ],
            ),
            const _Section(
              title: 'Campos de texto',
              children: [
                AppTextField(
                  label: 'Correo electrónico',
                  hintText: 'nombre@ejemplo.com',
                  helperText: 'Lo usamos para enviarte tus comprobantes',
                  keyboardType: TextInputType.emailAddress,
                ),
                AppTextField(
                  label: 'Cédula',
                  errorText: 'Ingresa una cédula válida de 10 dígitos',
                  keyboardType: TextInputType.number,
                ),
                AppTextField(label: 'Nombres y apellidos', enabled: false),
              ],
            ),
            _Section(
              title: 'Chips',
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  children: [
                    for (final interest in _interests)
                      AppChip(
                        label: interest,
                        selected: _selectedInterests.contains(interest),
                        onSelected: (selected) =>
                            _toggleInterest(interest, selected: selected),
                      ),
                  ],
                ),
                const Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    StatusChip(label: 'Completado', tone: AppTone.success),
                    StatusChip(label: 'En cola', tone: AppTone.warning),
                    StatusChip(label: 'Fallido', tone: AppTone.danger),
                    StatusChip(label: 'Aliado', tone: AppTone.info),
                  ],
                ),
              ],
            ),
            _Section(
              title: 'Formularios',
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Wordmark(name: 'Banca Digital'),
                ),
                const StepIndicator(current: 2, total: 3),
                const InlineAlert(
                  message:
                      'No pudimos validar tus datos. Revisa e intenta de '
                      'nuevo.',
                ),
                Column(
                  spacing: AppSpacing.x2,
                  children: [
                    for (final segment in _segments)
                      RadioCard(
                        label: segment,
                        selected: _segment == segment,
                        onSelected: () => setState(() => _segment = segment),
                      ),
                  ],
                ),
                const Column(
                  spacing: AppSpacing.x2,
                  children: [
                    RequirementItem(label: 'Al menos 8 caracteres', met: true),
                    RequirementItem(label: 'Un símbolo', met: false),
                  ],
                ),
                ToggleRow(
                  label: 'Ingresar con huella o rostro',
                  value: _biometricUnlock,
                  onChanged: (value) =>
                      setState(() => _biometricUnlock = value),
                ),
                CheckboxRow(
                  value: _termsAccepted,
                  semanticLabel: 'Acepto los términos y condiciones',
                  onChanged: (value) => setState(() => _termsAccepted = value),
                  label: const Text('Acepto los términos y condiciones.'),
                ),
              ],
            ),
            const _Section(
              title: 'Estados de conexión',
              children: [
                StatusBanner(kind: StatusBannerKind.offline),
                StatusBanner(kind: StatusBannerKind.slow),
                StatusBanner(kind: StatusBannerKind.restored),
              ],
            ),
            const _Section(
              title: 'Carga',
              children: [
                SkeletonBlock(height: 146),
                SkeletonBlock(height: 22, width: 180),
              ],
            ),
            _Section(
              title: 'Errores y vacíos',
              children: [
                InlineError(
                  message: 'No pudimos cargar tus movimientos',
                  onRetry: () {},
                ),
                EmptyState(
                  icon: Icons.cloud_off,
                  title: 'No pudimos conectarnos',
                  message: 'Lo intentamos 3 veces sin éxito.',
                  primaryActionLabel: 'Reintentar',
                  onPrimaryAction: () {},
                  secondaryActionLabel: 'Ver datos guardados',
                  onSecondaryAction: () {},
                  footnote: 'Intento 3 de 3',
                ),
              ],
            ),
            _Section(
              title: 'Módulo',
              children: [
                ModuleContainer(
                  title: 'Últimos movimientos',
                  actionLabel: 'Ver todos',
                  onAction: () {},
                  footnote: 'Actualizado hace 8 min',
                  child: const SkeletonBlock(height: 72),
                ),
              ],
            ),
            _Section(
              title: 'Cuentas y movimientos',
              children: [
                AccountCard(
                  name: 'Cuenta de ahorros',
                  maskedNumber: '****4821',
                  balanceCents: 357035,
                  onTap: () {},
                ),
                const GroupHeader(label: 'Hoy'),
                MovementRow(
                  icon: Icons.south_east,
                  description: 'Nómina de septiembre',
                  detail: 'Hoy · 09:12',
                  amountCents: 185000,
                  onTap: () {},
                ),
                MovementRow(
                  icon: Icons.storefront_outlined,
                  description: 'Supermercado',
                  detail: 'Hoy · 08:45',
                  amountCents: -6480,
                  onTap: () {},
                ),
                const DetailRow(label: 'Canal', value: 'Tarjeta de débito'),
              ],
            ),
            _Section(
              title: 'Navegación',
              children: [
                AppBottomNavigation(
                  items: _destinations,
                  currentIndex: _destination,
                  onSelected: (index) => setState(() => _destination = index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.metrics.moduleGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          const Divider(height: AppSpacing.x6),
          for (final (index, child) in children.indexed) ...[
            if (index > 0) SizedBox(height: context.metrics.componentGap),
            child,
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.input),
              border: Border.all(color: context.colors.line),
            ),
            child: const SizedBox(width: _size, height: _size),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(name, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TypeSample extends StatelessWidget {
  const _TypeSample(this.label, this.style);

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: style.copyWith(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}
