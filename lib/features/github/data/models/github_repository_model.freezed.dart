// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'github_repository_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GithubRepositoryModel {

@JsonKey(fromJson: _idAsString) String get id; String get name;@JsonKey(name: 'full_name') String get fullName; String? get description;@JsonKey(name: 'html_url') String? get htmlUrl; String? get language;@JsonKey(name: 'private') bool get isPrivate;@JsonKey(name: 'fork') bool get isFork;@JsonKey(name: 'stargazers_count') int get stargazersCount;@JsonKey(name: 'open_issues_count') int get openIssuesCount;@JsonKey(name: 'default_branch') String? get defaultBranch;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of GithubRepositoryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GithubRepositoryModelCopyWith<GithubRepositoryModel> get copyWith => _$GithubRepositoryModelCopyWithImpl<GithubRepositoryModel>(this as GithubRepositoryModel, _$identity);

  /// Serializes this GithubRepositoryModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GithubRepositoryModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GithubRepositoryModel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.fullName, _this.fullName) || other.fullName == _this.fullName)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.htmlUrl, _this.htmlUrl) || other.htmlUrl == _this.htmlUrl)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.isPrivate, _this.isPrivate) || other.isPrivate == _this.isPrivate)&&(identical(other.isFork, _this.isFork) || other.isFork == _this.isFork)&&(identical(other.stargazersCount, _this.stargazersCount) || other.stargazersCount == _this.stargazersCount)&&(identical(other.openIssuesCount, _this.openIssuesCount) || other.openIssuesCount == _this.openIssuesCount)&&(identical(other.defaultBranch, _this.defaultBranch) || other.defaultBranch == _this.defaultBranch)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GithubRepositoryModel;
  return Object.hash(runtimeType,_this.id,_this.name,_this.fullName,_this.description,_this.htmlUrl,_this.language,_this.isPrivate,_this.isFork,_this.stargazersCount,_this.openIssuesCount,_this.defaultBranch,_this.updatedAt);
}

