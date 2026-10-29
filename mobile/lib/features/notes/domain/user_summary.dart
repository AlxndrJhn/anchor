import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_summary.freezed.dart';
part 'user_summary.g.dart';

@freezed
abstract class UserSummary with _$UserSummary {
  const factory UserSummary({
    required String id,
    required String name,
    required String email,
    String? profileImage,
  }) = _UserSummary;

  factory UserSummary.fromJson(Map<String, dynamic> json) =>
      _$UserSummaryFromJson(json);
}
