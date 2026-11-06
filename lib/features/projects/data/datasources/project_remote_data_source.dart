import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import '../../../../core/network/current_workspace.dart';
import '../../../../core/network/firebase_client.dart';
import '../models/project_model.dart';

/// Projects of the current workspace, stored under
/// `workspaces/{id}/projects` with their repositories as subcollections.
class ProjectRemoteDataSource {
  ProjectRemoteDataSource(this._db, this._workspace);

  final FirebaseFirestoreResolver _db;
  final CurrentWorkspace _workspace;

  Future<List<ProjectModel>> getProjects() =>
      runFirestore('projects.list', () async {
        final db = _db();
        final wsId = await _workspace.resolve();
        final snapshot = await db
            .collection('workspaces/$wsId/projects')
            .orderBy('updatedAt', descending: true)
            .get();

        // The model needs the linked repository and the task statuses, so
        // one round of parallel reads feeds the whole projects screen.
        // Tasks live at the workspace level with a `projectId`, mirroring the
        // SQL schema, so the count is a filtered query, not a subcollection.
        final repositories = await Future.wait([
          for (final project in snapshot.docs)
            project.reference.collection('repositories').limit(1).get(),
        ]);
        final taskCounts = await Future.wait([
          for (final project in snapshot.docs)
            db
                .collection('workspaces/$wsId/tasks')
                .where('projectId', isEqualTo: project.id)
                .get(),
        ]);

        return [
          for (var i = 0; i < snapshot.docs.length; i++)
            _toModel(
              snapshot.docs[i],
              repositories[i].docs,
              taskCounts[i].docs,
            ),
        ];
      });

  Future<ProjectModel> createProject({
    required String name,
    String? description,
    String? repositoryFullName,
  }) =>
      runFirestore('projects.create', () async {
        final db = _db();
        final wsId = await _workspace.resolve();
        final now = FieldValue.serverTimestamp();
        final ref = db.collection('workspaces/$wsId/projects').doc();
        final hasRepository = repositoryFullName != null && repositoryFullName.isNotEmpty;

        await ref.set({
          'name': name,
          'description': description,
          'icon': null,
          'color': null,
          'isArchived': false,
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'createdAt': now,
          'updatedAt': now,
        });
        if (hasRepository) {
          await ref.collection('repositories').add({
            'provider': 'github',
            'fullName': repositoryFullName,
            'branch': 'main',
          });
        }

        return ProjectModel(
          id: ref.id,
          name: name,
          description: description,
          icon: null,
          colorHex: null,
          openTasks: 0,
          doneTasks: 0,
          repositoryFullName:
              hasRepository ? repositoryFullName : null,
          isArchived: false,
          updatedAt: DateTime.now(),
        );
      });

  /// Projects are archived, never deleted: the `archived` filter reads the flag.
  Future<void> archiveProject(String id) =>
      runFirestore('projects.archive', () async {
        final db = _db();
        await db
            .doc('workspaces/${await _workspace.resolve()}/projects/$id')
            .update({
          'isArchived': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  ProjectModel _toModel(
    DocumentSnapshot project,
    List<QueryDocumentSnapshot> repositories,
    List<QueryDocumentSnapshot> tasks,
  ) {
    var openTasks = 0;
    var doneTasks = 0;
    for (final task in tasks) {
      if (task.get('status') == 'done') {
        doneTasks++;
      } else {
        openTasks++;
      }
    }

    return ProjectModel(
      id: project.id,
      name: project.get('name') as String? ?? '',
      description: project.get('description') as String?,
      icon: project.get('icon') as String?,
      colorHex: project.get('color') as String?,
      openTasks: openTasks,
      doneTasks: doneTasks,
      repositoryFullName: repositories.isEmpty
          ? null
          : repositories.first.get('fullName') as String?,
      isArchived: project.get('isArchived') == true,
      updatedAt: _toDateTime(project.get('updatedAt')) ?? DateTime.now(),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