@override
String toString() {
  final _this = this as GithubRepositoryModel;
  return 'GithubRepositoryModel(id: ${_this.id}, name: ${_this.name}, fullName: ${_this.fullName}, description: ${_this.description}, htmlUrl: ${_this.htmlUrl}, language: ${_this.language}, isPrivate: ${_this.isPrivate}, isFork: ${_this.isFork}, stargazersCount: ${_this.stargazersCount}, openIssuesCount: ${_this.openIssuesCount}, defaultBranch: ${_this.defaultBranch}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $GithubRepositoryModelCopyWith<$Res>  {
  factory $GithubRepositoryModelCopyWith(GithubRepositoryModel value, $Res Function(GithubRepositoryModel) _then) = _$GithubRepositoryModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _idAsString) String id, String name,@JsonKey(name: 'full_name') String fullName, String? description,@JsonKey(name: 'html_url') String? htmlUrl, String? language,@JsonKey(name: 'private') bool isPrivate,@JsonKey(name: 'fork') bool isFork,@JsonKey(name: 'stargazers_count') int stargazersCount,@JsonKey(name: 'open_issues_count') int openIssuesCount,@JsonKey(name: 'default_branch') String? defaultBranch,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$GithubRepositoryModelCopyWithImpl<$Res>
    implements $GithubRepositoryModelCopyWith<$Res> {
  _$GithubRepositoryModelCopyWithImpl(this._self, this._then);

  final GithubRepositoryModel _self;
  final $Res Function(GithubRepositoryModel) _then;

/// Create a copy of GithubRepositoryModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? fullName = null,Object? description = freezed,Object? htmlUrl = freezed,Object? language = freezed,Object? isPrivate = null,Object? isFork = null,Object? stargazersCount = null,Object? openIssuesCount = null,Object? defaultBranch = freezed,Object? updatedAt = freezed,}) {
  return _then(GithubRepositoryModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,htmlUrl: freezed == htmlUrl ? _self.htmlUrl : htmlUrl // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,isFork: null == isFork ? _self.isFork : isFork // ignore: cast_nullable_to_non_nullable
as bool,stargazersCount: null == stargazersCount ? _self.stargazersCount : stargazersCount // ignore: cast_nullable_to_non_nullable
as int,openIssuesCount: null == openIssuesCount ? _self.openIssuesCount : openIssuesCount // ignore: cast_nullable_to_non_nullable
as int,defaultBranch: freezed == defaultBranch ? _self.defaultBranch : defaultBranch // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [GithubRepositoryModel].
extension GithubRepositoryModelPatterns on GithubRepositoryModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GithubRepositoryModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GithubRepositoryModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GithubRepositoryModel value)  $default,){
final _that = this;
switch (_that) {
case _GithubRepositoryModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GithubRepositoryModel value)?  $default,){
final _that = this;
switch (_that) {
case _GithubRepositoryModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _idAsString)  String id,  String name, @JsonKey(name: 'full_name')  String fullName,  String? description, @JsonKey(name: 'html_url')  String? htmlUrl,  String? language, @JsonKey(name: 'private')  bool isPrivate, @JsonKey(name: 'fork')  bool isFork, @JsonKey(name: 'stargazers_count')  int stargazersCount, @JsonKey(name: 'open_issues_count')  int openIssuesCount, @JsonKey(name: 'default_branch')  String? defaultBranch, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GithubRepositoryModel() when $default != null:
return $default(_that.id,_that.name,_that.fullName,_that.description,_that.htmlUrl,_that.language,_that.isPrivate,_that.isFork,_that.stargazersCount,_that.openIssuesCount,_that.defaultBranch,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _idAsString)  String id,  String name, @JsonKey(name: 'full_name')  String fullName,  String? description, @JsonKey(name: 'html_url')  String? htmlUrl,  String? language, @JsonKey(name: 'private')  bool isPrivate, @JsonKey(name: 'fork')  bool isFork, @JsonKey(name: 'stargazers_count')  int stargazersCount, @JsonKey(name: 'open_issues_count')  int openIssuesCount, @JsonKey(name: 'default_branch')  String? defaultBranch, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _GithubRepositoryModel():
return $default(_that.id,_that.name,_that.fullName,_that.description,_that.htmlUrl,_that.language,_that.isPrivate,_that.isFork,_that.stargazersCount,_that.openIssuesCount,_that.defaultBranch,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _idAsString)  String id,  String name, @JsonKey(name: 'full_name')  String fullName,  String? description, @JsonKey(name: 'html_url')  String? htmlUrl,  String? language, @JsonKey(name: 'private')  bool isPrivate, @JsonKey(name: 'fork')  bool isFork, @JsonKey(name: 'stargazers_count')  int stargazersCount, @JsonKey(name: 'open_issues_count')  int openIssuesCount, @JsonKey(name: 'default_branch')  String? defaultBranch, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _GithubRepositoryModel() when $default != null:
return $default(_that.id,_that.name,_that.fullName,_that.description,_that.htmlUrl,_that.language,_that.isPrivate,_that.isFork,_that.stargazersCount,_that.openIssuesCount,_that.defaultBranch,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GithubRepositoryModel extends GithubRepositoryModel {
  const _GithubRepositoryModel({@JsonKey(fromJson: _idAsString) required this.id, required this.name, @JsonKey(name: 'full_name') required this.fullName, this.description, @JsonKey(name: 'html_url') this.htmlUrl, this.language, @JsonKey(name: 'private') this.isPrivate = false, @JsonKey(name: 'fork') this.isFork = false, @JsonKey(name: 'stargazers_count') this.stargazersCount = 0, @JsonKey(name: 'open_issues_count') this.openIssuesCount = 0, @JsonKey(name: 'default_branch') this.defaultBranch, @JsonKey(name: 'updated_at') this.updatedAt}): super._();
  factory _GithubRepositoryModel.fromJson(Map<String, dynamic> json) => _$GithubRepositoryModelFromJson(json);

@override@JsonKey(fromJson: _idAsString) final  String id;
@override final  String name;
@override@JsonKey(name: 'full_name') final  String fullName;
@override final  String? description;
@override@JsonKey(name: 'html_url') final  String? htmlUrl;
@override final  String? language;
@override@JsonKey(name: 'private') final  bool isPrivate;
@override@JsonKey(name: 'fork') final  bool isFork;
@override@JsonKey(name: 'stargazers_count') final  int stargazersCount;
@override@JsonKey(name: 'open_issues_count') final  int openIssuesCount;
@override@JsonKey(name: 'default_branch') final  String? defaultBranch;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of GithubRepositoryModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GithubRepositoryModelCopyWith<_GithubRepositoryModel> get copyWith => __$GithubRepositoryModelCopyWithImpl<_GithubRepositoryModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GithubRepositoryModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GithubRepositoryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.description, description) || other.description == description)&&(identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl)&&(identical(other.language, language) || other.language == language)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.isFork, isFork) || other.isFork == isFork)&&(identical(other.stargazersCount, stargazersCount) || other.stargazersCount == stargazersCount)&&(identical(other.openIssuesCount, openIssuesCount) || other.openIssuesCount == openIssuesCount)&&(identical(other.defaultBranch, defaultBranch) || other.defaultBranch == defaultBranch)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,fullName,description,htmlUrl,language,isPrivate,isFork,stargazersCount,openIssuesCount,defaultBranch,updatedAt);
}

