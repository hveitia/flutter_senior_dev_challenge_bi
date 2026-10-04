import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_notifications/adapters.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('decodeInboxItem', () {
    final createdAt = Timestamp.fromDate(DateTime(2026, 10, 3, 9, 12));

    test('reads a notification as the server writes it', () {
      final item = decodeInboxItem('n-1', {
        'title': 'Nuevo inicio de sesión',
        'body': 'Ingresaste desde tu dispositivo habitual.',
        'kind': 'security',
        'destination': 'profile',
        'createdAt': createdAt,
        'read': false,
      });

      expect(
        item,
        InboxItem(
          id: 'n-1',
          title: 'Nuevo inicio de sesión',
          body: 'Ingresaste desde tu dispositivo habitual.',
          kind: NotificationKind.security,
          destination: 'profile',
          createdAt: DateTime(2026, 10, 3, 9, 12),
          isRead: false,
        ),
      );
    });

    test('a kind it does not know is shown as a benefit, and a missing '
        'destination leads nowhere', () {
      final item = decodeInboxItem('n-1', {
        'title': 'Aviso',
        'body': '',
        'kind': 'survey',
        'createdAt': createdAt,
        'read': true,
      });

      expect(item?.kind, NotificationKind.benefit);
      expect(item?.destination, '');
      expect(item?.isRead, isTrue);
    });

    test('anything other than true counts as unread', () {
      final item = decodeInboxItem('n-1', {
        'title': 'Aviso',
        'body': '',
        'createdAt': createdAt,
        'read': 'true',
      });

      expect(item?.isRead, isFalse);
    });

    test('leaves out a document without a title or a date', () {
      expect(
        decodeInboxItem('n-1', {'body': '', 'createdAt': createdAt}),
        isNull,
      );
      expect(decodeInboxItem('n-1', {'title': 'Aviso', 'body': ''}), isNull);
      expect(
        decodeInboxItem('n-1', {
          'title': 'Aviso',
          'body': '',
          'createdAt': '2026-10-03',
        }),
        isNull,
      );
    });
  });

  group('pushMessageOf', () {
    test('reads the destination and the kind the console sends', () {
      expect(
        pushMessageOf(
          title: 'Recibiste un pago',
          data: {'destination': 'accounts', 'kind': 'movement'},
        ),
        const PushMessage(
          title: 'Recibiste un pago',
          destination: 'accounts',
          kind: NotificationKind.movement,
        ),
      );
    });

    test('a push without data leads nowhere', () {
      expect(
        pushMessageOf(title: null, data: {}),
        const PushMessage(title: '', destination: ''),
      );
    });
  });

  group('permissionOf', () {
    test('authorized and provisional are granted', () {
      for (final status in [
        AuthorizationStatus.authorized,
        AuthorizationStatus.provisional,
      ]) {
        expect(
          permissionOf(status, wasAsked: false),
          NotificationPermission.granted,
        );
      }
    });

    test('a refusal counts only once the system has actually asked', () {
      expect(
        permissionOf(AuthorizationStatus.denied, wasAsked: false),
        NotificationPermission.notAsked,
      );
      expect(
        permissionOf(AuthorizationStatus.denied, wasAsked: true),
        NotificationPermission.denied,
      );
    });
  });

  group('device identity and primer memory', () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    test(
      'the installation keeps the identifier it made up the first time',
      () async {
        final first = await SharedPreferencesDeviceIdentity(
          preferences,
          random: Random(1),
        ).id();
        final second = await SharedPreferencesDeviceIdentity(
          preferences,
          random: Random(2),
        ).id();

        expect(first, hasLength(20));
        expect(first, matches(RegExp(r'^[0-9a-z]+$')));
        expect(second, first);
      },
    );

    test('remembers that the invitation was answered', () async {
      final memory = SharedPreferencesPrimerMemory(preferences);
      expect(memory.wasAnswered, isFalse);

      await memory.rememberAnswered();

      expect(SharedPreferencesPrimerMemory(preferences).wasAnswered, isTrue);
    });
  });
}
