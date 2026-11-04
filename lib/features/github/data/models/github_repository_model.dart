import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/github_repository.dart';

part 'github_repository_model.freezed.dart';
part 'github_repository_model.g.dart';

// GitHub answers with snake_case keys and numeric ids, while the app uses
// strings for every identifier — so the decoding is explicit here instead of
// relying on the Dart field names. Parsing the raw payload with the field names
// threw a TypeError on `id`, which surfaced as an endlessly retried request.

String _idAsString(Object? value) => value == null ? '' : '$value';

String? _ref(Object? value) => value is Map ? value['ref'] as String? : null;

String? _login(Object? value) =>
    value is Map ? value['login'] as String? : null;

bool _isPresent(Object? value) => value != null;

@freezed
abstract class GithubRepositoryModel with _$GithubRepositoryModel {
  const GithubRepositoryModel._();

  const factory GithubRepositoryModel({
    @JsonKey(fromJson: _idAsString) required String id,
    required String name,
    @JsonKey(name: 'full_name') required String fullName,
    String? description,
    @JsonKey(name: 'html_url') String? htmlUrl,
    String? language,
    @JsonKey(name: 'private') @Default(false) bool isPrivate,
    @JsonKey(name: 'fork') @Default(false) bool isFork,
    @JsonKey(name: 'stargazers_count') @Default(0) int stargazersCount,
    @JsonKey(name: 'open_issues_count') @Default(0) int openIssuesCount,
    @JsonKey(name: 'default_branch') String? defaultBranch,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _GithubRepositoryModel;

  factory GithubRepositoryModel.fromJson(Map<String, dynamic> json) =>
      _$GithubRepositoryModelFromJson(json);

  GithubRepository toEntity() => GithubRepository(
        id: id,
        name: name,
        fullName: fullName,
        description: description,
        htmlUrl: htmlUrl,
        language: language,
        isPrivate: isPrivate,
        stargazersCount: stargazersCount,
        openIssuesCount: openIssuesCount,
        defaultBranch: defaultBranch,
      );
}

@freezed
abstract class GithubIssueModel with _$GithubIssueModel {
  const factory GithubIssueModel({
    @JsonKey(fromJson: _idAsString) required String id,
    @JsonKey(fromJson: _idAsString) required String number,
    required String title,
    String? body,
    @Default('open') String state,
    @JsonKey(name: 'pull_request', fromJson: _isPresent)
    @Default(false)
    bool isPullRequest,
    @JsonKey(name: 'user', fromJson: _login) String? userLogin,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _GithubIssueModel;

  factory GithubIssueModel.fromJson(Map<String, dynamic> json) =>
      _$GithubIssueModelFromJson(json);
}

@freezed
abstract class GithubPullRequestModel with _$GithubPullRequestModel {
  const factory GithubPullRequestModel({
    @JsonKey(fromJson: _idAsString) required String id,
    @JsonKey(fromJson: _idAsString) required String number,
    required String title,
    String? body,
    @Default('open') String state,
    @JsonKey(name: 'user', fromJson: _login) String? userLogin,
    @JsonKey(name: 'head', fromJson: _ref) String? headBranch,
    @JsonKey(name: 'base', fromJson: _ref) String? baseBranch,
    @Default(0) int additions,
    @Default(0) int deletions,
    @JsonKey(name: 'changed_files') @Default(0) int changedFiles,
    @Default(0) int comments,
    @JsonKey(name: 'draft') @Default(false) bool isDraft,
    @JsonKey(name: 'mergeable') @Default(false) bool mergeable,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _GithubPullRequestModel;

  factory GithubPullRequestModel.fromJson(Map<String, dynamic> json) =>
      _$GithubPullRequestModelFromJson(json);
}

@freezed
abstract class GithubUserModel with _$GithubUserModel {
  const factory GithubUserModel({
    required String login,
    @JsonKey(fromJson: _idAsString) required String id,
    String? name,
    String? email,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    String? bio,
    @JsonKey(name: 'public_repos') @Default(0) int publicRepos,
    @Default(0) int followers,
    @Default(0) int following,
  }) = _GithubUserModel;

  factory GithubUserModel.fromJson(Map<String, dynamic> json) =>
      _$GithubUserModelFromJson(json);
}
