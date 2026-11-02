// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Task {

 String get id; String get title; String? get description; TaskStatus get status; TaskPriority get priority; String? get projectId; String? get projectName; String? get assigneeName; String? get assigneeAvatar; String? get label; String? get prNumber; String? get branchName; int get subtasksDone; int get subtasksTotal; int get commentsCount; DateTime? get dueDate; DateTime? get createdAt;
/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCopyWith<Task> get copyWith => _$TaskCopyWithImpl<Task>(this as Task, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Task;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Task&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.priority, _this.priority) || other.priority == _this.priority)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.projectName, _this.projectName) || other.projectName == _this.projectName)&&(identical(other.assigneeName, _this.assigneeName) || other.assigneeName == _this.assigneeName)&&(identical(other.assigneeAvatar, _this.assigneeAvatar) || other.assigneeAvatar == _this.assigneeAvatar)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.prNumber, _this.prNumber) || other.prNumber == _this.prNumber)&&(identical(other.branchName, _this.branchName) || other.branchName == _this.branchName)&&(identical(other.subtasksDone, _this.subtasksDone) || other.subtasksDone == _this.subtasksDone)&&(identical(other.subtasksTotal, _this.subtasksTotal) || other.subtasksTotal == _this.subtasksTotal)&&(identical(other.commentsCount, _this.commentsCount) || other.commentsCount == _this.commentsCount)&&(identical(other.dueDate, _this.dueDate) || other.dueDate == _this.dueDate)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}


@override
int get hashCode {
  final _this = this as Task;
  return Object.hash(runtimeType,_this.id,_this.title,_this.description,_this.status,_this.priority,_this.projectId,_this.projectName,_this.assigneeName,_this.assigneeAvatar,_this.label,_this.prNumber,_this.branchName,_this.subtasksDone,_this.subtasksTotal,_this.commentsCount,_this.dueDate,_this.createdAt);
}

@override
String toString() {
  final _this = this as Task;
  return 'Task(id: ${_this.id}, title: ${_this.title}, description: ${_this.description}, status: ${_this.status}, priority: ${_this.priority}, projectId: ${_this.projectId}, projectName: ${_this.projectName}, assigneeName: ${_this.assigneeName}, assigneeAvatar: ${_this.assigneeAvatar}, label: ${_this.label}, prNumber: ${_this.prNumber}, branchName: ${_this.branchName}, subtasksDone: ${_this.subtasksDone}, subtasksTotal: ${_this.subtasksTotal}, commentsCount: ${_this.commentsCount}, dueDate: ${_this.dueDate}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $TaskCopyWith<$Res>  {
  factory $TaskCopyWith(Task value, $Res Function(Task) _then) = _$TaskCopyWithImpl;
@useResult
$Res call({
 String id, String title, String? description, TaskStatus status, TaskPriority priority, String? projectId, String? projectName, String? assigneeName, String? assigneeAvatar, String? label, String? prNumber, String? branchName, int subtasksDone, int subtasksTotal, int commentsCount, DateTime? dueDate, DateTime? createdAt
});




}
/// @nodoc
class _$TaskCopyWithImpl<$Res>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._self, this._then);

  final Task _self;
  final $Res Function(Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? status = null,Object? priority = null,Object? projectId = freezed,Object? projectName = freezed,Object? assigneeName = freezed,Object? assigneeAvatar = freezed,Object? label = freezed,Object? prNumber = freezed,Object? branchName = freezed,Object? subtasksDone = null,Object? subtasksTotal = null,Object? commentsCount = null,Object? dueDate = freezed,Object? createdAt = freezed,}) {
  return _then(Task(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TaskStatus,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as TaskPriority,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,projectName: freezed == projectName ? _self.projectName : projectName // ignore: cast_nullable_to_non_nullable
as String?,assigneeName: freezed == assigneeName ? _self.assigneeName : assigneeName // ignore: cast_nullable_to_non_nullable
as String?,assigneeAvatar: freezed == assigneeAvatar ? _self.assigneeAvatar : assigneeAvatar // ignore: cast_nullable_to_non_nullable
as String?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,prNumber: freezed == prNumber ? _self.prNumber : prNumber // ignore: cast_nullable_to_non_nullable
as String?,branchName: freezed == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String?,subtasksDone: null == subtasksDone ? _self.subtasksDone : subtasksDone // ignore: cast_nullable_to_non_nullable
as int,subtasksTotal: null == subtasksTotal ? _self.subtasksTotal : subtasksTotal // ignore: cast_nullable_to_non_nullable
as int,commentsCount: null == commentsCount ? _self.commentsCount : commentsCount // ignore: cast_nullable_to_non_nullable
as int,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Task].
extension TaskPatterns on Task {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Task value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Task value)  $default,){
final _that = this;
switch (_that) {
case _Task():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Task value)?  $default,){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String? description,  TaskStatus status,  TaskPriority priority,  String? projectId,  String? projectName,  String? assigneeName,  String? assigneeAvatar,  String? label,  String? prNumber,  String? branchName,  int subtasksDone,  int subtasksTotal,  int commentsCount,  DateTime? dueDate,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.status,_that.priority,_that.projectId,_that.projectName,_that.assigneeName,_that.assigneeAvatar,_that.label,_that.prNumber,_that.branchName,_that.subtasksDone,_that.subtasksTotal,_that.commentsCount,_that.dueDate,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String? description,  TaskStatus status,  TaskPriority priority,  String? projectId,  String? projectName,  String? assigneeName,  String? assigneeAvatar,  String? label,  String? prNumber,  String? branchName,  int subtasksDone,  int subtasksTotal,  int commentsCount,  DateTime? dueDate,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Task():
return $default(_that.id,_that.title,_that.description,_that.status,_that.priority,_that.projectId,_that.projectName,_that.assigneeName,_that.assigneeAvatar,_that.label,_that.prNumber,_that.branchName,_that.subtasksDone,_that.subtasksTotal,_that.commentsCount,_that.dueDate,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String? description,  TaskStatus status,  TaskPriority priority,  String? projectId,  String? projectName,  String? assigneeName,  String? assigneeAvatar,  String? label,  String? prNumber,  String? branchName,  int subtasksDone,  int subtasksTotal,  int commentsCount,  DateTime? dueDate,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.status,_that.priority,_that.projectId,_that.projectName,_that.assigneeName,_that.assigneeAvatar,_that.label,_that.prNumber,_that.branchName,_that.subtasksDone,_that.subtasksTotal,_that.commentsCount,_that.dueDate,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Task extends Task {
  const _Task({required this.id, required this.title, this.description, this.status = TaskStatus.todo, this.priority = TaskPriority.medium, this.projectId, this.projectName, this.assigneeName, this.assigneeAvatar, this.label, this.prNumber, this.branchName, this.subtasksDone = 0, this.subtasksTotal = 0, this.commentsCount = 0, this.dueDate, this.createdAt}): super._();
  

@override final  String id;
@override final  String title;
@override final  String? description;
@override@JsonKey() final  TaskStatus status;
@override@JsonKey() final  TaskPriority priority;
@override final  String? projectId;
@override final  String? projectName;
@override final  String? assigneeName;
@override final  String? assigneeAvatar;
@override final  String? label;
@override final  String? prNumber;
@override final  String? branchName;
@override@JsonKey() final  int subtasksDone;
@override@JsonKey() final  int subtasksTotal;
@override@JsonKey() final  int commentsCount;
@override final  DateTime? dueDate;
@override final  DateTime? createdAt;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskCopyWith<_Task> get copyWith => __$TaskCopyWithImpl<_Task>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Task&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.projectName, projectName) || other.projectName == projectName)&&(identical(other.assigneeName, assigneeName) || other.assigneeName == assigneeName)&&(identical(other.assigneeAvatar, assigneeAvatar) || other.assigneeAvatar == assigneeAvatar)&&(identical(other.label, label) || other.label == label)&&(identical(other.prNumber, prNumber) || other.prNumber == prNumber)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.subtasksDone, subtasksDone) || other.subtasksDone == subtasksDone)&&(identical(other.subtasksTotal, subtasksTotal) || other.subtasksTotal == subtasksTotal)&&(identical(other.commentsCount, commentsCount) || other.commentsCount == commentsCount)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,description,status,priority,projectId,projectName,assigneeName,assigneeAvatar,label,prNumber,branchName,subtasksDone,subtasksTotal,commentsCount,dueDate,createdAt);
}

