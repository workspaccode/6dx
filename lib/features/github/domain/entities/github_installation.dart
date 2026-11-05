/// A GitHub App installation: the account that installed it and which
/// repositories it can see.
///
/// Repositories are never "all of the account" — the user (or the org admin)
/// picks them during installation, and the server mints a short-lived token
/// limited to that selection.
class GithubInstallation {
  const GithubInstallation({
    required this.installationId,
    required this.accountLogin,
    required this.accountType,
  });

  final int installationId;
  final String accountLogin;
  final String accountType;

  bool get isOrganization => accountType.toLowerCase() == 'organization';

  /// `owner` for an organization, `@login` for a personal account.
  String get displayName => isOrganization ? accountLogin : '@$accountLogin';
}
