import 'package:design_system/design_system.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:feature_services/src/presentation/service_icons.dart';
import 'package:feature_services/src/presentation/services_strings.dart';
import 'package:flutter/material.dart';
import 'package:module_kit/module_kit.dart';

/// The Servicios section: what the bank and its partners offer the
/// customer.
///
/// A service is listed only while [destinations] can open it, so a product
/// without a screen in this version, or a partner switched off in the
/// published configuration, leaves no row behind. Whoever shows this screen
/// rebuilds it when what is published changes.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({
    required this.catalog,
    required this.destinations,
    super.key,
  });

  final ServiceCatalog catalog;
  final DestinationResolver destinations;

  @override
  Widget build(BuildContext context) {
    final listed = catalog.listed(
      (destination) => destinations.resolve(destination) != null,
    );
    final margin = context.metrics.screenMargin;

    return Scaffold(
      appBar: const TabRootAppBar(title: ServicesStrings.title),
      body: listed.bank.isEmpty && listed.partners.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(margin),
                child: const EmptyState(
                  icon: Icons.grid_view,
                  title: ServicesStrings.emptyTitle,
                  message: ServicesStrings.emptyMessage,
                ),
              ),
            )
          // A handful of rows: all of them are built, so whatever is below
          // the fold can be reached by a screen reader.
          : SingleChildScrollView(
              padding: EdgeInsets.all(margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ServicesStrings.subtitle,
                    style: AppTypography.body.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  if (listed.bank.isNotEmpty)
                    _Section(
                      title: ServicesStrings.bankSection,
                      entries: listed.bank,
                      destinations: destinations,
                    ),
                  if (listed.partners.isNotEmpty)
                    _Section(
                      title: ServicesStrings.partnersSection,
                      entries: listed.partners,
                      destinations: destinations,
                    ),
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.entries,
    required this.destinations,
  });

  final String title;
  final List<ServiceEntry> entries;
  final DestinationResolver destinations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: context.metrics.moduleGap),
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTypography.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        for (final entry in entries) ...[
          const SizedBox(height: AppSpacing.x3),
          LinkCard(
            icon: iconFor(entry.symbol),
            title: entry.title,
            description: entry.description,
            badge: entry.isPartner ? ServicesStrings.partnerBadge : null,
            // Asked again on the tap: what is published may have changed
            // since the row was drawn.
            onTap: () => destinations.resolve(entry.destination)?.call(context),
          ),
        ],
      ],
    );
  }
}
