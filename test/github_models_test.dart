import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/github/data/models/github_repository_model.dart';

/// GitHub answers with snake_case keys and **numeric** ids. Parsing the raw
/// payload with the Dart field names used to throw a `TypeError` on `id`, which
/// the app reported as an endlessly retried request.
void main() {
  group('repository payload', () {
    test('decodes a real /user/repos entry', () {
      final model = GithubRepositoryModel.fromJson({
        'id': 1296269,
        'node_id': 'MDEwOlJlcG9zaXRvcnkxMjk2MjY5',
        'name': 'Hello-World',
        'full_name': 'octocat/Hello-World',
        'private': false,
        'fork': true,
        'html_url': 'https://github.com/octocat/Hello-World',
        'description': 'This your first repo!',
        'language': 'Dart',
        'stargazers_count': 80,
        'open_issues_count': 3,
        'default_branch': 'main',
        'updated_at': '2026-11-01T10:20:30Z',
        'owner': {'login': 'octocat', 'id': 1},
      });

      expect(model.id, '1296269');
      expect(model.fullName, 'octocat/Hello-World');
      expect(model.htmlUrl, 'https://github.com/octocat/Hello-World');
      expect(model.isPrivate, isFalse);
      expect(model.isFork, isTrue);
      expect(model.stargazersCount, 80);
      expect(model.openIssuesCount, 3);
      expect(model.defaultBranch, 'main');
      expect(model.updatedAt, DateTime.utc(2026, 11, 1, 10, 20, 30));

      final entity = model.toEntity();
      expect(entity.owner, 'octocat');
      expect(entity.repo, 'Hello-World');
    });

    test('tolerates the fields GitHub omits', () {
      final model = GithubRepositoryModel.fromJson({
        'id': 7,
        'name': 'empty',
        'full_name': 'me/empty',
      });

      expect(model.id, '7');
      expect(model.description, isNull);
      expect(model.language, isNull);
      expect(model.stargazersCount, 0);
      expect(model.updatedAt, isNull);
    });
  });

  group('issue / pull request payloads', () {
    test('issue keeps its numeric id and number as strings', () {
      final issue = GithubIssueModel.fromJson({
        'id': 1001,
        'number': 42,
        'title': 'Crash on launch',
        'state': 'open',
        'user': {'login': 'octocat'},
        'created_at': '2026-10-30T08:00:00Z',
      });

      expect(issue.id, '1001');
      expect(issue.number, '42');
      expect(issue.isPullRequest, isFalse);
      expect(issue.userLogin, 'octocat');
    });

    test('an issue that is actually a PR is flagged', () {
      final issue = GithubIssueModel.fromJson({
        'id': 2,
        'number': 43,
        'title': 'Add CI',
        'pull_request': {'url': 'https://api.github.com/…'},
      });

      expect(issue.isPullRequest, isTrue);
    });

    test('pull request decodes head/base refs and counters', () {
      final pr = GithubPullRequestModel.fromJson({
        'id': 3003,
        'number': 12,
        'title': 'Wire the snapshot',
        'state': 'open',
        'user': {'login': 'octocat'},
        'head': {'ref': 'feat/snapshot'},
        'base': {'ref': 'main'},
        'additions': 120,
        'deletions': 4,
        'changed_files': 6,
        'comments': 2,
        'draft': true,
        'mergeable': null,
        'created_at': '2026-10-29T12:00:00Z',
      });

      expect(pr.id, '3003');
      expect(pr.number, '12');
      expect(pr.headBranch, 'feat/snapshot');
      expect(pr.baseBranch, 'main');
      expect(pr.additions, 120);
      expect(pr.changedFiles, 6);
      expect(pr.isDraft, isTrue);
      expect(pr.mergeable, isFalse);
    });
  });

  group('user payload', () {
    test('decodes /user', () {
      final user = GithubUserModel.fromJson({
        'login': 'octocat',
        'id': 583231,
        'name': 'The Octocat',
        'email': null,
        'avatar_url': 'https://avatars.githubusercontent.com/u/583231?v=4',
        'bio': null,
        'public_repos': 8,
        'followers': 16000,
        'following': 9,
      });

      expect(user.id, '583231');
      expect(user.login, 'octocat');
      expect(user.avatarUrl, contains('avatars.githubusercontent.com'));
      expect(user.publicRepos, 8);
      expect(user.followers, 16000);
    });
  });
}
