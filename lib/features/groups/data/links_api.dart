import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/current_workspace.dart';
import '../domain/hardware_models.dart';
import '../presentation/providers/group_providers.dart';
import '../presentation/providers/hardware_providers.dart';

/// Links between projects of different groups — §3.1. A link shows a
/// summary of the other project, never its tasks list, BOM, prices or
/// members.

class LinkedProjectRef {
  const LinkedProjectRef({
    required this.projectId,
    required this.projectName,
    required this.groupName,
    required this.groupType,
  });

  final String projectId;
  final String projectName;
  final String groupName;
  final String groupType;

  bool get isHardware => groupType == 'hardware';

  factory LinkedProjectRef.fromJson(Map<String, dynamic> json) => LinkedProjectRef(
        projectId: '${json['project_id']}',
        projectName: '${json['project_name'] ?? ''}',
        groupName: '${json['group_name'] ?? ''}',
        groupType: '${json['group_type'] ?? 'software'}',
      );
}

class ProjectLink {
  const ProjectLink({
    required this.id,
    required this.status,
    required this.outgoing,
    required this.other,
    this.note,
  });

  final String id;
  final String status;
  final bool outgoing;
  final LinkedProjectRef other;
  final String? note;

  bool get isActive => status == 'active';
  bool get isRequested => status == 'requested';

  factory ProjectLink.fromJson(Map<String, dynamic> json) => ProjectLink(
        id: '${json['id']}',
        status: '${json['status'] ?? 'requested'}',
        outgoing: json['outgoing'] == true,
        other: LinkedProjectRef.fromJson(hwMap(json['other'])),
        note: json['note'] as String?,
      );
}

class ProjectLinks {
  const ProjectLinks({required this.links, required this.canManage});
  final List<ProjectLink> links;
  final bool canManage;
}

class LinkTaskRef {
  const LinkTaskRef({required this.taskId, required this.title, required this.status, required this.mine});
  final String taskId;
  final String title;
  final String status;
  final bool mine;

  bool get done => status == 'done';

  factory LinkTaskRef.fromJson(Map<String, dynamic> json) => LinkTaskRef(
        taskId: '${json['task_id']}',
        title: '${json['title'] ?? ''}',
        status: '${json['status'] ?? 'todo'}',
        mine: json['mine'] == true,
      );
}

class LinkDependency {
  const LinkDependency({required this.id, required this.waiting, required this.dependsOn});
  final String id;
  final LinkTaskRef waiting;
  final LinkTaskRef dependsOn;

  factory LinkDependency.fromJson(Map<String, dynamic> json) => LinkDependency(
        id: '${json['id']}',
        waiting: LinkTaskRef.fromJson(hwMap(json['waiting'])),
        dependsOn: LinkTaskRef.fromJson(hwMap(json['depends_on'])),
      );
}

class LinkSummary {
  const LinkSummary({
    required this.projectName,
    required this.groupName,
    required this.groupType,
    required this.openTasks,
    required this.doneTasks,
    required this.phases,
    required this.releasedBom,
    required this.firmware,
    required this.dependencies,
    required this.canEdit,
  });

  final String projectName;
  final String groupName;
  final String groupType;
  final int openTasks;
  final int doneTasks;
  final List<({String name, String status})> phases;
  final String? releasedBom;
  final List<({String tag, String bomRev})> firmware;
  final List<LinkDependency> dependencies;
  final bool canEdit;

  factory LinkSummary.fromJson(Map<String, dynamic> json) {
    final s = hwMap(json['summary']);
    return LinkSummary(
      projectName: '${s['project_name'] ?? ''}',
      groupName: '${s['group_name'] ?? ''}',
      groupType: '${s['group_type'] ?? 'software'}',
      openTasks: hwInt(s['open_tasks']),
      doneTasks: hwInt(s['done_tasks']),
      phases: [for (final p in hwList(s['phases'])) (name: '${p['name']}', status: '${p['status']}')],
      releasedBom: s['released_bom'] as String?,
      firmware: [
        for (final f in hwList(s['firmware'])) (tag: '${f['firmware_tag']}', bomRev: '${f['bom_rev']}'),
      ],
      dependencies: hwList(json['dependencies']).map(LinkDependency.fromJson).toList(),
      canEdit: json['can_edit'] == true,
    );
  }
}

class LinksApi {
  LinksApi(this._api, this._workspace);
  final ApiClient _api;
  final CurrentWorkspace _workspace;

  static String _seg(String v) => Uri.encodeComponent(v);
  String _base(String gid, String pid) => '/v1/groups/${_seg(gid)}/projects/${_seg(pid)}/links';

  Future<Map<String, dynamic>> _call(String op, String method, String path, [Object? body]) =>
      _api.run(op, () async {
        await _workspace.resolve();
        return switch (method) {
          'GET' => _api.get(path),
          'POST' => _api.post(path, body: body ?? const <String, dynamic>{}),
          _ => _api.delete(path),
        };
      });

  Future<ProjectLinks> links(String gid, String pid) async {
    final p = await _call('links.list', 'GET', _base(gid, pid));
    return ProjectLinks(
      links: hwList(p['links']).map(ProjectLink.fromJson).toList(),
      canManage: p['can_manage'] == true,
    );
  }

  Future<List<LinkedProjectRef>> candidates(String gid, String pid) async =>
      hwList((await _call('links.candidates', 'GET', '${_base(gid, pid)}/candidates'))['projects'])
          .map(LinkedProjectRef.fromJson)
          .toList();

  Future<void> request(String gid, String pid, {required String toProjectId, String? note}) =>
      _call('links.request', 'POST', _base(gid, pid), {
        'to_project_id': toProjectId,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  Future<void> approve(String gid, String pid, String lid) =>
      _call('links.approve', 'POST', '${_base(gid, pid)}/${_seg(lid)}/approve');

  Future<void> revoke(String gid, String pid, String lid) =>
      _call('links.revoke', 'POST', '${_base(gid, pid)}/${_seg(lid)}/revoke');

  Future<LinkSummary> summary(String gid, String pid, String lid) async =>
      LinkSummary.fromJson(await _call('links.summary', 'GET', '${_base(gid, pid)}/${_seg(lid)}/summary'));

  Future<List<LinkTaskRef>> otherTasks(String gid, String pid, String lid) async =>
      hwList((await _call('links.tasks', 'GET', '${_base(gid, pid)}/${_seg(lid)}/tasks'))['tasks'])
          .map(LinkTaskRef.fromJson)
          .toList();

  Future<void> addDependency(String gid, String pid, String lid, {required String taskId, required String dependsOn}) =>
      _call('links.dep_add', 'POST', '${_base(gid, pid)}/${_seg(lid)}/deps', {'task_id': taskId, 'depends_on': dependsOn});

  Future<void> removeDependency(String gid, String pid, String lid, String did) =>
      _call('links.dep_remove', 'DELETE', '${_base(gid, pid)}/${_seg(lid)}/deps/${_seg(did)}');
}

final linksApiProvider = Provider<LinksApi>(
  (ref) => LinksApi(ref.watch(apiClientProvider), ref.watch(currentWorkspaceProvider)),
);

void _bind(Ref ref) => ref.watch(authNotifierProvider.select((state) => state.value?.id));

final projectLinksProvider = FutureProvider.family<ProjectLinks, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(linksApiProvider).links(key.gid, key.pid);
});

final linkSummaryProvider = FutureProvider.family<LinkSummary, HwItemKey>((ref, key) {
  _bind(ref);
  return ref.watch(linksApiProvider).summary(key.gid, key.pid, key.id);
});