@override
String toString() {
    return 'GithubRepositoryModel(id: $id, name: $name, fullName: $fullName, description: $description, htmlUrl: $htmlUrl, language: $language, isPrivate: $isPrivate, isFork: $isFork, stargazersCount: $stargazersCount, openIssuesCount: $openIssuesCount, defaultBranch: $defaultBranch, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$GithubRepositoryModelCopyWith<$Res> implements $GithubRepositoryModelCopyWith<$Res> {
  factory _$GithubRepositoryModelCopyWith(_GithubRepositoryModel value, $Res Function(_GithubRepositoryModel) _then) = __$GithubRepositoryModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _idAsString) String id, String name,@JsonKey(name: 'full_name') String fullName, String? description,@JsonKey(name: 'html_url') String? htmlUrl, String? language,@JsonKey(name: 'private') bool isPrivate,@JsonKey(name: 'fork') bool isFork,@JsonKey(name: 'stargazers_count') int stargazersCount,@JsonKey(name: 'open_issues_count') int openIssuesCount,@JsonKey(name: 'default_branch') String? defaultBranch,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$GithubRepositoryModelCopyWithImpl<$Res>
    implements _$GithubRepositoryModelCopyWith<$Res> {
  __$GithubRepositoryModelCopyWithImpl(this._self, this._then);

  final _GithubRepositoryModel _self;
  final $Res Function(_GithubRepositoryModel) _then;

/// Create a copy of GithubRepositoryModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? fullName = null,Object? description = freezed,Object? htmlUrl = freezed,Object? language = freezed,Object? isPrivate = null,Object? isFork = null,Object? stargazersCount = null,Object? openIssuesCount = null,Object? defaultBranch = freezed,Object? updatedAt = freezed,}) {
  return _then(_GithubRepositoryModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,htmlUrl: freezed == htmlUrl ? _self.htmlUrl : htmlUrl // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,isFork: null == isFork ? _self.isFork : isFork // ignore: cast_nullable_to_non_nullable
as bool,stargazersCount: null == stargazersCount ? _self.stargazersCount : stargazersCount // ignore: cast_nullable_to_non_nullable
as int,openIssuesCount: null == openIssuesCount ? _self.openIssuesCount : openIssuesCount // ignore: cast_nullable_to_non_nullable
as int,defaultBranch: freezed == defaultBranch ? _self.defaultBranch : defaultBranch // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$GithubIssueModel {

@JsonKey(fromJson: _idAsString) String get id;@JsonKey(fromJson: _idAsString) String get number; String get title; String? get body; String get state;@JsonKey(name: 'pull_request', fromJson: _isPresent) bool get isPullRequest;@JsonKey(name: 'user', fromJson: _login) String? get userLogin;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of GithubIssueModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GithubIssueModelCopyWith<GithubIssueModel> get copyWith => _$GithubIssueModelCopyWithImpl<GithubIssueModel>(this as GithubIssueModel, _$identity);

  /// Serializes this GithubIssueModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GithubIssueModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GithubIssueModel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.body, _this.body) || other.body == _this.body)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.isPullRequest, _this.isPullRequest) || other.isPullRequest == _this.isPullRequest)&&(identical(other.userLogin, _this.userLogin) || other.userLogin == _this.userLogin)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GithubIssueModel;
  return Object.hash(runtimeType,_this.id,_this.number,_this.title,_this.body,_this.state,_this.isPullRequest,_this.userLogin,_this.createdAt);
}

@override
String toString() {
  final _this = this as GithubIssueModel;
  return 'GithubIssueModel(id: ${_this.id}, number: ${_this.number}, title: ${_this.title}, body: ${_this.body}, state: ${_this.state}, isPullRequest: ${_this.isPullRequest}, userLogin: ${_this.userLogin}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $GithubIssueModelCopyWith<$Res>  {
  factory $GithubIssueModelCopyWith(GithubIssueModel value, $Res Function(GithubIssueModel) _then) = _$GithubIssueModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _idAsString) String id,@JsonKey(fromJson: _idAsString) String number, String title, String? body, String state,@JsonKey(name: 'pull_request', fromJson: _isPresent) bool isPullRequest,@JsonKey(name: 'user', fromJson: _login) String? userLogin,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$GithubIssueModelCopyWithImpl<$Res>
    implements $GithubIssueModelCopyWith<$Res> {
  _$GithubIssueModelCopyWithImpl(this._self, this._then);

  final GithubIssueModel _self;
  final $Res Function(GithubIssueModel) _then;

/// Create a copy of GithubIssueModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? title = null,Object? body = freezed,Object? state = null,Object? isPullRequest = null,Object? userLogin = freezed,Object? createdAt = freezed,}) {
  return _then(GithubIssueModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,isPullRequest: null == isPullRequest ? _self.isPullRequest : isPullRequest // ignore: cast_nullable_to_non_nullable
as bool,userLogin: freezed == userLogin ? _self.userLogin : userLogin // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [GithubIssueModel].
extension GithubIssueModelPatterns on GithubIssueModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GithubIssueModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GithubIssueModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GithubIssueModel value)  $default,){
final _that = this;
switch (_that) {
case _GithubIssueModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GithubIssueModel value)?  $default,){
final _that = this;
switch (_that) {
case _GithubIssueModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _idAsString)  String id, @JsonKey(fromJson: _idAsString)  String number,  String title,  String? body,  String state, @JsonKey(name: 'pull_request', fromJson: _isPresent)  bool isPullRequest, @JsonKey(name: 'user', fromJson: _login)  String? userLogin, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GithubIssueModel() when $default != null:
return $default(_that.id,_that.number,_that.title,_that.body,_that.state,_that.isPullRequest,_that.userLogin,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _idAsString)  String id, @JsonKey(fromJson: _idAsString)  String number,  String title,  String? body,  String state, @JsonKey(name: 'pull_request', fromJson: _isPresent)  bool isPullRequest, @JsonKey(name: 'user', fromJson: _login)  String? userLogin, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _GithubIssueModel():
return $default(_that.id,_that.number,_that.title,_that.body,_that.state,_that.isPullRequest,_that.userLogin,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _idAsString)  String id, @JsonKey(fromJson: _idAsString)  String number,  String title,  String? body,  String state, @JsonKey(name: 'pull_request', fromJson: _isPresent)  bool isPullRequest, @JsonKey(name: 'user', fromJson: _login)  String? userLogin, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _GithubIssueModel() when $default != null:
return $default(_that.id,_that.number,_that.title,_that.body,_that.state,_that.isPullRequest,_that.userLogin,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GithubIssueModel implements GithubIssueModel {
  const _GithubIssueModel({@JsonKey(fromJson: _idAsString) required this.id, @JsonKey(fromJson: _idAsString) required this.number, required this.title, this.body, this.state = 'open', @JsonKey(name: 'pull_request', fromJson: _isPresent) this.isPullRequest = false, @JsonKey(name: 'user', fromJson: _login) this.userLogin, @JsonKey(name: 'created_at') this.createdAt});
  factory _GithubIssueModel.fromJson(Map<String, dynamic> json) => _$GithubIssueModelFromJson(json);

@override@JsonKey(fromJson: _idAsString) final  String id;
@override@JsonKey(fromJson: _idAsString) final  String number;
@override final  String title;
@override final  String? body;
@override@JsonKey() final  String state;
@override@JsonKey(name: 'pull_request', fromJson: _isPresent) final  bool isPullRequest;
@override@JsonKey(name: 'user', fromJson: _login) final  String? userLogin;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of GithubIssueModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GithubIssueModelCopyWith<_GithubIssueModel> get copyWith => __$GithubIssueModelCopyWithImpl<_GithubIssueModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GithubIssueModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GithubIssueModel&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.state, state) || other.state == state)&&(identical(other.isPullRequest, isPullRequest) || other.isPullRequest == isPullRequest)&&(identical(other.userLogin, userLogin) || other.userLogin == userLogin)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,number,title,body,state,isPullRequest,userLogin,createdAt);
}

