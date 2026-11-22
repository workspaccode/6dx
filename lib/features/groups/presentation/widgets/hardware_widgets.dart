import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// One text field of [askForm].
class FormFieldSpec {
  const FormFieldSpec(
    this.key,
    this.label, {
    this.required = false,
    this.maxLength,
    this.number = false,
    this.multiline = false,
    this.initial,
    this.hint,
  });

  final String key;
  final String label;
  final bool required;
  final int? maxLength;
  final bool number;
  final bool multiline;
  final String? initial;
  final String? hint;
}

/// A small form in a bottom sheet; returns the trimmed values, or null when
/// dismissed. Required fields block "حفظ" until filled.
Future<Map<String, String>?> askForm(
  BuildContext context, {
  required String title,
  required List<FormFieldSpec> fields,
  String submit = 'حفظ',
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FormSheet(title: title, fields: fields, submit: submit),
  );
}

class _FormSheet extends StatefulWidget {
  const _FormSheet({required this.title, required this.fields, required this.submit});
  final String title;
  final List<FormFieldSpec> fields;
  final String submit;

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields) f.key: TextEditingController(text: f.initial),
  };
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final values = {for (final e in _controllers.entries) e.key: e.value.text.trim()};
    for (final f in widget.fields) {
      final v = values[f.key]!;
      if (f.required && v.isEmpty) {
        setState(() => _error = '«${f.label}» مطلوب.');
        return;
      }
      if (f.number && v.isNotEmpty && num.tryParse(v) == null) {
        setState(() => _error = '«${f.label}» لازم يكون رقم.');
        return;
      }
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final (i, f) in widget.fields.indexed) ...[
              TextField(
                controller: _controllers[f.key],
                autofocus: i == 0,
                maxLength: f.maxLength,
                minLines: f.multiline ? 2 : 1,
                maxLines: f.multiline ? 5 : 1,
                keyboardType: f.number
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : (f.multiline ? TextInputType.multiline : TextInputType.text),
                decoration: InputDecoration(
                  labelText: f.required ? '${f.label} *' : f.label,
                  hintText: f.hint,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
            FilledButton(onPressed: _save, child: Text(widget.submit)),
          ],
        ),
      ),
    );
  }
}

/// Pick one of [options] in a bottom sheet.
Future<T?> pickOne<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) label,
  String Function(T)? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title, style: Theme.of(sheet).textTheme.titleMedium),
            ),
            if (options.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('مفيش اختيارات متاحة.'),
              ),
            for (final o in options)
              ListTile(
                title: Text(label(o)),
                subtitle: subtitle == null ? null : Text(subtitle(o)),
                onTap: () => Navigator.of(sheet).pop(o),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Small coloured status chip.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color = AppColors.textMuted});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12)),
      );
}

Color phaseColor(String status) => switch (status) {
      'in_progress' => AppColors.info,
      'ready_for_review' => AppColors.warning,
      'on_hold' => AppColors.warning,
      'passed' => AppColors.success,
      'killed' => AppColors.danger,
      _ => AppColors.textMuted,
    };

Color ecoColor(String status) => switch (status) {
      'design_review' || 'production_review' => AppColors.warning,
      'approved' => AppColors.info,
      'released' => AppColors.success,
      'rejected' || 'cancelled' => AppColors.danger,
      _ => AppColors.textMuted,
    };

Color unitColor(String status) => switch (status) {
      'passed' => AppColors.success,
      'failed' => AppColors.danger,
      'rework' => AppColors.warning,
      'scrapped' => AppColors.textDim,
      _ => AppColors.textMuted,
    };

/// '12.50' → 1250 cents; empty → null.
int? parseCents(String? text) {
  final value = num.tryParse((text ?? '').trim());
  if (value == null) return null;
  return (value * 100).round();
}
