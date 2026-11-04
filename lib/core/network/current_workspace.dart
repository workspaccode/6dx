import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/exceptions.dart';
import 'supabase_client.dart';

/// The workspace the signed-in user belongs to.
///
/// A brand-new account has no membership yet, and RLS has no insert policy on
/// `workspaces` (a member has to exist before anything can be read), so the
/// first workspace is created by the `ensure_my_workspace()` SECURITY DEFINER
/// function — see `supabase/migrations/0002_workspace_bootstrap.sql`.
class CurrentWorkspace {
  CurrentWorkspace(this._client);

  final SupabaseClientResolver _client;

  String? _id;
  String? _userId;

  Future<String> resolve() async {
    final db = _client();
    final user = db.auth.currentUser;
    if (user == null) {
      throw const UnauthorizedException();
    }
    // The cache is scoped to the account: signing out and back in as somebody
    // else must not reuse the previous workspace.
    if (_id != null && _userId == user.id) return _id!;

    final resolved = await runSupabase('workspace.resolve', () async {
      final rows = await db
          .from('workspace_members')
          .select('workspace_id')
          .eq('user_id', user.id)
          .limit(1);
      if (rows.isNotEmpty) {
        return rows.first['workspace_id'] as String;
      }
      final created = await db.rpc('ensure_my_workspace');
      if (created is String && created.isNotEmpty) return created;
      throw const ServerException('تعذّر إنشاء مساحة عمل لهذا الحساب.');
    });

    _userId = user.id;
    return _id = resolved;
  }

  /// Forgets the cached id, e.g. after the session changes.
  void reset() {
    _id = null;
    _userId = null;
  }
}

final currentWorkspaceProvider = Provider<CurrentWorkspace>(
  (ref) => CurrentWorkspace(ref.watch(supabaseClientResolverProvider)),
);
