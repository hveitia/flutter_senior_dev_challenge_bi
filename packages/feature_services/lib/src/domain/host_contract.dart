import 'dart:convert';

/// The contract between the bank's app (the host) and a partner's page.
///
/// It is deliberately small. The host tells the page two things about the
/// customer, neither of which identifies them, and the page can tell the
/// host two things: that it is done, or that it wants to be closed.
abstract final class HostContract {
  /// The version of this contract, sent with the context.
  static const int version = 1;

  /// The object the page posts its messages to:
  /// `BancaDigitalHost.postMessage(JSON.stringify({type: 'close'}))`.
  static const String channel = 'BancaDigitalHost';

  static const String typeKey = 'type';
  static const String contextType = 'context';
  static const String closeType = 'close';
  static const String completedType = 'completed';
  static const String referenceKey = 'reference';
  static const String versionKey = 'version';
  static const String localeKey = 'locale';
  static const String segmentKey = 'segment';

  /// Longest message the host reads. Anything longer is dropped unread.
  static const int maxMessageLength = 512;

  /// Longest reference of a completed operation.
  static const int maxReferenceLength = 40;

  /// Segment sent when the app does not know the customer's.
  static const String unknownSegment = 'unknown';
}

/// What the host tells the page once it has loaded. Nothing here names the
/// customer: no identifier, no name, no balance and no credential.
final class HostContext {
  const HostContext({required this.locale, required this.segment});

  /// The language of the app: `es-EC`.
  final String locale;

  /// The customer's segment as published: `family`.
  final String segment;

  /// The context as the JSON object the page receives. A [segment] that is
  /// not a plain identifier is sent as [HostContract.unknownSegment].
  Map<String, Object> toJson() => {
    HostContract.typeKey: HostContract.contextType,
    HostContract.versionKey: HostContract.version,
    HostContract.localeKey: locale,
    HostContract.segmentKey: _identifier.hasMatch(segment)
        ? segment
        : HostContract.unknownSegment,
  };

  /// A segment id as the published configuration bounds it.
  static final RegExp _identifier = RegExp(r'^[a-zA-Z][a-zA-Z0-9]{0,31}$');
}

/// Something the page told the host.
sealed class PartnerMessage {
  const PartnerMessage();
}

/// The page asks to be closed.
final class PartnerClosed extends PartnerMessage {
  const PartnerClosed();
}

/// The page finished what the customer came for.
final class PartnerCompleted extends PartnerMessage {
  const PartnerCompleted({this.reference});

  /// The partner's reference for the operation, when it gave one.
  final String? reference;
}

/// Reads [raw], a message posted by the page. Null when it is not a message
/// of the contract: too long, not a JSON object, an unknown type, or a
/// reference that is not a short plain code. Keys the contract does not
/// name are ignored.
PartnerMessage? parsePartnerMessage(String raw) {
  if (raw.length > HostContract.maxMessageLength) return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, Object?>) return null;

  switch (decoded[HostContract.typeKey]) {
    case HostContract.closeType:
      return const PartnerClosed();
    case HostContract.completedType:
      if (!decoded.containsKey(HostContract.referenceKey)) {
        return const PartnerCompleted();
      }
      final reference = decoded[HostContract.referenceKey];
      if (reference is! String || !_reference.hasMatch(reference)) return null;
      return PartnerCompleted(reference: reference);
    default:
      return null;
  }
}

/// A short plain code: letters, digits and hyphens. It is shown to the
/// customer, so nothing that could be markup or a sentence gets through.
final RegExp _reference = RegExp(
  '^[A-Za-z0-9-]{1,${HostContract.maxReferenceLength}}\$',
);
