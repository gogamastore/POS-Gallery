import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String uid,
    required String name,
    String? email,
    String? phone,
    String? photoURL,
    // Beri nilai default jika 'position' null di firestore
    @Default('Jabatan Tidak Diketahui') String position,
    String? role,
    String? whatsapp,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}
