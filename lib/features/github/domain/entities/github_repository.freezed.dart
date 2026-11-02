// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'github_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GithubRepository {

 String get id; String get name; String get fullName; String? get description; String? get htmlUrl; String? get language; bool get isPrivate; int get stargazersCount; int get openIssuesCount; String? get defaultBranch;
/// Create a copy of GithubRepository
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GithubRepositoryCopyWith<GithubRepository> get copyWith => _$GithubRepositoryCopyWithImpl<GithubRepository>(this as GithubRepository, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GithubRepository;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GithubRepository&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.fullName, _this.fullName) || other.fullName == _this.fullName)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.htmlUrl, _this.htmlUrl) || other.htmlUrl == _this.htmlUrl)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.isPrivate, _this.isPrivate) || other.isPrivate == _this.isPrivate)&&(identical(other.stargazersCount, _this.stargazersCount) || other.stargazersCount == _this.stargazersCount)&&(identical(other.openIssuesCount, _this.openIssuesCount) || other.openIssuesCount == _this.openIssuesCount)&&(identical(other.defaultBranch, _this.defaultBranch) || other.defaultBranch == _this.defaultBranch));
}


@override
int get hashCode {
  final _this = this as GithubRepository;
  return Object.hash(runtimeType,_this.id,_this.name,_this.fullName,_this.description,_this.htmlUrl,_this.language,_this.isPrivate,_this.stargazersCount,_this.openIssuesCount,_this.defaultBranch);
}

@override
String toString() {
  final _this = this as GithubRepository;
  return 'GithubRepository(id: ${_this.id}, name: ${_this.name}, fullName: ${_this.fullName}, description: ${_this.description}, htmlUrl: ${_this.htmlUrl}, language: ${_this.language}, isPrivate: ${_this.isPrivate}, stargazersCount: ${_this.stargazersCount}, openIssuesCount: ${_this.openIssuesCount}, defaultBranch: ${_this.defaultBranch})';
}


}

