import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_remote_data_source.dart';
import '../models/task_model.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._remote);

  final TaskRemoteDataSource _remote;

  final List<TaskModel> _cache = List.of(_seedTasks);

  @override
  Future<Result<List<Task>>> getTasks({String? projectId}) => _guard(() async {
        if (AppConfig.useMockData) {
          final filtered = projectId == null
              ? _cache
              : _cache.where((t) => t.projectId == projectId).toList();
          return filtered.map((e) => e.toEntity()).toList();
        }
        final tasks = await _remote.getTasks(projectId: projectId);
        _cache
          ..clear()
          ..addAll(tasks);
        return tasks.map((e) => e.toEntity()).toList();
      });

  @override
  Future<Result<Task>> getTask(String id) => _guard(() async {
        final found = _cache.firstWhere(
          (t) => t.id == id,
          orElse: () => _cache.first,
        );
        return found.toEntity();
      });

  @override
  Future<Result<Task>> createTask({
    required String title,
    String? description,
    String? projectId,
    TaskPriority priority = TaskPriority.medium,
    String? assigneeName,
  }) =>
      _guard(() async {
        final model = AppConfig.useMockData
            ? TaskModel(
                id: 't-${DateTime.now().millisecondsSinceEpoch}',
                title: title,
                description: description,
                status: TaskStatus.todo,
                priority: priority,
                projectId: projectId,
                projectName: '6DX Mobile',
                assigneeName: assigneeName ?? 'Sami',
                createdAt: DateTime.now(),
              )
            : await _remote.createTask(
                title: title,
                description: description,
                projectId: projectId,
                priority: priority.name,
                assigneeName: assigneeName,
              );
        _cache.insert(0, model);
        return model.toEntity();
      });

  @override
  Future<Result<Task>> updateStatus(String id, TaskStatus status) =>
      _guard(() async {
        final index = _cache.indexWhere((t) => t.id == id);
        if (index == -1) {
          throw const ServerException('Task not found');
        }
        final updated = _cache[index].copyWith(status: status);
        _cache[index] = updated;
        return updated.toEntity();
      });

  @override
  Future<Result<void>> deleteTask(String id) => _guard(() async {
        _cache.removeWhere((t) => t.id == id);
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on UnauthorizedException {
      return const Result.failure(Failure.unauthorized());
    } on NetworkException catch (e) {
      return Result.failure(Failure.network(e.message));
    } on ServerException catch (e) {
      return Result.failure(Failure.server(e.message));
    } on DioException catch (e) {
      return Result.failure(Failure.network(e.message ?? 'Network error'));
    } catch (e) {
      return Result.failure(Failure.unknown(e.toString()));
    }
  }

  static final List<TaskModel> _seedTasks = [
    const TaskModel(
      id: '58',
      title: 'صفحة تسجيل الدخول بكود OTP',
      description: 'تصميم وتنفيذ صفحة التحقق بخطأ لمرة واحدة (OTP).',
      status: TaskStatus.review,
      priority: TaskPriority.high,
      projectId: 'p-1',
      projectName: 'Mobile',
      assigneeName: 'Sami',
      label: 'مراجعة',
      prNumber: '58',
      branchName: 'feat/otp-login',
      subtasksDone: 4,
      subtasksTotal: 4,
      commentsCount: 7,
    ),
    const TaskModel(
      id: '61',
      title: 'ربط مستودع GitHub عبر GitHub App',
      description: 'تثبيت التطبيق والتحقق من الصلاحيات.',
      status: TaskStatus.inProgress,
      priority: TaskPriority.urgent,
      projectId: 'p-1',
      projectName: 'Mobile',
      assigneeName: 'Nadia',
      label: 'تطوير',
      prNumber: '61',
      branchName: 'feat/github-app',
      subtasksDone: 3,
      subtasksTotal: 6,
      commentsCount: 4,
    ),
    const TaskModel(
      id: '63',
      title: 'لوحة المهام — عرض الكانبو',
      description: 'السحب والإفلات بين الأعمدة.',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      projectId: 'p-1',
      projectName: 'Mobile',
      assigneeName: 'Omar',
      label: 'تطوير',
      subtasksDone: 0,
      subtasksTotal: 4,
      commentsCount: 0,
    ),
    const TaskModel(
      id: '70',
      title: 'الملخص اليومي للإشعارات',
      description: 'إرسال ملخص يومي بالبريد.',
      status: TaskStatus.done,
      priority: TaskPriority.low,
      projectId: 'p-2',
      projectName: 'Web',
      assigneeName: 'Sami',
      label: 'مهمة',
      subtasksDone: 5,
      subtasksTotal: 5,
      commentsCount: 2,
    ),
    const TaskModel(
      id: '72',
      title: 'تقرير الفاتورة للعميل',
      description: 'تصدير PDF مع الوقت المحسوب.',
      status: TaskStatus.inProgress,
      priority: TaskPriority.high,
      projectId: 'p-2',
      projectName: 'Web',
      assigneeName: 'Lina',
      label: 'عميل',
      subtasksDone: 2,
      subtasksTotal: 5,
      commentsCount: 3,
    ),
    const TaskModel(
      id: '75',
      title: 'خريطة المعرفة داخل المشروع',
      description: 'فهرسة المستندات والقرارات.',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      projectId: 'p-3',
      projectName: 'Design',
      assigneeName: 'Omar',
      label: 'بحث',
      subtasksDone: 1,
      subtasksTotal: 3,
      commentsCount: 1,
    ),
  ];
}
