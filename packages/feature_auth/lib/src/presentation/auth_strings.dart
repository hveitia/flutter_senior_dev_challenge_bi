import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/domain/validators/password_policy.dart';

/// Every text the access screens show, in one place.
abstract final class AuthStrings {
  static const String productName = 'Banca Digital';
  static const String back = 'Volver';

  // Welcome
  static const String welcomeTitle = 'Tu banco, sin filas ni sucursales';
  static const String welcomeBody =
      'Todo lo que necesitas para manejar tu dinero, desde donde estés.';
  static const String welcomeFast = 'Abre tu cuenta en minutos';
  static const String welcomePersonal = 'Una experiencia que se adapta a ti';
  static const String welcomeServices =
      'Servicios y beneficios en un solo lugar';
  static const String openAccount = 'Abrir mi cuenta';
  static const String alreadyCustomer = 'Ya soy cliente';

  // Login
  static const String loginTitle = 'Hola de nuevo';
  static const String loginBody = 'Tu dinero y tus proyectos, aquí contigo.';
  static const String email = 'Correo electrónico';
  static const String password = 'Contraseña';
  static const String showPassword = 'Mostrar contraseña';
  static const String hidePassword = 'Ocultar contraseña';
  static const String forgotPassword = 'Olvidé mi contraseña';
  static const String signIn = 'Ingresar';
  static const String noAccountYet = '¿Todavía no tienes una cuenta?';
  static const String openYourAccount = 'Abre tu cuenta';
  static const String passwordRequired = 'Ingresa tu contraseña';

  /// Shown whether or not the address belongs to an account.
  static const String passwordResetSent =
      'Si el correo está registrado, te enviaremos un enlace para '
      'restablecer tu contraseña.';

  // Sign-up
  static const String signUpTitle = 'Abre tu cuenta';
  static const String completeProfileTitle = 'Completa tu perfil';
  static const String next = 'Continuar';
  static const String signOut = 'Cerrar sesión';

  static const String personalDataTitle = 'Tus datos';
  static const String personalDataBody = 'Empecemos con lo esencial.';
  static const String nationalId = 'Cédula';
  static const String fullName = 'Nombres y apellidos';
  static const String phone = 'Celular';
  static const String phoneHint = '099 123 4567';
  static const String nationalIdInvalid =
      'Ingresa una cédula válida de 10 dígitos';
  static const String fullNameInvalid = 'Ingresa tus nombres y apellidos';
  static const String emailInvalid = 'Ingresa un correo electrónico válido';
  static const String emailTaken = 'Este correo ya está registrado';
  static const String phoneInvalid = 'Ingresa un celular válido de 10 dígitos';

  static const String interestsTitle = 'Cuéntanos qué te interesa';
  static const String interestsBody =
      'Usamos esto para personalizar tu inicio. Puedes cambiarlo cuando '
      'quieras.';
  static const String segmentQuestion = '¿Qué te describe mejor?';
  static const String skip = 'Omitir por ahora';

  static const String preferencesTitle = 'Personalización';
  static const String preferencesHeading = 'Mis intereses';
  static const String preferencesBody =
      'Tu inicio se adapta a lo que elijas aquí.';
  static const String savePreferences = 'Guardar cambios';
  static const String preferencesSaved = 'Guardamos tus preferencias';

  static const String accessTitle = 'Protege tu acceso';
  static const String accessBody = 'Crea una contraseña que solo tú conozcas.';
  static const String biometricUnlock = 'Ingresar con huella o rostro';
  static const String createAccount = 'Crear mi cuenta';
  static const String acceptTerms =
      'Acepto los términos y condiciones y la política de privacidad';
  static const String termsLead = 'Acepto los ';
  static const String terms = 'términos y condiciones';
  static const String termsJoin = ' y la ';
  static const String privacy = 'política de privacidad';
  static const String termsEnd = '.';
  static const String legalNotice =
      'Documento de demostración. En un producto real, aquí se muestra el '
      'texto legal vigente.';
  static const String close = 'Cerrar';

  // Unlock
  static const String unlockBody = 'Confirma tu identidad para entrar.';
  static const String unlockReason = 'Confirma tu identidad para ingresar';
  static const String unlockFailed =
      'No pudimos confirmar tu identidad. Intenta de nuevo o ingresa con tu '
      'contraseña.';
  static const String usePassword = 'Ingresar con contraseña';

  // Session unavailable
  static const String unavailableTitle = 'No pudimos cargar tu información';
  static const String unavailableBody =
      'Revisa tu conexión e intenta de nuevo.';
  static const String retry = 'Reintentar';

  static const String offline =
      'Sin conexión. Revisa tu red e intenta de nuevo';

  /// Greets by name only when the session behind the lock has one.
  static String unlockGreeting(String? firstName) =>
      firstName == null ? loginTitle : '$loginTitle, $firstName';

  /// The message for [failure]. Rejected credentials get one wording for
  /// every cause, so the screen never hints at which field was wrong.
  static String failureMessage(AuthFailure failure) => switch (failure) {
    AuthFailure.invalidCredentials =>
      'No pudimos validar tus datos. Revisa e intenta de nuevo.',
    AuthFailure.emailAlreadyInUse => emailTaken,
    AuthFailure.weakPassword => 'Elige una contraseña más segura.',
    AuthFailure.offline => offline,
    AuthFailure.unavailable =>
      'No pudimos completar la operación. Intenta de nuevo en unos minutos.',
    AuthFailure.unexpected =>
      'Ocurrió un problema inesperado. Intenta de nuevo.',
  };

  static String interest(Interest interest) => switch (interest) {
    Interest.saving => 'Ahorrar',
    Interest.investing => 'Invertir',
    Interest.travel => 'Viajar',
    Interest.billPayments => 'Pagar servicios',
    Interest.credit => 'Créditos',
    Interest.insurance => 'Seguros',
    Interest.business => 'Mi negocio',
  };

  static String segment(Segment segment) => switch (segment) {
    Segment.starting => 'Estoy empezando',
    Segment.family => 'Familia',
    Segment.wealth => 'Patrimonio',
  };

  static String passwordRequirement(PasswordRequirement requirement) =>
      switch (requirement) {
        PasswordRequirement.minLength =>
          'Al menos ${PasswordPolicy.minLength} caracteres',
        PasswordRequirement.uppercase => 'Una letra mayúscula',
        PasswordRequirement.number => 'Un número',
        PasswordRequirement.symbol => 'Un símbolo',
      };
}
