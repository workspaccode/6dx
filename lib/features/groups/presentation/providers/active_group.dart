import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// The group the classic screens (board, sprints, reviews, tasks…) show.
///
/// It travels as `X-Group-Id` on every request; the API checks membership and
/// scopes the snapshot and the lists to it. `null` = the workspace's default
/// group, i.e. the app as it was before groups.
///
/// Providers that load group data `ref.watch(activeGroupProvider)`, so
/// switching groups reloads them — no manual invalidation.
class ActiveGroupNotifier extends Notifier<String?> {
  @override
  String? build() {
    // A new account starts from its own default, never the previous one's.
    ref.watch(authNotifierProvider.select((state) => state.value?.id));
    final api = ref.read(apiClientProvider);
    // The API said "not a member" (removed from the group): fall back to
    // the default group instead of failing every screen.
    api.onGroupRevoked = clear;
    final remembered = _storage()?.lastGroupId;
    api.activeGroupId = remembered;
    return remembered;
  }

  void select(String groupId) {
    if (state == groupId) return;
    ref.read(apiClientProvider).activeGroupId = groupId;
    _storage()?.setLastGroupId(groupId);
    state = groupId;
  }

  void clear() {
    ref.read(apiClientProvider).activeGroupId = null;
    _storage()?.setLastGroupId(null);
    state = null;
  }

  /// The app always provides local storage; a bare container (tests) does
  /// not, and the choice then lives in memory only.
  LocalStorageService? _storage() {
    try {
      return ref.read(localStorageServiceProvider);
    } catch (_) {
      return null;
    }
  }
}

final activeGroupProvider =
    NotifierProvider<ActiveGroupNotifier, String?>(ActiveGroupNotifier.new);
