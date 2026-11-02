import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/github_repository_model.dart';

part 'github_api.g.dart';

@RestApi()
abstract class GithubApi {
  factory GithubApi(Dio dio, {String? baseUrl}) = _GithubApi;

  @GET('/user/repos')
  Future<List<GithubRepositoryModel>> listRepositories({
    @Query('per_page') int perPage = 100,
    @Query('sort') String sort = 'updated',
  });

  @GET('/repos/{owner}/{repo}')
  Future<GithubRepositoryModel> getRepository({
    @Path('owner') required String owner,
    @Path('repo') required String repo,
  });

  @GET('/repos/{owner}/{repo}/issues')
  Future<List<GithubIssueModel>> listIssues({
    @Path('owner') required String owner,
    @Path('repo') required String repo,
    @Query('state') String state = 'open',
    @Query('per_page') int perPage = 50,
  });

  @GET('/repos/{owner}/{repo}/pulls')
  Future<List<GithubPullRequestModel>> listPullRequests({
    @Path('owner') required String owner,
    @Path('repo') required String repo,
    @Query('state') String state = 'open',
  });

  @GET('/user')
  Future<GithubUserModel> getUser();
}