@override
String toString() {
    return 'GithubIssueModel(id: $id, number: $number, title: $title, body: $body, state: $state, isPullRequest: $isPullRequest, userLogin: $userLogin, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$GithubIssueModelCopyWith<$Res> implements $GithubIssueModelCopyWith<$Res> {
  factory _$GithubIssueModelCopyWith(_GithubIssueModel value, $Res Function(_GithubIssueModel) _then) = __$GithubIssueModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _idAsString) String id,@JsonKey(fromJson: _idAsString) String number, String title, String? body, String state,@JsonKey(name: 'pull_request', fromJson: _isPresent) bool isPullRequest,@JsonKey(name: 'user', fromJson: _login) String? userLogin,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$GithubIssueModelCopyWithImpl<$Res>
    implements _$GithubIssueModelCopyWith<$Res> {
  __$GithubIssueModelCopyWithImpl(this._self, this._then);

  final _GithubIssueModel _self;
  final $Res Function(_GithubIssueModel) _then;

/// Create a copy of GithubIssueModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? title = null,Object? body = freezed,Object? state = null,Object? isPullRequest = null,Object? userLogin = freezed,Object? createdAt = freezed,}) {
  return _then(_GithubIssueModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,isPullRequest: null == isPullRequest ? _self.isPullRequest : isPullRequest // ignore: cast_nullable_to_non_nullable
as bool,userLogin: freezed == userLogin ? _self.userLogin : userLogin // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$GithubPullRequestModel {

@JsonKey(fromJson: _idAsString) String get id;@JsonKey(fromJson: _idAsString) String get number; String get title; String? get body; String get state;@JsonKey(name: 'user', fromJson: _login) String? get userLogin;@JsonKey(name: 'head', fromJson: _ref) String? get headBranch;@JsonKey(name: 'base', fromJson: _ref) String? get baseBranch; int get additions; int get deletions;@JsonKey(name: 'changed_files') int get changedFiles; int get comments;@JsonKey(name: 'draft') bool get isDraft;@JsonKey(name: 'mergeable') bool get mergeable;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of GithubPullRequestModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GithubPullRequestModelCopyWith<GithubPullRequestModel> get copyWith => _$GithubPullRequestModelCopyWithImpl<GithubPullRequestModel>(this as GithubPullRequestModel, _$identity);

  /// Serializes this GithubPullRequestModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GithubPullRequestModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GithubPullRequestModel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.body, _this.body) || other.body == _this.body)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.userLogin, _this.userLogin) || other.userLogin == _this.userLogin)&&(identical(other.headBranch, _this.headBranch) || other.headBranch == _this.headBranch)&&(identical(other.baseBranch, _this.baseBranch) || other.baseBranch == _this.baseBranch)&&(identical(other.additions, _this.additions) || other.additions == _this.additions)&&(identical(other.deletions, _this.deletions) || other.deletions == _this.deletions)&&(identical(other.changedFiles, _this.changedFiles) || other.changedFiles == _this.changedFiles)&&(identical(other.comments, _this.comments) || other.comments == _this.comments)&&(identical(other.isDraft, _this.isDraft) || other.isDraft == _this.isDraft)&&(identical(other.mergeable, _this.mergeable) || other.mergeable == _this.mergeable)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GithubPullRequestModel;
  return Object.hash(runtimeType,_this.id,_this.number,_this.title,_this.body,_this.state,_this.userLogin,_this.headBranch,_this.baseBranch,_this.additions,_this.deletions,_this.changedFiles,_this.comments,_this.isDraft,_this.mergeable,_this.createdAt);
}

@override
String toString() {
  final _this = this as GithubPullRequestModel;
  return 'GithubPullRequestModel(id: ${_this.id}, number: ${_this.number}, title: ${_this.title}, body: ${_this.body}, state: ${_this.state}, userLogin: ${_this.userLogin}, headBranch: ${_this.headBranch}, baseBranch: ${_this.baseBranch}, additions: ${_this.additions}, deletions: ${_this.deletions}, changedFiles: ${_this.changedFiles}, comments: ${_this.comments}, isDraft: ${_this.isDraft}, mergeable: ${_this.mergeable}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $GithubPullRequestModelCopyWith<$Res>  {
  factory $GithubPullRequestModelCopyWith(GithubPullRequestModel value, $Res Function(GithubPullRequestModel) _then) = _$GithubPullRequestModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _idAsString) String id,@JsonKey(fromJson: _idAsString) String number, String title, String? body, String state,@JsonKey(name: 'user', fromJson: _login) String? userLogin,@JsonKey(name: 'head', fromJson: _ref) String? headBranch,@JsonKey(name: 'base', fromJson: _ref) String? baseBranch, int additions, int deletions,@JsonKey(name: 'changed_files') int changedFiles, int comments,@JsonKey(name: 'draft') bool isDraft,@JsonKey(name: 'mergeable') bool mergeable,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$GithubPullRequestModelCopyWithImpl<$Res>
    implements $GithubPullRequestModelCopyWith<$Res> {
  _$GithubPullRequestModelCopyWithImpl(this._self, this._then);

  final GithubPullRequestModel _self;
  final $Res Function(GithubPullRequestModel) _then;

/// Create a copy of GithubPullRequestModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? title = null,Object? body = freezed,Object? state = null,Object? userLogin = freezed,Object? headBranch = freezed,Object? baseBranch = freezed,Object? additions = null,Object? deletions = null,Object? changedFiles = null,Object? comments = null,Object? isDraft = null,Object? mergeable = null,Object? createdAt = freezed,}) {
  return _then(GithubPullRequestModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,userLogin: freezed == userLogin ? _self.userLogin : userLogin // ignore: cast_nullable_to_non_nullable
as String?,headBranch: freezed == headBranch ? _self.headBranch : headBranch // ignore: cast_nullable_to_non_nullable
as String?,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,changedFiles: null == changedFiles ? _self.changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as int,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as int,isDraft: null == isDraft ? _self.isDraft : isDraft // ignore: cast_nullable_to_non_nullable
as bool,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [GithubPullRequestModel].
extension GithubPullRequestModelPatterns on GithubPullRequestModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GithubPullRequestModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GithubPullRequestModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GithubPullRequestModel value)  $default,){
final _that = this;
switch (_that) {
case _GithubPullRequestModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GithubPullRequestModel value)?  $default,){
final _that = this;
switch (_that) {
case _GithubPullRequestModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _idAsString)  String id, @JsonKey(fromJson: _idAsString)  String number,  String title,  String? body,  String state, @JsonKey(name: 'user', fromJson: _login)  String? userLogin, @JsonKey(name: 'head', fromJson: _ref)  String? headBranch, @JsonKey(name: 'base', fromJson: _ref)  String? baseBranch,  int additions,  int deletions, @JsonKey(name: 'changed_files')  int changedFiles,  int comments, @JsonKey(name: 'draft')  bool isDraft, @JsonKey(name: 'mergeable')  bool mergeable, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GithubPullRequestModel() when $default != null:
return $default(_that.id,_that.number,_that.title,_that.body,_that.state,_that.userLogin,_that.headBranch,_that.baseBranch,_that.additions,_that.deletions,_that.changedFiles,_that.comments,_that.isDraft,_that.mergeable,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _idAsString)  String id, @JsonKey(fromJson: _idAsString)  String number,  String title,  String? body,  String state, @JsonKey(name: 'user', fromJson: _login)  String? userLogin, @JsonKey(name: 'head', fromJson: _ref)  String? headBranch, @JsonKey(name: 'base', fromJson: _ref)  String? baseBranch,  int additions,  int deletions, @JsonKey(name: 'changed_files')  int changedFiles,  int comments, @JsonKey(name: 'draft')  bool isDraft, @JsonKey(name: 'mergeable')  bool mergeable, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _GithubPullRequestModel():
return $default(_that.id,_that.number,_that.title,_that.body,_that.state,_that.userLogin,_that.headBranch,_that.baseBranch,_that.additions,_that.deletions,_that.changedFiles,_that.comments,_that.isDraft,_that.mergeable,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _idAsString)  String id, @JsonKey(fromJson: _idAsString)  String number,  String title,  String? body,  String state, @JsonKey(name: 'user', fromJson: _login)  String? userLogin, @JsonKey(name: 'head', fromJson: _ref)  String? headBranch, @JsonKey(name: 'base', fromJson: _ref)  String? baseBranch,  int additions,  int deletions, @JsonKey(name: 'changed_files')  int changedFiles,  int comments, @JsonKey(name: 'draft')  bool isDraft, @JsonKey(name: 'mergeable')  bool mergeable, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _GithubPullRequestModel() when $default != null:
return $default(_that.id,_that.number,_that.title,_that.body,_that.state,_that.userLogin,_that.headBranch,_that.baseBranch,_that.additions,_that.deletions,_that.changedFiles,_that.comments,_that.isDraft,_that.mergeable,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GithubPullRequestModel implements GithubPullRequestModel {
  const _GithubPullRequestModel({@JsonKey(fromJson: _idAsString) required this.id, @JsonKey(fromJson: _idAsString) required this.number, required this.title, this.body, this.state = 'open', @JsonKey(name: 'user', fromJson: _login) this.userLogin, @JsonKey(name: 'head', fromJson: _ref) this.headBranch, @JsonKey(name: 'base', fromJson: _ref) this.baseBranch, this.additions = 0, this.deletions = 0, @JsonKey(name: 'changed_files') this.changedFiles = 0, this.comments = 0, @JsonKey(name: 'draft') this.isDraft = false, @JsonKey(name: 'mergeable') this.mergeable = false, @JsonKey(name: 'created_at') this.createdAt});
  factory _GithubPullRequestModel.fromJson(Map<String, dynamic> json) => _$GithubPullRequestModelFromJson(json);

@override@JsonKey(fromJson: _idAsString) final  String id;
@override@JsonKey(fromJson: _idAsString) final  String number;
@override final  String title;
@override final  String? body;
@override@JsonKey() final  String state;
@override@JsonKey(name: 'user', fromJson: _login) final  String? userLogin;
@override@JsonKey(name: 'head', fromJson: _ref) final  String? headBranch;
@override@JsonKey(name: 'base', fromJson: _ref) final  String? baseBranch;
@override@JsonKey() final  int additions;
@override@JsonKey() final  int deletions;
@override@JsonKey(name: 'changed_files') final  int changedFiles;
@override@JsonKey() final  int comments;
@override@JsonKey(name: 'draft') final  bool isDraft;
@override@JsonKey(name: 'mergeable') final  bool mergeable;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of GithubPullRequestModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GithubPullRequestModelCopyWith<_GithubPullRequestModel> get copyWith => __$GithubPullRequestModelCopyWithImpl<_GithubPullRequestModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GithubPullRequestModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GithubPullRequestModel&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.state, state) || other.state == state)&&(identical(other.userLogin, userLogin) || other.userLogin == userLogin)&&(identical(other.headBranch, headBranch) || other.headBranch == headBranch)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.changedFiles, changedFiles) || other.changedFiles == changedFiles)&&(identical(other.comments, comments) || other.comments == comments)&&(identical(other.isDraft, isDraft) || other.isDraft == isDraft)&&(identical(other.mergeable, mergeable) || other.mergeable == mergeable)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,number,title,body,state,userLogin,headBranch,baseBranch,additions,deletions,changedFiles,comments,isDraft,mergeable,createdAt);
}

