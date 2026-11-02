import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/github_repository.dart';

part 'github_repository_model.freezed.dart';
part 'github_repository_model.g.dart';

@freezed
abstract class GithubRepositoryModel with _$GithubRepositoryModel {
  const GithubRepositoryModel._();

  const factory GithubRepositoryModel({
    required String id,
    required String name,
    required String fullName,
    String? description,
    String? htmlUrl,
    String? language,
    @Default(false) bool isPrivate,
    @Default(false) bool isFork,
    @Default(0) int stargazersCount,
    @Default(0) int openIssuesCount,
    String? defaultBranch,
    DateTime? updatedAt,
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
    required String id,
    required String number,
    required String title,
    String? body,
    @Default('open') String state,
    @Default(false) bool isPullRequest,
    String? userLogin,
    DateTime? createdAt,
  }) = _GithubIssueModel;

  factory GithubIssueModel.fromJson(Map<String, dynamic> json) =>
      _$GithubIssueModelFromJson(json);
}

@freezed
abstract class GithubPullRequestModel with _$GithubPullRequestModel {
  const factory GithubPullRequestModel({
    required String id,
    required String number,
    required String title,
    String? body,
    @Default('open') String state,
    String? userLogin,
    String? headBranch,
    String? baseBranch,
    @Default(0) int additions,
    @Default(0) int deletions,
    @Default(0) int changedFiles,
    @Default(0) int comments,
    @Default(false) bool isDraft,
    @Default(false) bool mergeable,
    DateTime? createdAt,
  }) = _GithubPullRequestModel;

  factory GithubPullRequestModel.fromJson(Map<String, dynamic> json) =>
      _$GithubPullRequestModelFromJson(json);
}

@freezed
abstract class GithubUserModel with _$GithubUserModel {
  const factory GithubUserModel({
    required String login,
    required String id,
    String? name,
    String? email,
    String? avatarUrl,
    String? bio,
    @Default(0) int publicRepos,
    @Default(0) int followers,
    @Default(0) int following,
  }) = _GithubUserModel;

  factory GithubUserModel.fromJson(Map<String, dynamic> json) =>
      _$GithubUserModelFromJson(json);
}
