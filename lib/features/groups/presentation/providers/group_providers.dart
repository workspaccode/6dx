import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/current_workspace.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/groups_api.dart';
import '../../domain/group_models.dart';
import '../../domain/workflow_models.dart';

final groupsApiProvider = Provider<GroupsApi>(
  (ref) => GroupsApi(ref.watch(apiClientProvider), ref.watch(currentWorkspaceProvider)),
);

/// Re-runs on account change, so a new session never sees the previous
/// account's groups.
void _bindToSession(Ref ref) {
  ref.watch(authNotifierProvider.select((state) => state.value?.id));
}

/// My groups in the active workspace + the plan counter.
final groupsOverviewProvider = FutureProvider<GroupsOverview>((ref) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).overview();
});

/// The caller's roles and capabilities in one group. Every group screen
/// watches it; buttons are enabled from `access.can(...)`.
final groupAccessProvider =
    FutureProvider.family<GroupAccess, String>((ref, gid) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).access(gid);
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, gid) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).members(gid);
});

final groupProjectsProvider =
    FutureProvider.family<List<GroupProject>, String>((ref, gid) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).projects(gid);
});

typedef ProjectKey = ({String gid, String pid});

final groupTasksProvider =
    FutureProvider.family<List<GroupTask>, ProjectKey>((ref, key) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).tasks(key.gid, projectId: key.pid);
});

/// The group's task states; the project screen groups tasks by them.
final groupWorkflowProvider =
    FutureProvider.family<GroupWorkflow, String>((ref, gid) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).workflow(gid);
});

/// What the group home shows for the caller's role.
final groupHomeProvider = FutureProvider.family<GroupHome, String>((ref, gid) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).home(gid);
});

final projectAccessProvider =
    FutureProvider.family<ProjectAccess, ProjectKey>((ref, key) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).projectAccess(key.gid, key.pid);
});

final projectMembersProvider =
    FutureProvider.family<List<ProjectMemberOverride>, ProjectKey>((ref, key) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).projectMembers(key.gid, key.pid);
});

final inviteDetailsProvider =
    FutureProvider.autoDispose.family<InviteDetails, String>((ref, id) {
  _bindToSession(ref);
  return ref.watch(groupsApiProvider).inviteDetails(id);
});

/// Remembers the group the user opened last.
final lastGroupIdProvider = Provider<LastGroup>(
  (ref) => LastGroup(ref),
);

class LastGroup {
  LastGroup(this._ref);
  final Ref _ref;

  String? get id => _ref.read(localStorageServiceProvider).lastGroupId;

  Future<void> set(String? id) =>
      _ref.read(localStorageServiceProvider).setLastGroupId(id);
}
