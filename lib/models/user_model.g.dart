// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoURL: json['photoURL'] as String?,
      position: json['position'] as String? ?? 'Jabatan Tidak Diketahui',
      role: json['role'] as String?,
      whatsapp: json['whatsapp'] as String?,
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'photoURL': instance.photoURL,
      'position': instance.position,
      'role': instance.role,
      'whatsapp': instance.whatsapp,
    };
