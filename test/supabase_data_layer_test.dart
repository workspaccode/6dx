import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sixdx/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:sixdx/features/tasks/domain/entities/task.dart';
import 'package:sixdx/features/workspace/data/models/workspace_snapshot_mapper.dart';

void main() {
  group('snapshot mapper', () {
    test('reads the whole payload the database function returns', () {
      final snapshot = const WorkspaceSnapshotMapper().fromJson({
        'workspace_id': 'w-1',
        'name': '6DX',
        'members': [
          {'id': 'u-1', 'name': 'Sami', 'role': 'owner', 'open_tasks': 3},
        ],
        'sprints': [
          {
            'id': 's-1',
            'name': 'Sprint 4',
            'start': '2026-01-01',
            'end': '2026-01-14',
          },
        ],
        'dependencies': [
          {
            'id': 'd-1',
            'task_key': '6DX-7',
            'title': 'Ship the auth flow',
            'state': 'blocked',
            'reason': 'waiting for review',
          },
        ],
        'client_report': {
          'client_name': 'Acme',
          'project_name': '6DX',
          'progress': 0.5,
          'decision_options': ['Ship now', 'Wait'],
        },
      });

      expect(snapshot.workspaceId, 'w-1');
      expect(snapshot.members.single.name, 'Sami');
      expect(snapshot.members.single.openTasks, 3);
      // Regression: the `sprints` key used to be read with a leading space.
      expect(snapshot.sprints.single.name, 'Sprint 4');
      expect(snapshot.dependencies.single.taskKey, '6DX-7');
      expect(snapshot.dependencies.single.state, 'blocked');
      expect(snapshot.clientReport?.clientName, 'Acme');
      expect(snapshot.clientReport?.decisionOptions, ['Ship now', 'Wait']);
    });

    test('an empty payload is an empty snapshot', () {
      expect(const WorkspaceSnapshotMapper().fromJson(null).isEmpty, isTrue);
      expect(const WorkspaceSnapshotMapper().fromJson({}).isEmpty, isTrue);
    });
  });

  group('task status mapping', () {
    test('round-trips the values of the Postgres enum', () {
      for (final status in TaskStatus.values) {
        final stored = TaskRemoteDataSource.statusToDb(status);
        expect(TaskRemoteDataSource.statusFromDb(stored), status);
      }
      expect(TaskRemoteDataSource.statusToDb(TaskStatus.inProgress),
          'in_progress');
    });

    test('unknown values fall back to todo', () {
      expect(TaskRemoteDataSource.statusFromDb('paused'), TaskStatus.todo);
      expect(TaskRemoteDataSource.statusFromDb(null), TaskStatus.todo);
    });
  });

  group('postgres errors', () {
    test('missing tables, functions and grants explain how to fix it', () {
      expect(
        describePostgresError(
          const PostgrestException(message: 'nope', code: '42P01'),
        ),
        contains('supabase/migrations'),
      );
      expect(
        describePostgresError(
          const PostgrestException(message: 'nope', code: 'PGRST202'),
        ),
        contains('supabase/migrations'),
      );
      expect(
        describePostgresError(
          const PostgrestException(message: 'nope', code: '42501'),
        ),
        contains('grants'),
      );
    });

    test('anything else keeps the database message', () {
      expect(
        describePostgresError(
          const PostgrestException(message: 'duplicate key value'),
        ),
        'duplicate key value',
      );
    });
  });
}
