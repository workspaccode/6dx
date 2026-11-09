import '../../../../core/errors/exceptions.dart';

/// Short, actionable messages for the Firebase auth errors the screens show.
///
/// (Firebase is the identity provider only; everything else lives in the Go
/// backend, which is why this mapping sits next to the auth backend rather than
/// in the network layer.)
String describeAuthError(Object error) {
  final code = error is Exception ? _codeOf(error) : '';
  switch (code) {
    case 'email-already-in-use':
      return 'البريد الإلكتروني مستخدم بالفعل — سجّل الدخول بدلاً من التسجيل.';
    case 'weak-password':
      return 'كلمة السر ضعيفة — استخدم 6 أحرف على الأقل.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'البريد الإلكتروني أو كلمة السر غير صحيحة.';
    case 'user-not-found':
      return 'لا يوجد حساب بهذا البريد الإلكتروني.';
    case 'too-many-requests':
      return 'محاولات كثيرة — استرح شوية وحاول تاني.';
    case 'network-request-failed':
      return 'تعذّر الاتصال بالشبكة — تحقق من الإنترنت.';
    case 'invalid-verification-code':
      return 'الكود غير صحيح — تأكد منه وحاول تاني.';
    case 'account-exists-with-different-credential':
      return 'هذا البريد مسجّل بطريقة دخول أخرى — استخدم نفس الطريقة السابقة.';
    case 'operation-not-allowed':
      return 'طريقة الدخول هذه غير مُفعّلة في مشروع Firebase.';
    default:
      return 'تعذّر إتمام عملية الدخول.';
  }
}

String _codeOf(Object error) {
  try {
    // FirebaseAuthException exposes `code`; reflection-free access keeps this
    // file free of the plugin import.
    final dynamic dynamicError = error;
    final code = dynamicError.code;
    return code is String ? code : '';
  } catch (_) {
    return '';
  }
}

/// Re-exported so callers keep a single import for the auth error type.
typedef AuthError = ServerException;
