import 'dart:math';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/text/name_order.dart';

part 'tag.freezed.dart';

const List<String> _tagColors = [
  '#E57373',
  '#F06292',
  '#BA68C8',
  '#9575CD',
  '#7986CB',
  '#64B5F6',
  '#4FC3F7',
  '#4DD0E1',
  '#4DB6AC',
  '#81C784',
  '#AED581',
  '#DCE775',
  '#FFD54F',
  '#FFB74D',
  '#FF8A65',
  '#A1887F',
  '#90A4AE',
];

String generateRandomTagColor() {
  final random = Random();
  return _tagColors[random.nextInt(_tagColors.length)];
}

/// Supports #RGB, #RRGGBB, #AARRGGBB and 0xAARRGGBB.
Color parseTagColor(String? hexColor, {Color fallback = Colors.grey}) {
  if (hexColor == null || hexColor.isEmpty) return fallback;

  String hex = hexColor.replaceAll('#', '').replaceAll('0x', '');

  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }

  if (hex.length == 6) {
    hex = 'FF$hex';
  }

  try {
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// Names are kept without the spaces around them and compared ignoring case.
bool isTagNameTaken(Iterable<Tag> tags, String name, {String? exceptId}) {
  final wanted = name.trim().toLowerCase();
  return tags.any(
    (tag) => tag.id != exceptId && tag.name.toLowerCase() == wanted,
  );
}

/// Tags in name order, the order every tag list shows.
List<Tag> sortTagsByName(Iterable<Tag> tags) =>
    sortedByName(tags, (tag) => tag.name);

/// A note's tags in the order they show.
List<Tag> tagsByName(Iterable<String> ids, Map<String, Tag> byId) =>
    sortTagsByName([for (final id in ids) ?byId[id]]);

class TagNameTakenException implements Exception {
  const TagNameTakenException(this.name);

  final String name;

  @override
  String toString() => 'TagNameTakenException: $name';
}

@freezed
abstract class Tag with _$Tag {
  const factory Tag({
    required String id,
    required String name,
    String? color,
    DateTime? updatedAt,
    @Default(true) bool isSynced,
    @Default(false) bool isDeleted,
  }) = _Tag;
}
