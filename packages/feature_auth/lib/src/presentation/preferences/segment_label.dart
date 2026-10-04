import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';

/// How [segment] is named to the customer, the same words the sign-up and
/// "Personalización" use.
String segmentLabel(Segment segment) => AuthStrings.segment(segment);
