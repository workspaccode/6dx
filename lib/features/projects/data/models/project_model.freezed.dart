// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProjectModel {

 String get id; String get name; String? get description; String? get icon; String? get colorHex; int get openTasks; int get doneTasks; int get membersCount; String? get repositoryFullName; bool get isArchived; DateTime? get updatedAt;
/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectModelCopyWith<ProjectModel> get copyWith => _$ProjectModelCopyWithImpl<ProjectModel>(this as ProjectModel, _$identity);

  /// Serializes this ProjectModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProjectModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectModel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.icon, _this.icon) || other.icon == _this.icon)&&(identical(other.colorHex, _this.colorHex) || other.colorHex == _this.colorHex)&&(identical(other.openTasks, _this.openTasks) || other.openTasks == _this.openTasks)&&(identical(other.doneTasks, _this.doneTasks) || other.doneTasks == _this.doneTasks)&&(identical(other.membersCount, _this.membersCount) || other.membersCount == _this.membersCount)&&(identical(other.repositoryFullName, _this.repositoryFullName) || other.repositoryFullName == _this.repositoryFullName)&&(identical(other.isArchived, _this.isArchived) || other.isArchived == _this.isArchived)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProjectModel;
  return Object.hash(runtimeType,_this.id,_this.name,_this.description,_this.icon,_this.colorHex,_this.openTasks,_this.doneTasks,_this.membersCount,_this.repositoryFullName,_this.isArchived,_this.updatedAt);
}

@override
String toString() {
  final _this = this as ProjectModel;
  return 'ProjectModel(id: ${_this.id}, name: ${_this.name}, description: ${_this.description}, icon: ${_this.icon}, colorHex: ${_this.colorHex}, openTasks: ${_this.openTasks}, doneTasks: ${_this.doneTasks}, membersCount: ${_this.membersCount}, repositoryFullName: ${_this.repositoryFullName}, isArchived: ${_this.isArchived}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ProjectModelCopyWith<$Res>  {
  factory $ProjectModelCopyWith(ProjectModel value, $Res Function(ProjectModel) _then) = _$ProjectModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, String? icon, String? colorHex, int openTasks, int doneTasks, int membersCount, String? repositoryFullName, bool isArchived, DateTime? updatedAt
});




}
/// @nodoc
class _$ProjectModelCopyWithImpl<$Res>
    implements $ProjectModelCopyWith<$Res> {
  _$ProjectModelCopyWithImpl(this._self, this._then);

  final ProjectModel _self;
  final $Res Function(ProjectModel) _then;

/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? icon = freezed,Object? colorHex = freezed,Object? openTasks = null,Object? doneTasks = null,Object? membersCount = null,Object? repositoryFullName = freezed,Object? isArchived = null,Object? updatedAt = freezed,}) {
  return _then(ProjectModel(
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


/// Adds pattern-matching-related methods to [ProjectModel].
extension ProjectModelPatterns on ProjectModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectModel value)  $default,){
final _that = this;
switch (_that) {
case _ProjectModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectModel() when $default != null:
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
case _ProjectModel() when $default != null:
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
case _ProjectModel():
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
case _ProjectModel() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.icon,_that.colorHex,_that.openTasks,_that.doneTasks,_that.membersCount,_that.repositoryFullName,_that.isArchived,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectModel extends ProjectModel {
  const _ProjectModel({required this.id, required this.name, this.description, this.icon, this.colorHex, this.openTasks = 0, this.doneTasks = 0, this.membersCount = 0, this.repositoryFullName, this.isArchived = false, this.updatedAt}): super._();
  factory _ProjectModel.fromJson(Map<String, dynamic> json) => _$ProjectModelFromJson(json);

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

/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectModelCopyWith<_ProjectModel> get copyWith => __$ProjectModelCopyWithImpl<_ProjectModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.colorHex, colorHex) || other.colorHex == colorHex)&&(identical(other.openTasks, openTasks) || other.openTasks == openTasks)&&(identical(other.doneTasks, doneTasks) || other.doneTasks == doneTasks)&&(identical(other.membersCount, membersCount) || other.membersCount == membersCount)&&(identical(other.repositoryFullName, repositoryFullName) || other.repositoryFullName == repositoryFullName)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,description,icon,colorHex,openTasks,doneTasks,membersCount,repositoryFullName,isArchived,updatedAt);
}

@override
String toString() {
    return 'ProjectModel(id: $id, name: $name, description: $description, icon: $icon, colorHex: $colorHex, openTasks: $openTasks, doneTasks: $doneTasks, membersCount: $membersCount, repositoryFullName: $repositoryFullName, isArchived: $isArchived, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ProjectModelCopyWith<$Res> implements $ProjectModelCopyWith<$Res> {
  factory _$ProjectModelCopyWith(_ProjectModel value, $Res Function(_ProjectModel) _then) = __$ProjectModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, String? icon, String? colorHex, int openTasks, int doneTasks, int membersCount, String? repositoryFullName, bool isArchived, DateTime? updatedAt
});




}
/// @nodoc
class __$ProjectModelCopyWithImpl<$Res>
    implements _$ProjectModelCopyWith<$Res> {
  __$ProjectModelCopyWithImpl(this._self, this._then);

  final _ProjectModel _self;
  final $Res Function(_ProjectModel) _then;

/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? icon = freezed,Object? colorHex = freezed,Object? openTasks = null,Object? doneTasks = null,Object? membersCount = null,Object? repositoryFullName = freezed,Object? isArchived = null,Object? updatedAt = freezed,}) {
  return _then(_ProjectModel(
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
