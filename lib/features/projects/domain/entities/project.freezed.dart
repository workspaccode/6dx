// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Project {

 String get id; String get name; String? get description; String? get icon; String? get colorHex; int get openTasks; int get doneTasks; int get membersCount; String? get repositoryFullName; bool get isArchived; DateTime? get updatedAt;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Project;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.icon, _this.icon) || other.icon == _this.icon)&&(identical(other.colorHex, _this.colorHex) || other.colorHex == _this.colorHex)&&(identical(other.openTasks, _this.openTasks) || other.openTasks == _this.openTasks)&&(identical(other.doneTasks, _this.doneTasks) || other.doneTasks == _this.doneTasks)&&(identical(other.membersCount, _this.membersCount) || other.membersCount == _this.membersCount)&&(identical(other.repositoryFullName, _this.repositoryFullName) || other.repositoryFullName == _this.repositoryFullName)&&(identical(other.isArchived, _this.isArchived) || other.isArchived == _this.isArchived)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as Project;
  return Object.hash(runtimeType,_this.id,_this.name,_this.description,_this.icon,_this.colorHex,_this.openTasks,_this.doneTasks,_this.membersCount,_this.repositoryFullName,_this.isArchived,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Project;
  return 'Project(id: ${_this.id}, name: ${_this.name}, description: ${_this.description}, icon: ${_this.icon}, colorHex: ${_this.colorHex}, openTasks: ${_this.openTasks}, doneTasks: ${_this.doneTasks}, membersCount: ${_this.membersCount}, repositoryFullName: ${_this.repositoryFullName}, isArchived: ${_this.isArchived}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, String? icon, String? colorHex, int openTasks, int doneTasks, int membersCount, String? repositoryFullName, bool isArchived, DateTime? updatedAt
});




}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? icon = freezed,Object? colorHex = freezed,Object? openTasks = null,Object? doneTasks = null,Object? membersCount = null,Object? repositoryFullName = freezed,Object? isArchived = null,Object? updatedAt = freezed,}) {
  return _then(Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,colorHex: freezed == colorHex ? _self.colorHex : colorHex // ignore: cast_nullable_to_non_nullable
as String?,openTasks: null == openTasks ? _self.openTasks : openTasks // ignore: cast_nullable_to_non_nullable
as int,doneTasks: null == doneTasks ? _self.doneTasks : doneTasks // ignore: cast_nullable_to_non_nullable
as int,membersCount: null == membersCount ? _self.membersCount : membersCount // ignore: cast_nullable_to_non_nullable
as int,repositoryFullName: freezed == repositoryFullName ? _self.repositoryFullName : repositoryFullName // ignore: cast_nullable_to_non_nullable
as String?,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Project].
extension ProjectPatterns on Project {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Project value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Project value)  $default,){
final _that = this;
switch (_that) {
case _Project():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Project value)?  $default,){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  String? icon,  String? colorHex,  int openTasks,  int doneTasks,  int membersCount,  String? repositoryFullName,  bool isArchived,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.icon,_that.colorHex,_that.openTasks,_that.doneTasks,_that.membersCount,_that.repositoryFullName,_that.isArchived,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  String? icon,  String? colorHex,  int openTasks,  int doneTasks,  int membersCount,  String? repositoryFullName,  bool isArchived,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Project():
return $default(_that.id,_that.name,_that.description,_that.icon,_that.colorHex,_that.openTasks,_that.doneTasks,_that.membersCount,_that.repositoryFullName,_that.isArchived,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  String? icon,  String? colorHex,  int openTasks,  int doneTasks,  int membersCount,  String? repositoryFullName,  bool isArchived,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.icon,_that.colorHex,_that.openTasks,_that.doneTasks,_that.membersCount,_that.repositoryFullName,_that.isArchived,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Project extends Project {
  const _Project({required this.id, required this.name, this.description, this.icon, this.colorHex, this.openTasks = 0, this.doneTasks = 0, this.membersCount = 0, this.repositoryFullName, this.isArchived = false, this.updatedAt}): super._();
  

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  String? icon;
@override final  String? colorHex;
@override@JsonKey() final  int openTasks;
@override@JsonKey() final  int doneTasks;
@override@JsonKey() final  int membersCount;
@override final  String? repositoryFullName;
@override@JsonKey() final  bool isArchived;
@override final  DateTime? updatedAt;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.colorHex, colorHex) || other.colorHex == colorHex)&&(identical(other.openTasks, openTasks) || other.openTasks == openTasks)&&(identical(other.doneTasks, doneTasks) || other.doneTasks == doneTasks)&&(identical(other.membersCount, membersCount) || other.membersCount == membersCount)&&(identical(other.repositoryFullName, repositoryFullName) || other.repositoryFullName == repositoryFullName)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,description,icon,colorHex,openTasks,doneTasks,membersCount,repositoryFullName,isArchived,updatedAt);
}

@override
String toString() {
    return 'Project(id: $id, name: $name, description: $description, icon: $icon, colorHex: $colorHex, openTasks: $openTasks, doneTasks: $doneTasks, membersCount: $membersCount, repositoryFullName: $repositoryFullName, isArchived: $isArchived, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, String? icon, String? colorHex, int openTasks, int doneTasks, int membersCount, String? repositoryFullName, bool isArchived, DateTime? updatedAt
});




}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? icon = freezed,Object? colorHex = freezed,Object? openTasks = null,Object? doneTasks = null,Object? membersCount = null,Object? repositoryFullName = freezed,Object? isArchived = null,Object? updatedAt = freezed,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,colorHex: freezed == colorHex ? _self.colorHex : colorHex // ignore: cast_nullable_to_non_nullable
as String?,openTasks: null == openTasks ? _self.openTasks : openTasks // ignore: cast_nullable_to_non_nullable
as int,doneTasks: null == doneTasks ? _self.doneTasks : doneTasks // ignore: cast_nullable_to_non_nullable
as int,membersCount: null == membersCount ? _self.membersCount : membersCount // ignore: cast_nullable_to_non_nullable
as int,repositoryFullName: freezed == repositoryFullName ? _self.repositoryFullName : repositoryFullName // ignore: cast_nullable_to_non_nullable
as String?,isArchived: null == isArchived ? _self.isArchived : isArchived // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