@override
String toString() {
    return 'GithubPullRequestModel(id: $id, number: $number, title: $title, body: $body, state: $state, userLogin: $userLogin, headBranch: $headBranch, baseBranch: $baseBranch, additions: $additions, deletions: $deletions, changedFiles: $changedFiles, comments: $comments, isDraft: $isDraft, mergeable: $mergeable, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$GithubPullRequestModelCopyWith<$Res> implements $GithubPullRequestModelCopyWith<$Res> {
  factory _$GithubPullRequestModelCopyWith(_GithubPullRequestModel value, $Res Function(_GithubPullRequestModel) _then) = __$GithubPullRequestModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _idAsString) String id,@JsonKey(fromJson: _idAsString) String number, String title, String? body, String state,@JsonKey(name: 'user', fromJson: _login) String? userLogin,@JsonKey(name: 'head', fromJson: _ref) String? headBranch,@JsonKey(name: 'base', fromJson: _ref) String? baseBranch, int additions, int deletions,@JsonKey(name: 'changed_files') int changedFiles, int comments,@JsonKey(name: 'draft') bool isDraft,@JsonKey(name: 'mergeable') bool mergeable,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$GithubPullRequestModelCopyWithImpl<$Res>
    implements _$GithubPullRequestModelCopyWith<$Res> {
  __$GithubPullRequestModelCopyWithImpl(this._self, this._then);

  final _GithubPullRequestModel _self;
  final $Res Function(_GithubPullRequestModel) _then;

/// Create a copy of GithubPullRequestModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? title = null,Object? body = freezed,Object? state = null,Object? userLogin = freezed,Object? headBranch = freezed,Object? baseBranch = freezed,Object? additions = null,Object? deletions = null,Object? changedFiles = null,Object? comments = null,Object? isDraft = null,Object? mergeable = null,Object? createdAt = freezed,}) {
  return _then(_GithubPullRequestModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,userLogin: freezed == userLogin ? _self.userLogin : userLogin // ignore: cast_nullable_to_non_nullable
as String?,headBranch: freezed == headBranch ? _self.headBranch : headBranch // ignore: cast_nullable_to_non_nullable
as String?,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,changedFiles: null == changedFiles ? _self.changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as int,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as int,isDraft: null == isDraft ? _self.isDraft : isDraft // ignore: cast_nullable_to_non_nullable
as bool,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$GithubUserModel {

 String get login;@JsonKey(fromJson: _idAsString) String get id; String? get name; String? get email;@JsonKey(name: 'avatar_url') String? get avatarUrl; String? get bio;@JsonKey(name: 'public_repos') int get publicRepos; int get followers; int get following;
/// Create a copy of GithubUserModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GithubUserModelCopyWith<GithubUserModel> get copyWith => _$GithubUserModelCopyWithImpl<GithubUserModel>(this as GithubUserModel, _$identity);

  /// Serializes this GithubUserModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GithubUserModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GithubUserModel&&(identical(other.login, _this.login) || other.login == _this.login)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.bio, _this.bio) || other.bio == _this.bio)&&(identical(other.publicRepos, _this.publicRepos) || other.publicRepos == _this.publicRepos)&&(identical(other.followers, _this.followers) || other.followers == _this.followers)&&(identical(other.following, _this.following) || other.following == _this.following));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GithubUserModel;
  return Object.hash(runtimeType,_this.login,_this.id,_this.name,_this.email,_this.avatarUrl,_this.bio,_this.publicRepos,_this.followers,_this.following);
}

@override
String toString() {
  final _this = this as GithubUserModel;
  return 'GithubUserModel(login: ${_this.login}, id: ${_this.id}, name: ${_this.name}, email: ${_this.email}, avatarUrl: ${_this.avatarUrl}, bio: ${_this.bio}, publicRepos: ${_this.publicRepos}, followers: ${_this.followers}, following: ${_this.following})';
}


}

/// @nodoc
abstract mixin class $GithubUserModelCopyWith<$Res>  {
  factory $GithubUserModelCopyWith(GithubUserModel value, $Res Function(GithubUserModel) _then) = _$GithubUserModelCopyWithImpl;
@useResult
$Res call({
 String login,@JsonKey(fromJson: _idAsString) String id, String? name, String? email,@JsonKey(name: 'avatar_url') String? avatarUrl, String? bio,@JsonKey(name: 'public_repos') int publicRepos, int followers, int following
});




}
/// @nodoc
class _$GithubUserModelCopyWithImpl<$Res>
    implements $GithubUserModelCopyWith<$Res> {
  _$GithubUserModelCopyWithImpl(this._self, this._then);

  final GithubUserModel _self;
  final $Res Function(GithubUserModel) _then;

/// Create a copy of GithubUserModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? login = null,Object? id = null,Object? name = freezed,Object? email = freezed,Object? avatarUrl = freezed,Object? bio = freezed,Object? publicRepos = null,Object? followers = null,Object? following = null,}) {
  return _then(GithubUserModel(
login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,publicRepos: null == publicRepos ? _self.publicRepos : publicRepos // ignore: cast_nullable_to_non_nullable
as int,followers: null == followers ? _self.followers : followers // ignore: cast_nullable_to_non_nullable
as int,following: null == following ? _self.following : following // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GithubUserModel].
extension GithubUserModelPatterns on GithubUserModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GithubUserModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GithubUserModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GithubUserModel value)  $default,){
final _that = this;
switch (_that) {
case _GithubUserModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GithubUserModel value)?  $default,){
final _that = this;
switch (_that) {
case _GithubUserModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String login, @JsonKey(fromJson: _idAsString)  String id,  String? name,  String? email, @JsonKey(name: 'avatar_url')  String? avatarUrl,  String? bio, @JsonKey(name: 'public_repos')  int publicRepos,  int followers,  int following)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GithubUserModel() when $default != null:
return $default(_that.login,_that.id,_that.name,_that.email,_that.avatarUrl,_that.bio,_that.publicRepos,_that.followers,_that.following);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String login, @JsonKey(fromJson: _idAsString)  String id,  String? name,  String? email, @JsonKey(name: 'avatar_url')  String? avatarUrl,  String? bio, @JsonKey(name: 'public_repos')  int publicRepos,  int followers,  int following)  $default,) {final _that = this;
switch (_that) {
case _GithubUserModel():
return $default(_that.login,_that.id,_that.name,_that.email,_that.avatarUrl,_that.bio,_that.publicRepos,_that.followers,_that.following);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String login, @JsonKey(fromJson: _idAsString)  String id,  String? name,  String? email, @JsonKey(name: 'avatar_url')  String? avatarUrl,  String? bio, @JsonKey(name: 'public_repos')  int publicRepos,  int followers,  int following)?  $default,) {final _that = this;
switch (_that) {
case _GithubUserModel() when $default != null:
return $default(_that.login,_that.id,_that.name,_that.email,_that.avatarUrl,_that.bio,_that.publicRepos,_that.followers,_that.following);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GithubUserModel implements GithubUserModel {
  const _GithubUserModel({required this.login, @JsonKey(fromJson: _idAsString) required this.id, this.name, this.email, @JsonKey(name: 'avatar_url') this.avatarUrl, this.bio, @JsonKey(name: 'public_repos') this.publicRepos = 0, this.followers = 0, this.following = 0});
  factory _GithubUserModel.fromJson(Map<String, dynamic> json) => _$GithubUserModelFromJson(json);

@override final  String login;
@override@JsonKey(fromJson: _idAsString) final  String id;
@override final  String? name;
@override final  String? email;
@override@JsonKey(name: 'avatar_url') final  String? avatarUrl;
@override final  String? bio;
@override@JsonKey(name: 'public_repos') final  int publicRepos;
@override@JsonKey() final  int followers;
@override@JsonKey() final  int following;

/// Create a copy of GithubUserModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GithubUserModelCopyWith<_GithubUserModel> get copyWith => __$GithubUserModelCopyWithImpl<_GithubUserModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GithubUserModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GithubUserModel&&(identical(other.login, login) || other.login == login)&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.publicRepos, publicRepos) || other.publicRepos == publicRepos)&&(identical(other.followers, followers) || other.followers == followers)&&(identical(other.following, following) || other.following == following));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,login,id,name,email,avatarUrl,bio,publicRepos,followers,following);
}

@override
String toString() {
    return 'GithubUserModel(login: $login, id: $id, name: $name, email: $email, avatarUrl: $avatarUrl, bio: $bio, publicRepos: $publicRepos, followers: $followers, following: $following)';
}


}

/// @nodoc
abstract mixin class _$GithubUserModelCopyWith<$Res> implements $GithubUserModelCopyWith<$Res> {
  factory _$GithubUserModelCopyWith(_GithubUserModel value, $Res Function(_GithubUserModel) _then) = __$GithubUserModelCopyWithImpl;
@override @useResult
$Res call({
 String login,@JsonKey(fromJson: _idAsString) String id, String? name, String? email,@JsonKey(name: 'avatar_url') String? avatarUrl, String? bio,@JsonKey(name: 'public_repos') int publicRepos, int followers, int following
});




}
/// @nodoc
class __$GithubUserModelCopyWithImpl<$Res>
    implements _$GithubUserModelCopyWith<$Res> {
  __$GithubUserModelCopyWithImpl(this._self, this._then);

  final _GithubUserModel _self;
  final $Res Function(_GithubUserModel) _then;

/// Create a copy of GithubUserModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? login = null,Object? id = null,Object? name = freezed,Object? email = freezed,Object? avatarUrl = freezed,Object? bio = freezed,Object? publicRepos = null,Object? followers = null,Object? following = null,}) {
  return _then(_GithubUserModel(
login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,publicRepos: null == publicRepos ? _self.publicRepos : publicRepos // ignore: cast_nullable_to_non_nullable
as int,followers: null == followers ? _self.followers : followers // ignore: cast_nullable_to_non_nullable
as int,following: null == following ? _self.following : following // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
