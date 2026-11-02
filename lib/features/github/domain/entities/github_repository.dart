import 'package:freezed_annotation/freezed_annotation.dart';

part 'github_repository.freezed.dart';

@freezed
abstract class GithubRepository with _$GithubRepository {
  const GithubRepository._();

  const factory GithubRepository({
    required String id,
    required String name,
    required String fullName,
    String? description,
    String? htmlUrl,
    String? language,
    @Default(false) bool isPrivate,
    @Default(0) int stargazersCount,
    @Default(0) int openIssuesCount,
    String? defaultBranch,
  }) = _GithubRepository;

  String get owner => fullName.split('/').first;
  String get repo => fullName.split('/').last;
}
