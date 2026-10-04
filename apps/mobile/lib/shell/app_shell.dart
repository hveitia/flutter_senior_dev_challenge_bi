import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One section of the app, reachable from the bottom navigation.
@immutable
class AppSection {
  const AppSection({
    required this.path,
    required this.label,
    required this.icon,
  });

  /// The location of the section's root screen.
  final String path;
  final String label;
  final IconData icon;
}

/// Frames the root screen of each section with the bottom navigation.
///
/// Sections do not keep a navigation stack of their own: a screen opened
/// from a section covers the whole app and returns to it.
class AppShell extends StatelessWidget {
  const AppShell({
    required this.sections,
    required this.location,
    required this.onSectionSelected,
    required this.child,
    super.key,
  });

  final List<AppSection> sections;

  /// Where the router is, to mark the current section.
  final String location;
  final ValueChanged<AppSection> onSectionSelected;
  final Widget child;

  /// The section [location] belongs to. An unknown location marks the
  /// first one rather than none.
  int get _currentIndex {
    final index = sections.indexWhere(
      (section) => location.startsWith(section.path),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onSelected: (index) => onSectionSelected(sections[index]),
        items: [
          for (final section in sections)
            AppBottomNavigationItem(label: section.label, icon: section.icon),
        ],
      ),
    );
  }
}