@override
String toString() {
    return 'Task(id: $id, title: $title, description: $description, status: $status, priority: $priority, projectId: $projectId, projectName: $projectName, assigneeName: $assigneeName, assigneeAvatar: $assigneeAvatar, label: $label, prNumber: $prNumber, branchName: $branchName, subtasksDone: $subtasksDone, subtasksTotal: $subtasksTotal, commentsCount: $commentsCount, dueDate: $dueDate, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$TaskCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$TaskCopyWith(_Task value, $Res Function(_Task) _then) = __$TaskCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String? description, TaskStatus status, TaskPriority priority, String? projectId, String? projectName, String? assigneeName, String? assigneeAvatar, String? label, String? prNumber, String? branchName, int subtasksDone, int subtasksTotal, int commentsCount, DateTime? dueDate, DateTime? createdAt
});




}
/// @nodoc
class __$TaskCopyWithImpl<$Res>
    implements _$TaskCopyWith<$Res> {
  __$TaskCopyWithImpl(this._self, this._then);

  final _Task _self;
  final $Res Function(_Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? status = null,Object? priority = null,Object? projectId = freezed,Object? projectName = freezed,Object? assigneeName = freezed,Object? assigneeAvatar = freezed,Object? label = freezed,Object? prNumber = freezed,Object? branchName = freezed,Object? subtasksDone = null,Object? subtasksTotal = null,Object? commentsCount = null,Object? dueDate = freezed,Object? createdAt = freezed,}) {
  return _then(_Task(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TaskStatus,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as TaskPriority,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,projectName: freezed == projectName ? _self.projectName : projectName // ignore: cast_nullable_to_non_nullable
as String?,assigneeName: freezed == assigneeName ? _self.assigneeName : assigneeName // ignore: cast_nullable_to_non_nullable
as String?,assigneeAvatar: freezed == assigneeAvatar ? _self.assigneeAvatar : assigneeAvatar // ignore: cast_nullable_to_non_nullable
as String?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,prNumber: freezed == prNumber ? _self.prNumber : prNumber // ignore: cast_nullable_to_non_nullable
as String?,branchName: freezed == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String?,subtasksDone: null == subtasksDone ? _self.subtasksDone : subtasksDone // ignore: cast_nullable_to_non_nullable
as int,subtasksTotal: null == subtasksTotal ? _self.subtasksTotal : subtasksTotal // ignore: cast_nullable_to_non_nullable
as int,commentsCount: null == commentsCount ? _self.commentsCount : commentsCount // ignore: cast_nullable_to_non_nullable
as int,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
