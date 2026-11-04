import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../providers/project_providers.dart';

@RoutePage()
class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({super.key});

  @override
  ConsumerState<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends ConsumerState<CreateProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _repositoryFullName;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickRepository() async {
    final picked = await context.push<String>(AppRoutes.connectRepository);
    if (!mounted || picked == null) return;
    setState(() => _repositoryFullName = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(projectsNotifierProvider.notifier).create(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          repositoryFullName: _repositoryFullName,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إنشاء المشروع')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مشروع جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'اسم المشروع'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'أدخل اسم المشروع' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'الوصف (اختياري)'),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _pickRepository,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(
                    _repositoryFullName == null
                        ? 'ربط مستودع GitHub'
                        : 'تغيير المستودع',
                  ),
                ),
                if (_repositoryFullName != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _repositoryFullName!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'إزالة',
                        onPressed: () =>
                            setState(() => _repositoryFullName = null),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('إنشاء المشروع'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
