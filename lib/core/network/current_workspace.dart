import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/exceptions.dart';
import 'firebase_client.dart';

/// The workspace the signed-in user belongs to.
///
/// A brand-new account has no membership yet, and the Firestore rules refuse
/// a direct `create` on /workspaces (a workspace must appear together with
/// its owner membership), so the first workspace is created by the
/// `ensureMyWorkspace` Cloud Function — the twin of the old
/// `ensure_my_workspace()` SECURITY DEFINER function.
class CurrentWorkspace {
  CurrentWorkspace(this._db);

  final FirebaseFirestoreResolver _db;

  String? _id;
  String? _userId;

  Future<String> resolve() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const UnauthorizedException();
    }
    // The cache is scoped to the account: signing out and back in as somebody
    // else must not reuse the previous workspace.
    if (_id != null && _userId == user.uid) return _id!;

    final resolved = await runFirestore('workspace.resolve', () async {
      final db = _db();

      // 1. The per-user pointer written by the last resolve / invite accept.
      final pointer = await db.doc('users/${user.uid}').get();
      final cached = pointer.data()?['defaultWorkspaceId'] as String?;
      if (cached != null && cached.isNotEmpty) {
        final member =
            await db.doc('workspaces/$cached/members/${user.uid}').get();
        if (member.exists) return cached;
      }

      // 2. The Cloud Function: finds a membership or bootstraps the first
      //    workspace, then refreshes the pointer.
      final result = await callFunction('ensureMyWorkspace', const {});
      final workspaceId = result['workspaceId'] as String?;
      if (workspaceId == null || workspaceId.isEmpty) {
        throw const ServerException('تعذّر إنشاء مساحة عمل لهذا الحساب.');
      }
      return workspaceId;
    });

    _userId = user.uid;
    return _id = resolved;
  }

  /// Forgets the cached id, e.g. after the session changes.
  void reset() {
    _id = null;
    _userId = null;
  }
}

final currentWorkspaceProvider = Provider<CurrentWorkspace>(
  (ref) => CurrentWorkspace(ref.watch(firebaseClientResolverProvider)),
);
