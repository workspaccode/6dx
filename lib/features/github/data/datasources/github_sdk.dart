import 'package:github/github.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/current_workspace.dart';

/// A ready-to-use `github` package client for the current workspace.
///
/// The token is **not** the user's OAuth token with a `repo` scope. It is a
/// short-lived installation token minted by the 6DX backend after it has
/// checked the caller's role:
///
///   * it can only reach the repositories the GitHub App was granted,
///   * it expires in an hour (the user's own OAuth grant is a separate,
///     longer-lived credential — see docs/review/03-security.md #19),
///   * it is issued only to `owner`/`admin`/`developer`/`reviewer` — a `viewer`
///     gets a 403 and never sees a token,
///   * the App private key and client secret never leave the server.
///
/// That keeps the workspace roles meaningful: with a `repo`-scoped user token
/// on the device, every member — including a viewer — could write to every
/// private repository directly.
class GithubSdk {
  GithubSdk(this._api, this._workspace);

  final ApiClient _api;
  final CurrentWorkspace _workspace;

  GitHub? _client;
  DateTime? _expiresAt;

  /// The workspace the cached token was minted for. A token is only reused
  /// for the same workspace; switching workspace or account drops it.
  String? _workspaceId;

  /// The authenticated client, refreshed before the installation token dies.
  Future<GitHub> client() async {
    final workspaceId = await _workspace.resolve();
    if (_client != null &&
        _workspaceId == workspaceId &&
        _expiresAt != null &&
        DateTime.now().isBefore(_expiresAt!)) {
      return _client!;
    }
    reset();

    final payload = await _api.run(
      'github.token',
      () => _api.post('/v1/github/token'),
    );

    final token = payload['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('github: the API returned no token');
    }
    final expiresAt = DateTime.tryParse('${payload['expires_at']}');

    _client = GitHub(auth: Authentication.withToken(token));
    // The API already subtracts a safety margin; keep the value as-is so a
    // long-running session refreshes in time.
    _expiresAt = expiresAt;
    _workspaceId = workspaceId;
    return _client!;
  }

  /// Drops the cached client — call after disconnecting or switching projects.
  void reset() {
    _client = null;
    _expiresAt = null;
    _workspaceId = null;
  }

  // --- conveniences over the package's services ---------------------------

  /// Open pull requests of a repository (`owner/name`).
  Future<List<PullRequest>> pullRequests(String fullName) async {
    final github = await client();
    final slug = RepositorySlug.full(fullName);
    return github.pullRequests.list(slug).toList();
  }

  /// Issues of a repository, optionally only the open ones.
  Future<List<Issue>> issues(String fullName, {bool openOnly = true}) async {
    final github = await client();
    final slug = RepositorySlug.full(fullName);
    return github.issues
        .listByRepo(slug, state: openOnly ? 'open' : 'all')
        .toList();
  }

  /// Files changed by a pull request.
  Future<List<Map<String, dynamic>>> pullRequestFiles(
    String fullName,
    int number,
  ) async {
    final github = await client();
    final slug = RepositorySlug.full(fullName);
    final files = await github.pullRequests.listFiles(slug, number).toList();
    return [
      for (final file in files)
        {
          'filename': file.filename,
          'status': file.status,
          'additions': file.additionsCount,
          'deletions': file.deletionsCount,
        },
    ];
  }

  /// Files in a repository at a ref (defaults to the default branch).
  Future<List<String>> repositoryTree(String fullName, {String? ref}) async {
    final github = await client();
    final slug = RepositorySlug.full(fullName);
    final tree = await github.git.getTree(slug, ref ?? 'HEAD', recursive: true);
    return [
      for (final entry in tree.entries ?? const <GitTreeEntry>[])
        if (entry.path != null) entry.path!,
    ];
  }

  /// The repositories the App installation can reach, straight from GitHub.
  Future<List<Repository>> repositories() async {
    final github = await client();
    final result = await github.request('GET', '/installation/repositories');
    final raw = result.body as Map<String, dynamic>?;
    final list = (raw?['repositories'] as List?) ?? const [];
    return [
      for (final item in list)
        Repository.fromJson(item as Map<String, dynamic>),
    ];
  }
}
