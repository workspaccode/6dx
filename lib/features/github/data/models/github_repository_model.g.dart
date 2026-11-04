// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'github_repository_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GithubRepositoryModel _$GithubRepositoryModelFromJson(
  Map<String, dynamic> json,
) => _GithubRepositoryModel(
  id: _idAsString(json['id']),
  name: json['name'] as String,
  fullName: json['full_name'] as String,
  description: json['description'] as String?,
  htmlUrl: json['html_url'] as String?,
  language: json['language'] as String?,
  isPrivate: json['private'] as bool? ?? false,
  isFork: json['fork'] as bool? ?? false,
  stargazersCount: (json['stargazers_count'] as num?)?.toInt() ?? 0,
  openIssuesCount: (json['open_issues_count'] as num?)?.toInt() ?? 0,
  defaultBranch: json['default_branch'] as String?,
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$GithubRepositoryModelToJson(
  _GithubRepositoryModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'full_name': instance.fullName,
  'description': instance.description,
  'html_url': instance.htmlUrl,
  'language': instance.language,
  'private': instance.isPrivate,
  'fork': instance.isFork,
  'stargazers_count': instance.stargazersCount,
  'open_issues_count': instance.openIssuesCount,
  'default_branch': instance.defaultBranch,
  'updated_at': instance.updatedAt?.toIso8601String(),
};

_GithubIssueModel _$GithubIssueModelFromJson(Map<String, dynamic> json) =>
    _GithubIssueModel(
      id: _idAsString(json['id']),
      number: _idAsString(json['number']),
      title: json['title'] as String,
      body: json['body'] as String?,
      state: json['state'] as String? ?? 'open',
      isPullRequest: json['pull_request'] == null
          ? false
          : _isPresent(json['pull_request']),
      userLogin: _login(json['user']),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$GithubIssueModelToJson(_GithubIssueModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'title': instance.title,
      'body': instance.body,
      'state': instance.state,
      'pull_request': instance.isPullRequest,
      'user': instance.userLogin,
      'created_at': instance.createdAt?.toIso8601String(),
    };

_GithubPullRequestModel _$GithubPullRequestModelFromJson(
  Map<String, dynamic> json,
) => _GithubPullRequestModel(
  id: _idAsString(json['id']),
  number: _idAsString(json['number']),
  title: json['title'] as String,
  body: json['body'] as String?,
  state: json['state'] as String? ?? 'open',
  userLogin: _login(json['user']),
  headBranch: _ref(json['head']),
  baseBranch: _ref(json['base']),
  additions: (json['additions'] as num?)?.toInt() ?? 0,
  deletions: (json['deletions'] as num?)?.toInt() ?? 0,
  changedFiles: (json['changed_files'] as num?)?.toInt() ?? 0,
  comments: (json['comments'] as num?)?.toInt() ?? 0,
  isDraft: json['draft'] as bool? ?? false,
  mergeable: json['mergeable'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$GithubPullRequestModelToJson(
  _GithubPullRequestModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'title': instance.title,
  'body': instance.body,
  'state': instance.state,
  'user': instance.userLogin,
  'head': instance.headBranch,
  'base': instance.baseBranch,
  'additions': instance.additions,
  'deletions': instance.deletions,
  'changed_files': instance.changedFiles,
  'comments': instance.comments,
  'draft': instance.isDraft,
  'mergeable': instance.mergeable,
  'created_at': instance.createdAt?.toIso8601String(),
};

_GithubUserModel _$GithubUserModelFromJson(Map<String, dynamic> json) =>
    _GithubUserModel(
      login: json['login'] as String,
      id: _idAsString(json['id']),
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      publicRepos: (json['public_repos'] as num?)?.toInt() ?? 0,
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      following: (json['following'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$GithubUserModelToJson(_GithubUserModel instance) =>
    <String, dynamic>{
      'login': instance.login,
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'avatar_url': instance.avatarUrl,
      'bio': instance.bio,
      'public_repos': instance.publicRepos,
      'followers': instance.followers,
      'following': instance.following,
    };
