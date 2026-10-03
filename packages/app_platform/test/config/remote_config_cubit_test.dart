import 'dart:async';
import 'dart:convert';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _document({required int configVersion}) => {
  'schemaVersion': 1,
  'configVersion': configVersion,
  'segments': {
    'starting': {'label': 'Estoy empezando', 'modules': <Object?>[]},
    'wealth': {'label': 'Patrimonio', 'modules': <Object?>[]},
  },
};

const int _bundledVersion = 1;
const int _remoteVersion = 14;

void main() {
  late StreamController<Object?> remote;

  RemoteConfigCubit cubit({String? segmentId}) {
    return RemoteConfigCubit(
      ConfigRepository(
        source: StreamConfigSource(remote.stream),
        store: InMemoryConfigStore(),
        loadBundled: () async =>
            jsonEncode(_document(configVersion: _bundledVersion)),
      ),
      segmentId: segmentId,
    );
  }

  setUp(() => remote = StreamController<Object?>());

  test('has no configuration before it starts', () async {
    final config = cubit();

    expect(config.state.isReady, isFalse);
    expect(config.state.config, isNull);
    expect(config.state.version, isNull);
    expect(config.state.origin, isNull);
    expect(config.state.segment, isNull);
    await config.close();
  });

  test(
    'exposes the configuration, its version and where it came from',
    () async {
      final config = cubit()..start();
      await pumpEventQueue();

      expect(config.state.isReady, isTrue);
      expect(config.state.version, _bundledVersion);
      expect(config.state.origin, ConfigOrigin.bundled);
      await config.close();
    },
  );

  test('follows the remote configuration as it is published', () async {
    final config = cubit()..start();
    await pumpEventQueue();

    remote.add(_document(configVersion: _remoteVersion));
    await pumpEventQueue();

    expect(config.state.version, _remoteVersion);
    expect(config.state.origin, ConfigOrigin.remote);
    await config.close();
  });

  test('resolves the segment it was created with', () async {
    final config = cubit(segmentId: 'wealth')..start();
    await pumpEventQueue();

    expect(config.state.segment!.label, 'Patrimonio');
    await config.close();
  });

  test('falls back to the default segment for an unknown one', () async {
    final config = cubit(segmentId: 'platinum')..start();
    await pumpEventQueue();

    expect(config.state.segment!.id, HomeConfig.defaultSegmentId);
    await config.close();
  });

  test('switches segment without waiting for a new document', () async {
    final config = cubit()..start();
    await pumpEventQueue();

    config.selectSegment('wealth');

    expect(config.state.segment!.id, 'wealth');
    expect(config.state.version, _bundledVersion);
    await config.close();
  });

  test('keeps the selected segment when a new document arrives', () async {
    final config = cubit()..start();
    await pumpEventQueue();
    config.selectSegment('wealth');

    remote.add(_document(configVersion: _remoteVersion));
    await pumpEventQueue();

    expect(config.state.segment!.id, 'wealth');
    expect(config.state.version, _remoteVersion);
    await config.close();
  });

  test('starting twice does not subscribe twice', () async {
    final config = cubit()
      ..start()
      ..start();
    await pumpEventQueue();

    expect(config.state.isReady, isTrue);
    await config.close();
  });

  test('stops listening to the remote source when closed', () async {
    final config = cubit()..start();
    await pumpEventQueue();
    expect(remote.hasListener, isTrue);

    await config.close();

    expect(remote.hasListener, isFalse);
  });
}
