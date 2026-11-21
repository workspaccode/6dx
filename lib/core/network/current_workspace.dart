import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/exceptions.dart';
import 'api_client.dart';

/// The workspace the signed-in user is acting in.
///
/// A brand-new account has none yet, so the backend bootstraps one together
/// with the owner membership on the first `GET /v1/me`. The resolved id is
/// sent as `X-Workspace-Id` on every later request, which is how an account
/// that belongs to several workspaces acts on the one the UI shows.
class CurrentWorkspace {
  CurrentWorkspace(this._api);

  final ApiClient _api;

  String? _id;

  Future<String> resolve() async {
    if (_id != null && _id!.isNotEmpty) return _id!;
    final payload = await _api.run('workspace.resolve', () => _api.get('/v1/me'));
    final workspace = payload['workspace'];
    final id = workspace is Map ? workspace['id'] as String? : null;
    if (id == null || id.isEmpty) {
      throw const ServerException('تعذّر تحديد مساحة العمل لهذا الحساب.');
    }
    activate(id);
    return id;
  }

  /// The workspace currently active, or `null` before [resolve].
  String? get id => _id;

  /// Switches the active workspace (after accepting an invite, or from the
  /// workspace switcher).
  void activate(String id) {
    _id = id;
    _api.activeWorkspaceId = id;
  }

  /// Forgets the cached id, e.g. after the session changes.
  void reset() {
    _id = null;
    _api.activeWorkspaceId = null;
  }
}

final currentWorkspaceProvider = Provider<CurrentWorkspace>(
  (ref) => CurrentWorkspace(ref.watch(apiClientProvider)),
);
