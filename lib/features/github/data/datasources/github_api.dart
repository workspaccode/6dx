import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/github_installation.dart';
import '../models/github_repository_model.dart';

/// GitHub access goes through the Supabase Edge Function `github-app`.
///
/// The App private key never leaves the server: the function mints a
/// short-lived installation token and calls GitHub on the app's behalf, so the
/// client never holds a GitHub credential and can only see the repositories the
/// user (or the org admin) selected when installing the App.
class GithubApi {
  GithubApi(this._client);

  final SupabaseClientResolver _client;

  static const String _function = 'github-app';

  Future<List<GithubRepositoryModel>> listRepositories() async {
    final data = await _invoke('repositories');
    final rows = data['repositories'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => GithubRepositoryModel.fromJson(_stringKeys(row)))
        .toList(growable: false);
  }

  /// The installation connected to the current workspace, if any.
  Future<GithubInstallation?> installation() async {
    final data = await _invoke('installation');
    final raw = data['installation'];
    if (raw is! Map) return null;
    final installation = _stringKeys(raw);
    return GithubInstallation(
      installationId: (installation['installation_id'] as num?)?.toInt() ?? 0,
      accountLogin: installation['account_login'] as String? ?? '',
      accountType: installation['account_type'] as String? ?? 'User',
    );
  }

  /// The GitHub page where the user picks the repositories to expose.
  Future<String> installUrl() async {
    final data = await _invoke('install-url');
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ServerException('تعذّر إنشاء رابط تثبيت تطبيق GitHub.');
    }
    return url;
  }

  Future<void> disconnect() => _invoke('disconnect');

  Future<Map<String, dynamic>> _invoke(String action) async {
    final FunctionResponse response;
    try {
      response = await _client().functions.invoke(
        _function,
        body: {'action': action},
      );
    } on FunctionException catch (error) {
      throw ServerException(_describe(error, action));
    }

    final data = response.data;
    if (data is Map) return _stringKeys(data);
    return const {};
  }

  static Map<String, dynamic> _stringKeys(Map<dynamic, dynamic> source) => {
        for (final entry in source.entries) '${entry.key}': entry.value,
      };

  static String _describe(FunctionException error, String action) {
    final details = error.details;
    final code = details is Map ? details['error'] as String? : null;
    switch (code) {
      case 'no_installation':
        return 'لم يتم تثبيت تطبيق GitHub على أي مستودع بعد.';
      case 'not_workspace_admin':
        return 'إدارة تطبيق GitHub تحتاج صلاحية admin في مساحة العمل.';
      case 'github_not_configured':
        return 'تطبيق GitHub غير مُهيّأ على الخادم (GITHUB_APP_ID / '
            'GITHUB_PRIVATE_KEY).';
    }
    if (error.status == 401) return 'انتهت الجلسة، سجّل الدخول من جديد.';
    return 'تعذّر تنفيذ "$action" على GitHub (${error.status}).';
  }
}
