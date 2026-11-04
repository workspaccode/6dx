import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/exceptions.dart';
import '../utils/logger.dart';

/// Resolves the Supabase client on demand.
///
/// `main()` initialises Supabase before `runApp`, but the data layer is also
/// built in tests where Supabase was never initialised, so the client is
/// resolved per call instead of while constructing a provider.
typedef SupabaseClientResolver = SupabaseClient Function();

SupabaseClient _resolveClient() => Supabase.instance.client;

final supabaseClientResolverProvider = Provider<SupabaseClientResolver>(
  (ref) => _resolveClient,
);

/// Runs a query and turns PostgREST / GoTrue failures into the exceptions the
/// repositories understand.
///
/// [label] names the operation (`projects.list`, `tasks.create`, …) so the log
/// shows exactly which step failed:
/// `[ACTION] Data: projects.list → ok (42ms)` or
/// `[ACTION] Data: projects.list → FAILED 42501: permission denied`.
Future<T> runSupabase<T>(String label, Future<T> Function() action) async {
  final started = DateTime.now();
  AppLogger.action('Data', '$label → start');
  try {
    final result = await action();
    AppLogger.action('Data', '$label → ok (${_elapsed(started)}ms)');
    return result;
  } on PostgrestException catch (error) {
    AppLogger.action(
      'Data',
      '$label → FAILED [${error.code}] ${error.message}',
    );
    throw ServerException(describePostgresError(error));
  } on AuthException catch (error) {
    AppLogger.action('Data', '$label → FAILED [auth] ${error.message}');
    throw const UnauthorizedException();
  } catch (error) {
    AppLogger.action('Data', '$label → FAILED $error');
    rethrow;
  }
}

String _elapsed(DateTime started) =>
    '${DateTime.now().difference(started).inMilliseconds}';

/// Short, actionable message for the Postgres errors that mean "the database
/// is not set up yet" — they are configuration mistakes, not user errors.
String describePostgresError(PostgrestException error) {
  switch (error.code) {
    case '42P01': // undefined_table
    case 'PGRST205': // table missing from the schema cache
      return 'جداول قاعدة البيانات غير مثبّتة — طبّق ملفات supabase/migrations.';
    case '42883': // undefined_function
    case 'PGRST202': // function missing from the schema cache
      return 'دوال قاعدة البيانات غير مثبّتة — طبّق ملفات supabase/migrations.';
    case '42501': // insufficient_privilege
      return 'لا توجد صلاحيات على قاعدة البيانات — أعد تطبيق '
          'supabase/migrations لضبط الـ grants.';
    default:
      return error.message;
  }
}
