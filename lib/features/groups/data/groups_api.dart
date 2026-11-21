import '../../../core/network/api_client.dart';
import '../../../core/network/current_workspace.dart';
import '../domain/group_models.dart';

/// `/v1/groups/...` and the invite-by-id endpoints.
///
/// Every call resolves the active workspace first, so `X-Workspace-Id` is
/// always sent: a group id alone is never enough to reach a group.
class GroupsApi {
  GroupsApi(this._api, this._workspace);

  final ApiClient _api;
  final CurrentWorkspace _workspace;

  Future<GroupsOverview> overview() => _api.run('groups.list', () async {
        await _workspace.resolve();
        final payload = await _api.get('/v1/groups');
        return GroupsOverview(
          groups: _list(payload['groups']).map(GroupSummary.fromJson).toList(),
          plan: PlanUsage.fromJson(_map(payload['plan'])),
        );
      });

  Future<GroupAccess> create({
    required String name,
    required GroupType type,
    String? template,
    String? description,
  }) =>
      _api.run('groups.create', () async {
        await _workspace.resolve();
        final payload = await _api.post('/v1/groups', body: {
          'name': name,
          'type': type.wire,
          if (template != null) 'template': template,
          if (description != null && description.isNotEmpty) 'description': description,
        });
        return GroupAccess.fromJson(_map(payload['group']));
      });

  Future<GroupAccess> access(String gid) => _api.run('groups.me', () async {
        await _workspace.resolve();
        final payload = await _api.get('/v1/groups/${_seg(gid)}/me');
        return GroupAccess.fromJson(_map(payload['group']));
      });

  Future<GroupAccess> update(
    String gid, {
    String? name,
    String? description,
    bool? archived,
  }) =>
      _api.run('groups.update', () async {
        await _workspace.resolve();
        final payload = await _api.patch('/v1/groups/${_seg(gid)}', body: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (archived != null) 'is_archived': archived,
        });
        return GroupAccess.fromJson(_map(payload['group']));
      });

  Future<void> delete(String gid) => _api.run('groups.delete', () async {
        await _workspace.resolve();
        await _api.delete('/v1/groups/${_seg(gid)}');
      });

  Future<void> transferLead(String gid, String uid) =>
      _api.run('groups.transfer', () async {
        await _workspace.resolve();
        await _api.post('/v1/groups/${_seg(gid)}/transfer', body: {'uid': uid});
      });

  Future<List<GroupMember>> members(String gid) =>
      _api.run('groups.members', () async {
        await _workspace.resolve();
        final payload = await _api.get('/v1/groups/${_seg(gid)}/members');
        return _list(payload['members']).map(GroupMember.fromJson).toList();
      });

  Future<void> updateMember(
    String gid,
    String uid, {
    GroupRole? groupRole,
    String? functionalRole,
  }) =>
      _api.run('groups.update_member', () async {
        await _workspace.resolve();
        await _api.patch('/v1/groups/${_seg(gid)}/members/${_seg(uid)}', body: {
          if (groupRole != null) 'group_role': groupRole.wire,
          if (functionalRole != null) 'functional_role': functionalRole,
        });
      });

  Future<void> removeMember(String gid, String uid) =>
      _api.run('groups.remove_member', () async {
        await _workspace.resolve();
        await _api.delete('/v1/groups/${_seg(gid)}/members/${_seg(uid)}');
      });

  Future<int> invite(
    String gid, {
    required List<String> emails,
    required GroupRole groupRole,
    required String functionalRole,
  }) =>
      _api.run('groups.invite', () async {
        await _workspace.resolve();
        final payload = await _api.post('/v1/groups/${_seg(gid)}/invites', body: {
          'emails': emails,
          'group_role': groupRole.wire,
          'functional_role': functionalRole,
        });
        return (payload['created'] as num?)?.toInt() ?? 0;
      });

  Future<List<GroupProject>> projects(String gid) =>
      _api.run('groups.projects', () async {
        await _workspace.resolve();
        final payload = await _api.get('/v1/projects', query: {'group_id': gid});
        return _list(payload['projects']).map(GroupProject.fromJson).toList();
      });

  Future<GroupProject> createProject(String gid, {required String name, String? description}) =>
      _api.run('groups.create_project', () async {
        await _workspace.resolve();
        final payload = await _api.post('/v1/projects', body: {
          'name': name,
          'group_id': gid,
          if (description != null && description.isNotEmpty) 'description': description,
        });
        return GroupProject.fromJson(_map(payload['project']));
      });

  Future<List<GroupTask>> tasks(String gid, {required String projectId}) =>
      _api.run('groups.tasks', () async {
        await _workspace.resolve();
        final payload = await _api.get('/v1/tasks',
            query: {'group_id': gid, 'project_id': projectId});
        return _list(payload['tasks']).map(GroupTask.fromJson).toList();
      });

  Future<void> createTask({required String projectId, required String title}) =>
      _api.run('groups.create_task', () async {
        await _workspace.resolve();
        await _api.post('/v1/tasks', body: {'title': title, 'project_id': projectId});
      });

  Future<void> setTaskStatus(String taskId, String status) =>
      _api.run('groups.task_status', () async {
        await _workspace.resolve();
        await _api.patch('/v1/tasks/${_seg(taskId)}/status', body: {'status': status});
      });

  /// The invite is addressed to an e-mail, not to a workspace: read it
  /// without X-Workspace-Id.
  Future<InviteDetails> inviteDetails(String inviteId) =>
      _api.run('invites.get', () async {
        final payload = await _api.get('/v1/invites/${_seg(inviteId)}');
        return InviteDetails.fromJson(_map(payload['invite']));
      });

  /// Accepts and switches to the joined workspace. Returns the group id.
  Future<String?> acceptInvite(String inviteId) =>
      _api.run('invites.accept', () async {
        final payload =
            await _api.post('/v1/invites/accept', body: {'invite_id': inviteId});
        final workspaceId = payload['workspace_id'] as String?;
        if (workspaceId != null && workspaceId.isNotEmpty) {
          _workspace.activate(workspaceId);
        }
        return payload['group_id'] as String?;
      });

  Future<void> declineInvite(String inviteId) =>
      _api.run('invites.decline', () async {
        await _api.post('/v1/invites/${_seg(inviteId)}/decline');
      });

  /// Path segments come from routes (user-controlled): encode them so an id
  /// can never reach another endpoint.
  static String _seg(String value) => Uri.encodeComponent(value);

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? value.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map>().map(_map).toList(growable: false)
      : const [];
}
