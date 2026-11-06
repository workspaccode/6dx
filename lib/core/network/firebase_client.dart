import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/exceptions.dart';
import '../utils/logger.dart';

/// Resolves Firestore and Functions on demand.
///
/// `main()` initialises Firebase before `runApp`, but the data layer is also
/// built in tests where Firebase was never initialised, so every client is
/// resolved per call instead of while constructing a provider.
typedef FirebaseFirestoreResolver = FirebaseFirestore Function();
typedef FirebaseFunctionsResolver = FirebaseFunctions Function();

FirebaseFirestore _resolveDb() => FirebaseFirestore.instance;
FirebaseFunctions _resolveFunctions() => FirebaseFunctions.instanceFor(
      app: Firebase.app(),
      region: 'europe-west1',
    );

final firebaseClientResolverProvider = Provider<FirebaseFirestoreResolver>(
  (ref) => _resolveDb,
);

final firebaseFunctionsResolverProvider =
    Provider<FirebaseFunctionsResolver>((ref) => _resolveFunctions);

/// Runs a Firestore/Firebase operation and turns platform failures into the
/// exceptions the repositories understand.
///
/// [label] names the operation (`projects.list`, `tasks.create`, …) so the log
/// shows exactly which step failed:
/// `[ACTION] Data: projects.list → ok (42ms)` or
/// `[ACTION] Data: projects.list → FAILED permission-denied`.
Future<T> runFirestore<T>(String label, Future<T> Function() action) async {
  final started = DateTime.now();
  AppLogger.action('Data', '$label → start');
  try {
    final result = await action();
    AppLogger.action('Data', '$label → ok (${_elapsed(started)}ms)');
    return result;
  } on FirebaseAuthException catch (error) {
    AppLogger.action('Data', '$label → FAILED [auth] ${error.message}');
    if (error.code == 'invalid-credential' || error.code == 'user-not-found') {
      throw const UnauthorizedException();
    }
    throw ServerException(describeAuthError(error));
  } on FirebaseException catch (error) {
    AppLogger.action(
      'Data',
      '$label → FAILED [${error.code}] ${error.message}',
    );
    if (error.code == 'permission-denied') {
      throw const ServerException(
        'لا توجد صلاحيات على قاعدة البيانات — راجع firestore.rules.',
      );
    }
    if (error.code == 'unavailable') {
      throw const ServerException('تعذّر الوصول لقاعدة البيانات — تحقق من الاتصال.');
    }
    throw ServerException(error.message ?? 'خطأ غير معروف من قاعدة البيانات.');
  } catch (error) {
    AppLogger.action('Data', '$label → FAILED $error');
    rethrow;
  }
}

String _elapsed(DateTime started) =>
    '${DateTime.now().difference(started).inMilliseconds}';

/// Short, actionable messages for the auth errors the screens surface.
String describeAuthError(FirebaseAuthException error) {
  switch (error.code) {
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
    default:
      return error.message ?? 'تعذّر إتمام العملية.';
  }
}

/// Calls a Cloud Function and unwraps its result, mapping FirebaseFunctionsException
/// to the exceptions the repositories understand.
Future<Map<String, dynamic>> callFunction(
  String name,
  Map<String, dynamic> data,
) =>
    runFirestore('functions.$name', () async {
      final functions = _resolveFunctions();
      try {
        final result = await functions.httpsCallable(name).call(data);
        final payload = result.data;
        if (payload is Map<String, dynamic>) return payload;
        if (payload is Map) {
          return <String, dynamic>{
            for (final entry in payload.entries) '${entry.key}': entry.value,
          };
        }
        return <String, dynamic>{};
      } on FirebaseFunctionsException catch (error) {
        throw ServerException(
          error.details is String ? error.details as String : (error.message ?? 'تعذّر إتمام العملية.'),
        );
      }
    });
