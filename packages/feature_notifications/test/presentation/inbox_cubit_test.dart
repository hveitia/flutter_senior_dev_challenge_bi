import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  late FakeNotificationsRepository repository;
  late InboxCubit cubit;

  setUp(() {
    repository = FakeNotificationsRepository();
    cubit = InboxCubit(repository);
  });

  tearDown(() => cubit.close());

  test('waits with nothing to show until the backend answers', () async {
    repository.onRefresh = () => Completer<Result<InboxSnapshot>>().future;

    cubit.start();
    await pumpEventQueue();

    expect(cubit.state.isWaiting, isTrue);
    expect(cubit.state.isLoading, isTrue);
  });

  test('shows what the backend has and counts what is unread', () async {
    repository.onRefresh = () async => Success(fresh([salary, signIn, travel]));

    cubit.start();
    await pumpEventQueue();

    expect(cubit.state.items, [salary, signIn, travel]);
    expect(cubit.state.unreadCount, 2);
    expect(cubit.state.failure, isNull);
    expect(cubit.state.isLoading, isFalse);
  });

  test('keeps the saved notifications when the refresh fails', () async {
    repository.onRefresh = () async => const Failed(TimeoutFailure());

    cubit.start();
    repository.inbox.add(saved([salary]));
    await pumpEventQueue();

    expect(cubit.state.items, [salary]);
    expect(cubit.state.fromCache, isTrue);
    expect(cubit.state.failure, InboxFailure.timeout);
    expect(cubit.state.needsOutdatedNotice, isTrue);
  });

  test('offline with saved notifications needs no notice of its own', () async {
    repository.onRefresh = () async => const Failed(OfflineFailure());

    cubit.start();
    repository.inbox.add(saved([salary]));
    await pumpEventQueue();

    expect(cubit.state.failure, InboxFailure.offline);
    expect(cubit.state.needsOutdatedNotice, isFalse);
  });

  test('an empty saved copy on a device that never synchronized is not '
      'taken for an empty inbox', () async {
    repository.onRefresh = () async => const Failed(OfflineFailure());

    cubit.start();
    repository.inbox.add(saved([]));
    await pumpEventQueue();

    expect(cubit.state.items, isNull);
    expect(cubit.state.hasFailed, isTrue);
  });

  test('a fresh delivery clears an earlier failure', () async {
    repository.onRefresh = () async => const Failed(TimeoutFailure());
    cubit.start();
    await pumpEventQueue();

    repository.inbox.add(fresh([salary]));
    await pumpEventQueue();

    expect(cubit.state.failure, isNull);
    expect(cubit.state.items, [salary]);
  });

  test('after a broken listener, retrying listens again so new '
      'notifications keep arriving', () async {
    cubit.start();
    await pumpEventQueue();
    repository.inbox.addError(const ServiceUnavailableFailure());
    await pumpEventQueue();
    expect(cubit.state.failure, InboxFailure.unavailable);

    repository.inbox = StreamController<InboxSnapshot>.broadcast();
    await cubit.retry();
    repository.inbox.add(fresh([salary]));
    await pumpEventQueue();

    expect(repository.watches, 2);
    expect(cubit.state.items, [salary]);
  });

  test('retrying after a failed refresh does not listen twice', () async {
    repository.onRefresh = () async => const Failed(TimeoutFailure());
    cubit.start();
    await pumpEventQueue();

    await cubit.retry();

    expect(repository.watches, 1);
    expect(repository.refreshes, 2);
  });

  group('markRead', () {
    setUp(() async {
      repository.onRefresh = () async => Success(fresh([salary, signIn]));
      cubit.start();
      await pumpEventQueue();
    });

    test('shows the notification as read at once', () async {
      final marking = cubit.markRead(salary);

      expect(cubit.state.items!.first.isRead, isTrue);
      expect(cubit.state.unreadCount, 1);
      await marking;
      expect(repository.markedRead, [salary.id]);
    });

    test('goes back to unread when the backend refuses', () async {
      repository.onMarkRead = (_) async => const Failed(TimeoutFailure());

      await cubit.markRead(salary);

      expect(cubit.state.items!.first.isRead, isFalse);
      expect(cubit.state.unreadCount, 2);
    });

    test('does not ask the backend for one already read', () async {
      await cubit.markRead(travel);

      expect(repository.markedRead, isEmpty);
    });

    test('a refusal puts back only the unread mark, keeping what arrived '
        'while the backend was answering', () async {
      final answer = Completer<Result<void>>();
      repository.onMarkRead = (_) => answer.future;
      final reworded = InboxItem(
        id: salary.id,
        title: 'Recibiste un pago',
        body: salary.body,
        kind: salary.kind,
        destination: salary.destination,
        createdAt: salary.createdAt,
        isRead: false,
      );

      final marking = cubit.markRead(salary);
      repository.inbox.add(fresh([travel, reworded, signIn]));
      await pumpEventQueue();
      answer.complete(const Failed(TimeoutFailure()));
      await marking;

      expect(cubit.state.items, [travel, reworded, signIn]);
    });

    test('a snapshot that arrives while marking does not show the '
        'notification as unread again', () async {
      final answer = Completer<Result<void>>();
      repository.onMarkRead = (_) => answer.future;

      final marking = cubit.markRead(salary);
      repository.inbox.add(fresh([salary, signIn]));
      await pumpEventQueue();

      expect(cubit.state.items!.first.isRead, isTrue);
      expect(cubit.state.unreadCount, 1);

      answer.complete(const Success(null));
      await marking;

      expect(cubit.state.items!.first.isRead, isTrue);
    });

    test('a refusal for a notification that is no longer in the inbox '
        'changes nothing', () async {
      final answer = Completer<Result<void>>();
      repository.onMarkRead = (_) => answer.future;

      final marking = cubit.markRead(salary);
      repository.inbox.add(fresh([signIn]));
      await pumpEventQueue();
      answer.complete(const Failed(TimeoutFailure()));
      await marking;

      expect(cubit.state.items, [signIn]);
    });
  });

  test(
    'an answer that arrives after the session ended changes nothing',
    () async {
      final answer = Completer<Result<InboxSnapshot>>();
      repository.onRefresh = () => answer.future;
      cubit.start();
      await cubit.close();

      answer.complete(Success(fresh([salary])));
      await pumpEventQueue();

      expect(cubit.state.items, isNull);
    },
  );
}
