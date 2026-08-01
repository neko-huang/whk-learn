/// 艾宾浩斯遗忘曲线算法
/// 用于计算最佳的复习时间点
class SpacedRepetition {
  /// 艾宾浩斯间隔天数（经典曲线）
  /// 1天后、2天后、4天后、7天后、15天后
  static const List<int> intervals = [1, 2, 4, 7, 15];

  /// 根据复习次数计算下次复习日期
  /// [lastReviewDate] 上次复习时间
  /// [reviewCount] 已经复习过的次数（0表示第一次添加）
  /// [difficultyLevel] 难度等级 1-5，难度越高复习频率越高
  static DateTime getNextReviewDate({
    required DateTime lastReviewDate,
    required int reviewCount,
    int difficultyLevel = 1,
  }) {
    // 根据难度调整间隔
    // 难度越高，间隔越短
    double difficultyMultiplier = 1.0;
    switch (difficultyLevel) {
      case 1: // 简单
        difficultyMultiplier = 1.2;
        break;
      case 2:
        difficultyMultiplier = 1.0;
        break;
      case 3: // 中等
        difficultyMultiplier = 0.9;
        break;
      case 4: // 较难
        difficultyMultiplier = 0.7;
        break;
      case 5: // 很难
        difficultyMultiplier = 0.5;
        break;
      default:
        difficultyMultiplier = 1.0;
    }

    int intervalDays;
    if (reviewCount >= intervals.length) {
      // 超过预设间隔，使用最后一个间隔的倍数
      intervalDays = (intervals.last * difficultyMultiplier * 1.5).round();
    } else {
      intervalDays = (intervals[reviewCount] * difficultyMultiplier).round();
    }

    // 确保至少有1天间隔
    intervalDays = intervalDays < 1 ? 1 : intervalDays;

    return lastReviewDate.add(Duration(days: intervalDays));
  }

  /// 获取复习状态描述
  static String getReviewStatusDescription(DateTime? nextReviewDate) {
    if (nextReviewDate == null) {
      return '尚未设置复习计划';
    }

    final now = DateTime.now();
    final diff = nextReviewDate.difference(now);

    if (diff.isNegative) {
      final daysOverdue = -diff.inDays;
      if (daysOverdue == 0) {
        return '今天应该复习';
      }
      return '已逾期 $daysOverdue 天';
    }

    final days = diff.inDays;
    if (days == 0) {
      return '今天需要复习';
    } else if (days == 1) {
      return '明天需要复习';
    } else {
      return '$days 天后复习';
    }
  }

  /// 获取复习周期提示
  static List<String> getReviewSchedule() {
    return [
      '第1次：1天后',
      '第2次：2天后',
      '第3次：4天后',
      '第4次：7天后',
      '第5次：15天后',
    ];
  }
}
