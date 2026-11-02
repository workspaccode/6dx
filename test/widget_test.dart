import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/core/errors/failures.dart';
import 'package:sixdx/core/utils/result.dart';
import 'package:sixdx/features/tasks/domain/entities/task.dart';
import 'package:sixdx/shared/widgets/status_badge.dart';

void main() {
  group('Result', () {
    test('holds a success value', () {
      const result = Result<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('holds a failure', () {
      final result = Result<int>.failure(Failure.network('offline'));

      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, isA<Failure>());
    });
  });

  group('Task entity', () {
    test('exposes a project based key', () {
      const task = Task(
        id: '24',
        title: 'OTP login',
        projectName: 'Mobile',
      );

      expect(task.key, 'MOBILE-24');
    });

    test('is overdue only when the due date has passed', () {
      final overdue = Task(
        id: '1',
        title: 'Old',
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      final fresh = Task(
        id: '2',
        title: 'New',
        dueDate: DateTime.now().add(const Duration(days: 1)),
      );
      final done = Task(
        id: '3',
        title: 'Done',
        status: TaskStatus.done,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(overdue.isOverdue, isTrue);
      expect(fresh.isOverdue, isFalse);
      expect(done.isOverdue, isFalse);
    });
  });

  testWidgets('StatusBadge renders its label', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StatusBadge(label: 'مراجعة', color: Colors.amber),
          ),
        ),
      ),
    );

    expect(find.text('مراجعة'), findsOneWidget);
  });
}
