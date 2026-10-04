import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/data/transfer_ports.dart';
import 'package:feature_accounts/src/domain/transfer.dart';
import 'package:feature_accounts/src/transfers_telemetry.dart';
import 'package:http/http.dart' as http;

/// The customer API over HTTP (`docs/operacion/api.md`).
///
/// Every request carries the customer's identity token; the server takes
/// who the customer is from it and from nothing else. Nothing of a request
/// or of an answer is logged. Timeouts and retries belong to the resilience
/// policy in front of this adapter.
final class HttpTransfersApi implements TransfersApi {
  HttpTransfersApi({
    required Uri baseUrl,
    required Future<String?> Function({required bool forceRefresh}) idToken,
    required http.Client client,
  }) : _baseUrl = baseUrl,
       _idToken = idToken,
       _client = client;

  final Uri _baseUrl;
  final Future<String?> Function({required bool forceRefresh}) _idToken;
  final http.Client _client;

  static const String _transfersPath = 'api/transfers';
  static const String _provisionPath = 'api/accounts/provision';

  static const int _ok = 200;
  static const int _unauthorized = 401;
  static const int _notFound = 404;
  static const int _rejected = 422;
  static const int _serverErrors = 500;

  static const String _transferRejected = 'transfer-rejected';
  static const String _unknownCode = 'unknown';

  @override
  Future<ApiTransferAnswer> submit(TransferOrder order) async {
    final response = await _post(_transfersPath, {
      'transferId': order.id,
      'fromAccountId': order.fromAccountId,
      'toAccountId': order.toAccountId,
      'amountCents': order.amountCents,
      'concept': order.concept,
    });
    return _answer(response);
  }

  @override
  Future<ApiTransferAnswer> process(String transferId) async {
    final response = await _post(
      '$_transfersPath/${Uri.encodeComponent(transferId)}/process',
    );
    if (response.statusCode == _notFound) return const ApiTransferNotFound();
    return _answer(response);
  }

  @override
  Future<void> provisionAccounts() async {
    final response = await _post(_provisionPath);
    if (response.statusCode != _ok) throw _failureOf(response);
  }

  /// Posts with the customer's token. A token the server does not accept is
  /// refreshed once and the same request sent again: tokens expire hourly,
  /// and the device may be holding a stale one. A second refusal is final.
  Future<http.Response> _post(String path, [Map<String, Object?>? body]) async {
    final first = await _send(path, body, forceRefresh: false);
    if (first.statusCode != _unauthorized) return first;
    return _send(path, body, forceRefresh: true);
  }

  Future<http.Response> _send(
    String path,
    Map<String, Object?>? body, {
    required bool forceRefresh,
  }) async {
    final token = await _idToken(forceRefresh: forceRefresh);
    if (token == null) {
      throw const ApiContractError(_unauthorized, 'unauthorized');
    }
    final request = http.Request('POST', _baseUrl.resolve(path))
      // A redirect is never followed: the token is for this server only.
      ..followRedirects = false
      ..headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    if (body != null) {
      request
        ..headers[HttpHeaders.contentTypeHeader] =
            'application/json; charset=utf-8'
        ..bodyBytes = utf8.encode(jsonEncode(body));
    }
    try {
      return await http.Response.fromStream(await _client.send(request));
    } on SocketException {
      // The device has a connection (the policy checked) but the server
      // did not take the call. That is the server being unavailable, worth
      // another attempt; calling it "offline" would queue an order that
      // may be waiting for a server that is simply down.
      throw const ServiceUnavailableFailure(TransfersTelemetry.service);
    } on http.ClientException {
      throw const ServiceUnavailableFailure(TransfersTelemetry.service);
    }
  }

  ApiTransferAnswer _answer(http.Response response) {
    final body = _json(response);
    final transfer = body['transfer'];
    if (response.statusCode == _ok &&
        transfer is Map<String, Object?> &&
        transfer['reference'] is String) {
      return ApiTransferCompleted(transfer['reference']! as String);
    }
    if (response.statusCode == _rejected &&
        body['error'] == _transferRejected) {
      return ApiTransferRejected(TransferRejection.fromCode(body['reason']));
    }
    throw _failureOf(response);
  }

  /// A server that is failing is worth trying again; anything else is an
  /// answer about this request that trying again will not change.
  Exception _failureOf(http.Response response) {
    if (response.statusCode >= _serverErrors) {
      return const ServiceUnavailableFailure(TransfersTelemetry.service);
    }
    final code = _json(response)['error'];
    return ApiContractError(
      response.statusCode,
      code is String ? code : _unknownCode,
    );
  }

  Map<String, Object?> _json(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}
