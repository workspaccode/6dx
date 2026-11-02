// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'github_repository_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GithubRepositoryModel _$GithubRepositoryModelFromJson(
  Map<String, dynamic> json,
) => _GithubRepositoryModel(
  id: json['id'] as String,
  name: json['name'] as String,
  fullName: json['fullName'] as String,
  description: json['description'] as String?,
  htmlUrl: json['htmlUrl'] as String?,
  language: json['language'] as String?,
  isPrivate: json['isPrivate'] as bool? ?? false,
  isFork: json['isFork'] as bool? ?? false,
  stargazersCount: (json['stargazersCount'] as num?)?.toInt() ?? 0,
  openIssuesCount: (json['openIssuesCount'] as num?)?.toInt() ?? 0,
  defaultBranch: json['defaultBranch'] as String?,
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$GithubRepositoryModelToJson(
  _GithubRepositoryModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'fullName': instance.fullName,
  'description': instance.description,
  'htmlUrl': instance.htmlUrl,
  'language': instance.language,
  'isPrivate': instance.isPrivate,
  'isFork': instance.isFork,
  'stargazersCount': instance.stargazersCount,
  'openIssuesCount': instance.openIssuesCount,
  'defaultBranch': instance.defaultBranch,
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

_GithubIssueModel _$GithubIssueModelFromJson(Map<String, dynamic> json) =>
    _GithubIssueModel(
      id: json['id'] as String,
      number: json['number'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      state: json['state'] as String? ?? 'open',
      isPullRequest: json['isPullRequest'] as bool? ?? false,
      userLogin: json['userLogin'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$GithubIssueModelToJson(_GithubIssueModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'title': instance.title,
      'body': instance.body,
      'state': instance.state,
      'isPullRequest': instance.isPullRequest,
      'userLogin': instance.userLogin,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_GithubPullRequestModel _$GithubPullRequestModelFromJson(
  Map<String, dynamic> json,
) => _GithubPullRequestModel(
  id: json['id'] as String,
  number: json['number'] as String,
  title: json['title'] as String,
  body: json['body'] as String?,
  state: json['state'] as String? ?? 'open',
  userLogin: json['userLogin'] as String?,
  headBranch: json['headBranch'] as String?,
  baseBranch: json['baseBranch'] as String?,
  additions: (json['additions'] as num?)?.toInt() ?? 0,
  deletions: (json['deletions'] as num?)?.toInt() ?? 0,
  changedFiles: (json['changedFiles'] as num?)?.toInt() ?? 0,
  comments: (json['comments'] as num?)?.toInt() ?? 0,
  isDraft: json['isDraft'] as bool? ?? false,
  mergeable: json['mergeable'] as bool? ?? false,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$GithubPullRequestModelToJson(
  _GithubPullRequestModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'title': instance.title,
  'body': instance.body,
  'state': instance.state,
  'userLogin': instance.userLogin,
  'headBranch': instance.headBranch,
  'baseBranch': instance.baseBranch,
  'additions': instance.additions,
  'deletions': instance.deletions,
  'changedFiles': instance.changedFiles,
  'comments': instance.comments,
  'isDraft': instance.isDraft,
  'mergeable': instance.mergeable,
  'createdAt': instance.createdAt?.toIso8601String(),
};

_GithubUserModel _$GithubUserModelFromJson(Map<String, dynamic> json) =>
    _GithubUserModel(
      login: json['login'] as String,
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      publicRepos: (json['publicRepos'] as num?)?.toInt() ?? 0,
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      following: (json['following'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$GithubUserModelToJson(_GithubUserModel instance) =>
    <String, dynamic>{
      'login': instance.login,
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'avatarUrl': instance.avatarUrl,
      'bio': instance.bio,
      'publicRepos': instance.publicRepos,
      'followers': instance.followers,
      'following': instance.following,
    };
