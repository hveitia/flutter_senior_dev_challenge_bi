import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/module_kit.dart';
import 'package:module_kit/testing.dart';

void main() {
  late RecordingModuleHost host;
  late HomeModuleContext module;

  setUp(() {
    host = RecordingModuleHost();
    module = moduleContext(id: 'movements', host: host);
  });

  Widget binding(
    HomeModuleStatus status, {
    Future<void> Function()? onRefresh,
  }) {
    return HomeModuleBinding(
      module: module,
      status: status,
      onRefresh: onRefresh,
      child: const SizedBox.shrink(),
    );
  }

  testWidgets('reports the status of its module to the home', (tester) async {
    await tester.pumpWidget(binding(HomeModuleStatus.waiting));

    expect(host.statuses, {'movements': HomeModuleStatus.waiting});
  });

  testWidgets('reports again only when the status changes', (tester) async {
    await tester.pumpWidget(binding(HomeModuleStatus.waiting));
    await tester.pumpWidget(binding(HomeModuleStatus.waiting));
    await tester.pumpWidget(binding(HomeModuleStatus.failed));

    expect(host.reports, [
      ('movements', HomeModuleStatus.waiting),
      ('movements', HomeModuleStatus.failed),
    ]);
  });

  testWidgets('offers its refresh to the home while it is on screen', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      binding(HomeModuleStatus.ready, onRefresh: () async => refreshes++),
    );

    await host.refreshAll();

    expect(refreshes, 1);
  });

  testWidgets('runs the refresh it was last given', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      binding(HomeModuleStatus.ready, onRefresh: () async => calls.add('old')),
    );
    await tester.pumpWidget(
      binding(HomeModuleStatus.ready, onRefresh: () async => calls.add('new')),
    );

    await host.refreshAll();

    expect(calls, ['new']);
  });

  testWidgets('withdraws its report when it leaves the screen', (tester) async {
    await tester.pumpWidget(binding(HomeModuleStatus.failed));
    await tester.pumpWidget(const SizedBox.shrink());

    expect(host.statuses, isEmpty);
    expect(host.withdrawn, ['movements']);
  });

  testWidgets('can say it has nothing to draw', (tester) async {
    await tester.pumpWidget(binding(HomeModuleStatus.hidden));

    expect(host.statuses, {'movements': HomeModuleStatus.hidden});
  });

  testWidgets('takes its refresh back when it leaves the screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      binding(HomeModuleStatus.ready, onRefresh: () async {}),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    expect(host.refreshers, isEmpty);
  });

  testWidgets('a module without data to refresh registers nothing', (
    tester,
  ) async {
    await tester.pumpWidget(binding(HomeModuleStatus.ready));

    expect(host.refreshers, isEmpty);
  });
}
