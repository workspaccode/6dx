import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/current_workspace.dart';
import '../../../../core/network/firebase_client.dart';
import '../../domain/entities/github_installation.dart';
import '../models/github_repository_model.dart';

/// GitHub access goes through the `githubAction` Cloud Function.
///
/// The App private key never leaves the server: the function mints a
/// short-lived installation token and calls GitHub on the app's behalf, so the
/// client never holds a GitHub credential and can only see the repositories
/// the user (or the org admin) selected when installing the App.
class GithubApi {
  GithubApi(this._workspace);

  final CurrentWorkspace _workspace;

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
      installationId: (installation['installationId'] as num?)?.toInt() ?? 0,
      accountLogin: installation['accountLogin'] as String? ?? '',
      accountType: installation['accountType'] as String? ?? 'User',
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

  Future<void> disconnect() async => _invoke('disconnect');

  Future<Map<String, dynamic>> _invoke(String action) async =>
      callFunction('githubAction', {
        'action': action,
        'workspaceId': await _workspace.resolve(),
      });

  static Map<String, dynamic> _stringKeys(Map<dynamic, dynamic> source) => {
        for (final entry in source.entries) '${entry.key}': entry.value,
      };
}
