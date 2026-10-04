import 'dart:convert';
import 'dart:io';

import 'package:app_platform/app_platform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_accounts/adapters.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const order = TransferOrder(
    id: 'order-0000000000000001',
    fromAccountId: 'savings',
    toAccountId: 'checking',
    amountCents: 15010,
    concept: 'Arriendo',
  );

  late List<http.Request> requests;

  HttpTransfersApi api(
    http.Response Function(http.Request request) answer, {
    String? token = 'id-token',
  }) {
    requests = [];
    return HttpTransfersApi(
      baseUrl: Uri.parse('https://api.example.com/'),
      idToken: () async => token,
      client: MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
    );
  }

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  group('submit', () {
    test('posts the order with the customer token and exactly the fields '
        'the server accepts', () async {
      final answer = await api(
        (_) => json(200, {
          'transfer': {
            'id': order.id,
            'status': 'completed',
            'processedAt': '2026-10-03T14:00:00.000Z',
            'reference': 'TRF-202610-3FA91C07B2',
          },
        }),
      ).submit(order);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://api.example.com/api/transfers');
      expect(request.headers['authorization'], 'Bearer id-token');
      expect(jsonDecode(request.body), {
        'transferId': order.id,
        'fromAccountId': 'savings',
        'toAccountId': 'checking',
        'amountCents': 15010,
        'concept': 'Arriendo',
      });
      expect(
        answer,
        isA<ApiTransferCompleted>().having(
          (completed) => completed.reference,
          'reference',
          'TRF-202610-3FA91C07B2',
        ),
      );
    });

    test('reads a rejection and its reason', () async {
      final answer = await api(
        (_) => json(422, {
          'error': 'transfer-rejected',
          'reason': 'insufficient-funds',
        }),
      ).submit(order);

      expect(
        answer,
        isA<ApiTransferRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          TransferRejection.insufficientFunds,
        ),
      );
    });

    test('a server that is failing is a service unavailable, worth trying '
        'again', () {
      expect(
        api((_) => json(503, {'error': 'unavailable'})).submit(order),
        throwsA(isA<ServiceUnavailableFailure>()),
      );
    });

    test('an answer about the request itself carries the server code and is '
        'not retried', () {
      expect(
        api(
          (_) => json(409, {'error': 'idempotency-key-reused'}),
        ).submit(order),
        throwsA(
          isA<ApiContractError>()
              .having((error) => error.status, 'status', 409)
              .having((error) => error.code, 'code', 'idempotency-key-reused'),
        ),
      );
    });

    test('a 200 without a reference is not taken for a completed transfer', () {
      expect(
        api((_) => json(200, {'transfer': <String, Object?>{}})).submit(order),
        throwsA(isA<ApiContractError>()),
      );
    });

    test('a body that is not JSON does not break the client', () {
      expect(
        api((_) => http.Response('<html>', 502)).submit(order),
        throwsA(isA<ServiceUnavailableFailure>()),
      );
    });

    test('without a session token, asks the server nothing', () async {
      await expectLater(
        api((_) => json(200, {}), token: null).submit(order),
        throwsA(isA<ApiContractError>()),
      );
      expect(requests, isEmpty);
    });

    test('a server that does not take the call is unavailable, not the '
        'device being offline', () {
      final unreachable = HttpTransfersApi(
        baseUrl: Uri.parse('https://api.example.com/'),
        idToken: () async => 'id-token',
        client: MockClient((_) => throw const SocketException('unreachable')),
      );

      expect(
        unreachable.submit(order),
        throwsA(isA<ServiceUnavailableFailure>()),
      );
    });
  });

  group('process', () {
    test('posts to the order by id, with no body', () async {
      await api(
        (_) => json(200, {
          'transfer': {'reference': 'TRF-1'},
        }),
      ).process(order.id);

      expect(
        requests.single.url.path,
        '/api/transfers/${order.id}/process',
      );
      expect(requests.single.body, isEmpty);
    });

    test(
      'an order the server does not have is an answer, not an error',
      () async {
        final answer = await api(
          (_) => json(404, {'error': 'transfer-not-found'}),
        ).process(order.id);

        expect(answer, isA<ApiTransferNotFound>());
      },
    );
  });

  group('provisionAccounts', () {
    test('posts to the provisioning route', () async {
      await api((_) => json(200, {'created': true})).provisionAccounts();

      expect(requests.single.url.path, '/api/accounts/provision');
    });

    test('fails when the customer has no profile yet', () {
      expect(
        api(
          (_) => json(422, {'error': 'profile-required'}),
        ).provisionAccounts(),
        throwsA(isA<ApiContractError>()),
      );
    });
  });

  group('FirestoreTransferQueue.encode', () {
    test('writes exactly the six fields the rules allow, pending and dated '
        'by the server', () {
      final document = FirestoreTransferQueue.encode(order);

      expect(document.keys, {
        'fromAccountId',
        'toAccountId',
        'amountCents',
        'concept',
        'status',
        'createdAt',
      });
      expect(document['status'], 'pending');
      expect(document['amountCents'], 15010);
      expect(document['createdAt'], isA<FieldValue>());
    });
  });
}
