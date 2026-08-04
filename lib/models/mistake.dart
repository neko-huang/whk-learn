import 'dart:convert';
import 'package:flutter/material.dart';
import 'database.dart';

/// 易错点数据模型（带科目信息的完整模型）
@immutable
class MistakeWithSubject {
  final Mistake mistake;
  final Subject subject;
  final List<MistakeImage> images;

  const MistakeWithSubject({
    required this.mistake,
    required this.subject,
    required this.images,
  });

  /// 从数据库查询结果构建
  factory MistakeWithSubject.fromDb({
    required Mistake mistake,
    required Subject subject,
    List<MistakeImage>? images,
  }) {
    return MistakeWithSubject(
      mistake: mistake,
      subject: subject,
      images: images ?? [],
    );
  }

  /// 标签列表
  List<String> get tagList {
    if (mistake.tags.isEmpty) return [];
    try {
      final decoded = jsonDecode(mistake.tags);
      if (decoded is List) return decoded.cast<String>();
      return [];
    } catch (_) {
      // 兼容旧数据：手工拼接的 JSON 格式
      final cleaned = mistake.tags.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
      if (cleaned.isEmpty) return [];
      return cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
  }

  /// 是否需要复习
  bool get needsReview {
    if (mistake.nextReviewDate == null) return true;
    return DateTime.now().isAfter(mistake.nextReviewDate!);
  }

  /// 复习紧急程度
  ReviewUrgency get reviewUrgency {
    if (mistake.nextReviewDate == null) return ReviewUrgency.overdue;
    final now = DateTime.now();
    final diff = mistake.nextReviewDate!.difference(now).inDays;
    if (diff < 0) return ReviewUrgency.overdue;
    if (diff == 0) return ReviewUrgency.today;
    if (diff <= 1) return ReviewUrgency.tomorrow;
    return ReviewUrgency.later;
  }
}

enum ReviewUrgency {
  overdue,   // 逾期
  today,     // 今天
  tomorrow,  // 明天
  later,     // 之后
}

/// 科目数据模型（扩展方法）
extension SubjectExtension on Subject {
  Color get displayColor {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}
