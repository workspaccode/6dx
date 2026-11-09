import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/current_workspace.dart';
import '../../domain/entities/github_installation.dart';
import '../models/github_repository_model.dart';

/// GitHub access goes through the Go backend (`/v1/github/*`).
///
/// The App private key never leaves the server: the API mints a short-lived
/// installation token and calls GitHub on the app's behalf, so the client never
/// holds a GitHub credential and can only see the repositories the user (or the
/// org admin) selected when installing the App.
class GithubApi {
  GithubApi(this._api, this._workspace);

  final ApiClient _api;
  final CurrentWorkspace _workspace;

  Future<List<GithubRepositoryModel>> listRepositories() async {
    await _workspace.resolve();
    final data = await _api.run('github.repositories',
        () => _api.get('/v1/github/repositories'));
    final rows = data['repositories'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => GithubRepositoryModel.fromJson(_stringKeys(row)))
        .toList(growable: false);
  }

  /// The installation connected to the current workspace, if any.
  Future<GithubInstallation?> installation() async {
    await _workspace.resolve();
    final data = await _api.run(
        'github.installation', () => _api.get('/v1/github/installation'));
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
    await _workspace.resolve();
    final data = await _api.run(
        'github.install_url', () => _api.post('/v1/github/install-url'));
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ServerException('تعذّر إنشاء رابط تثبيت تطبيق GitHub.');
    }
    return url;
  }

  Future<void> disconnect() async {
    await _workspace.resolve();
    await _api.run('github.disconnect', () => _api.post('/v1/github/disconnect'));
  }

  static Map<String, dynamic> _stringKeys(Map<dynamic, dynamic> source) => {
        for (final entry in source.entries) '${entry.key}': entry.value,
      };
}