/// @nodoc
abstract mixin class $GithubRepositoryCopyWith<$Res>  {
  factory $GithubRepositoryCopyWith(GithubRepository value, $Res Function(GithubRepository) _then) = _$GithubRepositoryCopyWithImpl;
@useResult
$Res call({
 String id, String name, String fullName, String? description, String? htmlUrl, String? language, bool isPrivate, int stargazersCount, int openIssuesCount, String? defaultBranch
});




}
/// @nodoc
class _$GithubRepositoryCopyWithImpl<$Res>
    implements $GithubRepositoryCopyWith<$Res> {
  _$GithubRepositoryCopyWithImpl(this._self, this._then);

  final GithubRepository _self;
  final $Res Function(GithubRepository) _then;

/// Create a copy of GithubRepository
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? fullName = null,Object? description = freezed,Object? htmlUrl = freezed,Object? language = freezed,Object? isPrivate = null,Object? stargazersCount = null,Object? openIssuesCount = null,Object? defaultBranch = freezed,}) {
  return _then(GithubRepository(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,htmlUrl: freezed == htmlUrl ? _self.htmlUrl : htmlUrl // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,stargazersCount: null == stargazersCount ? _self.stargazersCount : stargazersCount // ignore: cast_nullable_to_non_nullable
as int,openIssuesCount: null == openIssuesCount ? _self.openIssuesCount : openIssuesCount // ignore: cast_nullable_to_non_nullable
as int,defaultBranch: freezed == defaultBranch ? _self.defaultBranch : defaultBranch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GithubRepository].
extension GithubRepositoryPatterns on GithubRepository {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GithubRepository value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GithubRepository() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GithubRepository value)  $default,){
final _that = this;
switch (_that) {
case _GithubRepository():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GithubRepository value)?  $default,){
final _that = this;
switch (_that) {
case _GithubRepository() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String fullName,  String? description,  String? htmlUrl,  String? language,  bool isPrivate,  int stargazersCount,  int openIssuesCount,  String? defaultBranch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GithubRepository() when $default != null:
return $default(_that.id,_that.name,_that.fullName,_that.description,_that.htmlUrl,_that.language,_that.isPrivate,_that.stargazersCount,_that.openIssuesCount,_that.defaultBranch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String fullName,  String? description,  String? htmlUrl,  String? language,  bool isPrivate,  int stargazersCount,  int openIssuesCount,  String? defaultBranch)  $default,) {final _that = this;
switch (_that) {
case _GithubRepository():
return $default(_that.id,_that.name,_that.fullName,_that.description,_that.htmlUrl,_that.language,_that.isPrivate,_that.stargazersCount,_that.openIssuesCount,_that.defaultBranch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String fullName,  String? description,  String? htmlUrl,  String? language,  bool isPrivate,  int stargazersCount,  int openIssuesCount,  String? defaultBranch)?  $default,) {final _that = this;
switch (_that) {
case _GithubRepository() when $default != null:
return $default(_that.id,_that.name,_that.fullName,_that.description,_that.htmlUrl,_that.language,_that.isPrivate,_that.stargazersCount,_that.openIssuesCount,_that.defaultBranch);case _:
  return null;

}
}

}

/// @nodoc


class _GithubRepository extends GithubRepository {
  const _GithubRepository({required this.id, required this.name, required this.fullName, this.description, this.htmlUrl, this.language, this.isPrivate = false, this.stargazersCount = 0, this.openIssuesCount = 0, this.defaultBranch}): super._();
  

@override final  String id;
@override final  String name;
@override final  String fullName;
@override final  String? description;
@override final  String? htmlUrl;
@override final  String? language;
@override@JsonKey() final  bool isPrivate;
@override@JsonKey() final  int stargazersCount;
@override@JsonKey() final  int openIssuesCount;
@override final  String? defaultBranch;

/// Create a copy of GithubRepository
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GithubRepositoryCopyWith<_GithubRepository> get copyWith => __$GithubRepositoryCopyWithImpl<_GithubRepository>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GithubRepository&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.description, description) || other.description == description)&&(identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl)&&(identical(other.language, language) || other.language == language)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.stargazersCount, stargazersCount) || other.stargazersCount == stargazersCount)&&(identical(other.openIssuesCount, openIssuesCount) || other.openIssuesCount == openIssuesCount)&&(identical(other.defaultBranch, defaultBranch) || other.defaultBranch == defaultBranch));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,fullName,description,htmlUrl,language,isPrivate,stargazersCount,openIssuesCount,defaultBranch);
}

@override
String toString() {
    return 'GithubRepository(id: $id, name: $name, fullName: $fullName, description: $description, htmlUrl: $htmlUrl, language: $language, isPrivate: $isPrivate, stargazersCount: $stargazersCount, openIssuesCount: $openIssuesCount, defaultBranch: $defaultBranch)';
}


}

/// @nodoc
abstract mixin class _$GithubRepositoryCopyWith<$Res> implements $GithubRepositoryCopyWith<$Res> {
  factory _$GithubRepositoryCopyWith(_GithubRepository value, $Res Function(_GithubRepository) _then) = __$GithubRepositoryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String fullName, String? description, String? htmlUrl, String? language, bool isPrivate, int stargazersCount, int openIssuesCount, String? defaultBranch
});




}
/// @nodoc
class __$GithubRepositoryCopyWithImpl<$Res>
    implements _$GithubRepositoryCopyWith<$Res> {
  __$GithubRepositoryCopyWithImpl(this._self, this._then);

  final _GithubRepository _self;
  final $Res Function(_GithubRepository) _then;

/// Create a copy of GithubRepository
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? fullName = null,Object? description = freezed,Object? htmlUrl = freezed,Object? language = freezed,Object? isPrivate = null,Object? stargazersCount = null,Object? openIssuesCount = null,Object? defaultBranch = freezed,}) {
  return _then(_GithubRepository(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,htmlUrl: freezed == htmlUrl ? _self.htmlUrl : htmlUrl // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,stargazersCount: null == stargazersCount ? _self.stargazersCount : stargazersCount // ignore: cast_nullable_to_non_nullable
as int,openIssuesCount: null == openIssuesCount ? _self.openIssuesCount : openIssuesCount // ignore: cast_nullable_to_non_nullable
as int,defaultBranch: freezed == defaultBranch ? _self.defaultBranch : defaultBranch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
