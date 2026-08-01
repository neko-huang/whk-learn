import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/database.dart';
import '../models/mistake.dart';

/// 数据库服务 - 管理数据库连接和提供 CRUD 操作
class DatabaseService {
  static AppDatabase? _database;

  static Future<AppDatabase> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<AppDatabase> _initDatabase() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'study_helper.db'));

    // 确保目录存在
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final db = AppDatabase(NativeDatabase.createInBackground(file));
    
    // 初始化默认科目（仅首次启动时）
    await _initDefaultSubjects(db);
    
    return db;
  }

  /// 获取各学段的默认科目
  static List<Map<String, dynamic>> getDefaultSubjectsForStage(String stage) {
    switch (stage) {
      case 'junior':
        return [
          {'name': '语文', 'color': '#F44336', 'order': 1},
          {'name': '数学', 'color': '#2196F3', 'order': 2},
          {'name': '英语', 'color': '#4CAF50', 'order': 3},
          {'name': '物理', 'color': '#FF9800', 'order': 4},
          {'name': '化学', 'color': '#9C27B0', 'order': 5},
          {'name': '生物', 'color': '#8BC34A', 'order': 6},
          {'name': '政治', 'color': '#795548', 'order': 7},
          {'name': '历史', 'color': '#607D8B', 'order': 8},
          {'name': '地理', 'color': '#00BCD4', 'order': 9},
        ];
      case 'college':
        return [
          {'name': '高等数学', 'color': '#2196F3', 'order': 1},
          {'name': '线性代数', 'color': '#4CAF50', 'order': 2},
          {'name': '概率论', 'color': '#FF9800', 'order': 3},
          {'name': '大学物理', 'color': '#9C27B0', 'order': 4},
          {'name': '英语', 'color': '#F44336', 'order': 5},
          {'name': '专业课', 'color': '#00BCD4', 'order': 6},
          {'name': '政治', 'color': '#795548', 'order': 7},
        ];
      case 'high_school':
      default:
        return [
          {'name': '语文', 'color': '#F44336', 'order': 1},
          {'name': '数学', 'color': '#2196F3', 'order': 2},
          {'name': '英语', 'color': '#4CAF50', 'order': 3},
          {'name': '物理', 'color': '#FF9800', 'order': 4},
          {'name': '化学', 'color': '#9C27B0', 'order': 5},
          {'name': '生物', 'color': '#8BC34A', 'order': 6},
          {'name': '政治', 'color': '#795548', 'order': 7},
          {'name': '历史', 'color': '#607D8B', 'order': 8},
          {'name': '地理', 'color': '#00BCD4', 'order': 9},
        ];
    }
  }

  /// 初始化默认科目
  static Future<void> _initDefaultSubjects(AppDatabase db) async {
    final count = await db.select(db.subjects).get();
    if (count.isNotEmpty) return; // 已有数据，跳过

    final defaultSubjects = getDefaultSubjectsForStage('high_school');

    for (final s in defaultSubjects) {
      await db.into(db.subjects).insert(
        SubjectsCompanion.insert(
          name: s['name'] as String,
          color: Value(s['color'] as String),
          sortOrder: Value(s['order'] as int),
          stage: Value('high_school'),
        ),
      );
    }
  }

  /// 关闭数据库
  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ==================== 科目相关操作 ====================

  /// 获取所有可见科目（按学段过滤）
  static Future<List<Subject>> getVisibleSubjects({String? stage}) async {
    final db = await database;
    final query = db.select(db.subjects)
      ..where((t) => t.isVisible.equals(true));
    if (stage != null) {
      query.where((t) => t.stage.equals(stage));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return await query.get();
  }

  /// 获取所有科目（包括隐藏的）
  static Future<List<Subject>> getAllSubjects() async {
    final db = await database;
    return await (db.select(db.subjects)
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
    ).get();
  }

  /// 添加自定义科目
  static Future<int> addSubject(String name, String color, {String stage = 'high_school'}) async {
    final db = await database;
    final maxOrder = await db.select(db.subjects).get();
    final nextOrder = maxOrder.isEmpty ? 1 : maxOrder.last.sortOrder + 1;
    
    return await db.into(db.subjects).insert(
      SubjectsCompanion.insert(
        name: name,
        color: Value(color),
        sortOrder: Value(nextOrder),
        stage: Value(stage),
      ),
    );
  }

  /// 切换学段 - 隐藏当前学段科目，初始化新学段默认科目
  static Future<void> switchStage(String newStage) async {
    final db = await database;

    // 隐藏所有当前可见科目
    final visible = await (db.select(db.subjects)
      ..where((t) => t.isVisible.equals(true))
    ).get();
    for (final s in visible) {
      await (db.update(db.subjects)..where((t) => t.id.equals(s.id))).write(
        const SubjectsCompanion(isVisible: Value(false)),
      );
    }

    // 检查新学段是否已有科目
    final existing = await (db.select(db.subjects)
      ..where((t) => t.stage.equals(newStage) & t.isVisible.equals(true))
    ).get();

    if (existing.isEmpty) {
      // 尝试恢复该学段已有的隐藏科目
      final hiddenForStage = await (db.select(db.subjects)
        ..where((t) => t.stage.equals(newStage) & t.isVisible.equals(false))
      ).get();

      if (hiddenForStage.isNotEmpty) {
        for (final s in hiddenForStage) {
          await (db.update(db.subjects)..where((t) => t.id.equals(s.id))).write(
            const SubjectsCompanion(isVisible: Value(true)),
          );
        }
      } else {
        // 插入新学段的默认科目
        final defaults = getDefaultSubjectsForStage(newStage);
        for (final item in defaults) {
          await db.into(db.subjects).insert(
            SubjectsCompanion.insert(
              name: item['name'] as String,
              color: Value(item['color'] as String),
              sortOrder: Value(item['order'] as int),
              stage: Value(newStage),
            ),
          );
        }
      }
    }
  }

  // ==================== 易错点相关操作 ====================

  /// 添加易错点
  static Future<int> addMistake({
    required String title,
    required int subjectId,
    String description = '',
    String chapter = '',
    String tags = '',
    int difficultyLevel = 1,
  }) async {
    final db = await database;
    final now = DateTime.now();
    
    return await db.into(db.mistakes).insert(
      MistakesCompanion.insert(
        title: title,
        description: Value(description),
        subjectId: subjectId,
        chapter: Value(chapter),
        tags: Value(tags),
        createdAt: Value(now),
        updatedAt: Value(now),
        difficultyLevel: Value(difficultyLevel),
        reviewCount: const Value(0),
      ),
    );
  }

  /// 添加图片到易错点
  static Future<int> addMistakeImage(int mistakeId, String imagePath, int sortOrder) async {
    final db = await database;
    return await db.into(db.mistakeImages).insert(
      MistakeImagesCompanion.insert(
        mistakeId: mistakeId,
        imagePath: imagePath,
        sortOrder: Value(sortOrder),
      ),
    );
  }

  /// 获取易错点列表（带科目信息）
  static Future<List<MistakeWithSubject>> getMistakes({
    int? subjectId,
    String? searchKeyword,
    bool? needsReview,
  }) async {
    final db = await database;

    // 构建查询
    var query = db.select(db.mistakes).join([
      innerJoin(db.subjects, db.subjects.id.equalsExp(db.mistakes.subjectId)),
    ]);

    // 应用筛选条件
    if (subjectId != null) {
      query.where(db.mistakes.subjectId.equals(subjectId));
    }
    if (searchKeyword != null && searchKeyword.isNotEmpty) {
      query.where(
        db.mistakes.title.contains(searchKeyword) |
        db.mistakes.description.contains(searchKeyword) |
        db.mistakes.tags.contains(searchKeyword),
      );
    }
    if (needsReview != null && needsReview) {
      query.where(
        db.mistakes.nextReviewDate.isNull() |
        db.mistakes.nextReviewDate.isSmallerThanValue(DateTime.now()),
      );
    }

    // 排序：按更新时间倒序
    query.orderBy([OrderingTerm.desc(db.mistakes.updatedAt)]);

    final rows = await query.get();
    
    // 构建结果
    final results = <MistakeWithSubject>[];
    for (final row in rows) {
      final mistake = row.readTable(db.mistakes);
      final subject = row.readTable(db.subjects);
      
      // 获取图片
      final images = await (db.select(db.mistakeImages)
        ..where((t) => t.mistakeId.equals(mistake.id))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
      ).get();
      
      results.add(MistakeWithSubject(
        mistake: mistake,
        subject: subject,
        images: images,
      ));
    }
    
    return results;
  }

  /// 获取单个易错点详情
  static Future<MistakeWithSubject?> getMistakeById(int id) async {
    final db = await database;
    
    final mistake = await (db.select(db.mistakes)
      ..where((t) => t.id.equals(id))
    ).getSingleOrNull();
    
    if (mistake == null) return null;
    
    final subject = await (db.select(db.subjects)
      ..where((t) => t.id.equals(mistake.subjectId))
    ).getSingle();
    
    final images = await (db.select(db.mistakeImages)
      ..where((t) => t.mistakeId.equals(mistake.id))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
    ).get();
    
    return MistakeWithSubject(
      mistake: mistake,
      subject: subject,
      images: images,
    );
  }

  /// 更新易错点
  static Future<bool> updateMistake(int id, {
    String? title,
    String? description,
    int? subjectId,
    String? chapter,
    String? tags,
    int? difficultyLevel,
    DateTime? nextReviewDate,
    int? reviewCount,
  }) async {
    final db = await database;
    
    return await (db.update(db.mistakes)..where((t) => t.id.equals(id))).write(
      MistakesCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        subjectId: subjectId != null ? Value(subjectId) : const Value.absent(),
        chapter: chapter != null ? Value(chapter) : const Value.absent(),
        tags: tags != null ? Value(tags) : const Value.absent(),
        difficultyLevel: difficultyLevel != null ? Value(difficultyLevel) : const Value.absent(),
        nextReviewDate: nextReviewDate != null ? Value(nextReviewDate) : const Value.absent(),
        reviewCount: reviewCount != null ? Value(reviewCount) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    ) > 0;
  }

  /// 删除易错点
  static Future<bool> deleteMistake(int id) async {
    final db = await database;
    return await (db.delete(db.mistakes)..where((t) => t.id.equals(id))).go() > 0;
  }

  /// 删除图片
  static Future<bool> deleteMistakeImage(int imageId) async {
    final db = await database;
    final image = await (db.select(db.mistakeImages)
      ..where((t) => t.id.equals(imageId))
    ).getSingleOrNull();
    
    if (image != null) {
      // 删除文件
      final file = File(image.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    return await (db.delete(db.mistakeImages)..where((t) => t.id.equals(imageId))).go() > 0;
  }

  // ==================== 复习记录相关操作 ====================

  /// 插入复习记录
  static Future<int> addReviewRecord({
    required int mistakeId,
    int reviewInterval = 1,
  }) async {
    final db = await database;
    return await db.into(db.reviewRecords).insert(
      ReviewRecordsCompanion.insert(
        mistakeId: mistakeId,
        reviewInterval: Value(reviewInterval),
      ),
    );
  }

  /// 获取某易错点的复习历史
  static Future<List<ReviewRecord>> getReviewHistory(int mistakeId) async {
    final db = await database;
    return await (db.select(db.reviewRecords)
      ..where((t) => t.mistakeId.equals(mistakeId))
      ..orderBy([(t) => OrderingTerm.desc(t.reviewDate)])
    ).get();
  }

  /// 获取需要复习的易错点数量
  static Future<int> getReviewCount() async {
    final db = await database;
    final now = DateTime.now();
    
    return await (db.select(db.mistakes)
      ..where((t) => t.nextReviewDate.isNull() | t.nextReviewDate.isSmallerThanValue(now))
    ).get().then((list) => list.length);
  }

  /// 获取今日统计
  static Future<Map<String, int>> getTodayStats() async {
    final db = await database;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    // 今日新增易错点
    final todayMistakes = await (db.select(db.mistakes)
      ..where((t) => t.createdAt.isBiggerOrEqualValue(todayStart) & t.createdAt.isSmallerThanValue(todayEnd))
    ).get();
    
    // 今日待复习
    final reviewCount = await getReviewCount();
    
    return {
      'newMistakes': todayMistakes.length,
      'reviewCount': reviewCount,
      'totalMistakes': await db.select(db.mistakes).get().then((l) => l.length),
    };
  }

  // ==================== 课程表相关操作 ====================

  /// 获取所有课程安排
  static Future<List<ClassSchedule>> getAllSchedules() async {
    final db = await database;
    return await (db.select(db.classSchedules)
      ..orderBy([(t) => OrderingTerm.asc(t.weekday)])
    ).get();
  }

  /// 获取指定星期的课程安排
  static Future<List<ClassSchedule>> getSchedulesByWeekday(int weekday) async {
    final db = await database;
    return await (db.select(db.classSchedules)
      ..where((t) => t.weekday.equals(weekday))
      ..orderBy([(t) => OrderingTerm.asc(t.startTime)])
    ).get();
  }

  /// 添加课程安排
  static Future<int> addSchedule({
    required int subjectId,
    required int weekday,
    required String startTime,
    required String endTime,
    String location = '',
    String? color,
  }) async {
    final db = await database;
    return await db.into(db.classSchedules).insert(
      ClassSchedulesCompanion.insert(
        subjectId: subjectId,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
        location: Value(location),
        color: Value(color),
      ),
    );
  }

  /// 更新课程安排
  static Future<bool> updateSchedule(int id, {
    int? subjectId,
    int? weekday,
    String? startTime,
    String? endTime,
    String? location,
    String? color,
  }) async {
    final db = await database;
    return await (db.update(db.classSchedules)..where((t) => t.id.equals(id))).write(
      ClassSchedulesCompanion(
        subjectId: subjectId != null ? Value(subjectId) : const Value.absent(),
        weekday: weekday != null ? Value(weekday) : const Value.absent(),
        startTime: startTime != null ? Value(startTime) : const Value.absent(),
        endTime: endTime != null ? Value(endTime) : const Value.absent(),
        location: location != null ? Value(location) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
      ),
    ) > 0;
  }

  /// 删除课程安排
  static Future<bool> deleteSchedule(int id) async {
    final db = await database;
    return await (db.delete(db.classSchedules)..where((t) => t.id.equals(id))).go() > 0;
  }

  /// 获取课程安排带科目信息
  static Future<List<Map<String, dynamic>>> getSchedulesWithSubject() async {
    final schedules = await getAllSchedules();
    final subjects = await getAllSubjects();
    final subjectMap = {for (var s in subjects) s.id: s};

    return schedules.map((s) => {
      'schedule': s,
      'subject': subjectMap[s.subjectId],
    }).toList();
  }

  // ==================== 学习计划相关操作 ====================

  /// 获取所有学习计划
  static Future<List<StudyPlan>> getAllStudyPlans() async {
    final db = await database;
    return await (db.select(db.studyPlans)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
    ).get();
  }

  /// 按状态获取学习计划
  static Future<List<StudyPlan>> getStudyPlansByStatus(String status) async {
    final db = await database;
    return await (db.select(db.studyPlans)
      ..where((t) => t.status.equals(status))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
    ).get();
  }

  /// 添加学习计划
  static Future<int> addStudyPlan({
    required String title,
    String description = '',
    int? subjectId,
    required DateTime startDate,
    required DateTime endDate,
    int targetHours = 0,
    String status = 'pending',
  }) async {
    final db = await database;
    return await db.into(db.studyPlans).insert(
      StudyPlansCompanion.insert(
        title: title,
        description: Value(description),
        subjectId: subjectId != null ? Value(subjectId) : const Value.absent(),
        startDate: startDate,
        endDate: endDate,
        targetHours: Value(targetHours),
        completedHours: const Value(0),
        status: Value(status),
      ),
    );
  }

  /// 更新学习计划
  static Future<bool> updateStudyPlan(int id, {
    String? title,
    String? description,
    int? subjectId,
    DateTime? startDate,
    DateTime? endDate,
    int? targetHours,
    int? completedHours,
    String? status,
  }) async {
    final db = await database;
    return await (db.update(db.studyPlans)..where((t) => t.id.equals(id))).write(
      StudyPlansCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        subjectId: subjectId != null ? Value(subjectId) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
        endDate: endDate != null ? Value(endDate) : const Value.absent(),
        targetHours: targetHours != null ? Value(targetHours) : const Value.absent(),
        completedHours: completedHours != null ? Value(completedHours) : const Value.absent(),
        status: status != null ? Value(status) : const Value.absent(),
      ),
    ) > 0;
  }

  /// 删除学习计划
  static Future<bool> deleteStudyPlan(int id) async {
    final db = await database;
    return await (db.delete(db.studyPlans)..where((t) => t.id.equals(id))).go() > 0;
  }

  /// 获取学习计划带科目信息
  static Future<List<Map<String, dynamic>>> getStudyPlansWithSubject() async {
    final db = await database;
    final plans = await getAllStudyPlans();
    final subjects = await getAllSubjects();
    final subjectMap = {for (var s in subjects) s.id: s};

    return plans.map((p) => {
      'plan': p,
      'subject': p.subjectId != null ? subjectMap[p.subjectId] : null,
    }).toList();
  }

  // ==================== 番茄钟相关操作 ====================

  /// 添加番茄钟记录
  static Future<int> addPomodoroRecord({
    int? subjectId,
    int? planId,
    required DateTime startTime,
    required DateTime endTime,
    required int duration,
    String type = 'focus',
    bool completed = true,
  }) async {
    final db = await database;
    return await db.into(db.pomodoroRecords).insert(
      PomodoroRecordsCompanion.insert(
        subjectId: subjectId != null ? Value(subjectId) : const Value.absent(),
        planId: planId != null ? Value(planId) : const Value.absent(),
        startTime: startTime,
        endTime: endTime,
        duration: duration,
        type: Value(type),
        completed: Value(completed),
      ),
    );
  }

  /// 获取今日番茄钟记录
  static Future<List<PomodoroRecord>> getTodayPomodoroRecords() async {
    final db = await database;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return await (db.select(db.pomodoroRecords)
      ..where((t) => t.startTime.isBiggerOrEqualValue(todayStart) & t.startTime.isSmallerThanValue(todayEnd))
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)])
    ).get();
  }

  /// 获取今日已完成番茄钟数量（focus + focus_mode 类型）
  static Future<int> getTodayPomodoroCount() async {
    final db = await database;
    final records = await getTodayPomodoroRecords();
    return records.where((r) => (r.type == 'focus' || r.type == 'focus_mode') && r.completed).length;
  }

  /// 获取今日学习时长（分钟，从 pomodoro_records 计算，包含 focus + focus_mode）
  static Future<int> getTodayStudyMinutes() async {
    final db = await database;
    final records = await getTodayPomodoroRecords();
    final totalMinutes = records
        .where((r) => (r.type == 'focus' || r.type == 'focus_mode') && r.completed)
        .fold<int>(0, (sum, r) => sum + r.duration);
    return totalMinutes;
  }

  /// 获取各科目学习时长分布（从 pomodoro_records 按科目统计，包含 focus + focus_mode）
  static Future<Map<int, int>> getSubjectStudyDistribution() async {
    final db = await database;
    final records = await (db.select(db.pomodoroRecords)
      ..where((t) =>
          (t.type.equals('focus') | t.type.equals('focus_mode')) &
          t.completed.equals(true))
    ).get();

    Map<int, int> distribution = {};
    for (final record in records) {
      if (record.subjectId != null) {
        distribution[record.subjectId!] = (distribution[record.subjectId!] ?? 0) + record.duration;
      }
    }
    return distribution;
  }

  /// 获取连续打卡天数（从 pomodoro_records 计算连续有学习记录的天数，包含 focus + focus_mode）
  static Future<int> getStudyStreak() async {
    final db = await database;
    final records = await (db.select(db.pomodoroRecords)
      ..where((t) =>
          (t.type.equals('focus') | t.type.equals('focus_mode')) &
          t.completed.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)])
    ).get();

    if (records.isEmpty) return 0;

    // 提取所有有学习记录的日期（去重）
    final studyDates = <DateTime>{};
    for (final record in records) {
      studyDates.add(DateTime(record.startTime.year, record.startTime.month, record.startTime.day));
    }

    // 从昨天或今天开始计算连续天数
    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);
    
    // 如果今天没有记录，从昨天开始检查
    if (!studyDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (!studyDates.contains(checkDate)) return 0;
    }

    int streak = 0;
    while (studyDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// 获取指定学习计划的番茄钟记录
  static Future<List<PomodoroRecord>> getPomodoroRecordsByPlan(int planId) async {
    final db = await database;
    return await (db.select(db.pomodoroRecords)
      ..where((t) => t.planId.equals(planId))
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)])
    ).get();
  }

  /// 获取某学习计划已完成的学习时长（分钟）
  static Future<int> getPlanCompletedMinutes(int planId) async {
    final db = await database;
    final records = await (db.select(db.pomodoroRecords)
      ..where((t) => t.planId.equals(planId) & t.type.equals('focus') & t.completed.equals(true))
    ).get();
    return records.fold<int>(0, (sum, r) => sum + r.duration);
  }

  /// 获取最近7天每日学习时长
  static Future<List<MapEntry<DateTime, int>>> getDailyStudyMinutes(int days) async {
    final db = await database;
    final now = DateTime.now();
    final List<MapEntry<DateTime, int>> dailyMinutes = [];

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final records = await (db.select(db.pomodoroRecords)
        ..where((t) => t.startTime.isBiggerOrEqualValue(dayStart) & 
                       t.startTime.isSmallerThanValue(dayEnd) & 
                       (t.type.equals('focus') | t.type.equals('focus_mode')) & 
                       t.completed.equals(true))
      ).get();

      final totalMinutes = records.fold<int>(0, (sum, r) => sum + r.duration);
      dailyMinutes.add(MapEntry(dayStart, totalMinutes));
    }

    return dailyMinutes;
  }

  // ==================== 每日时间安排相关操作 ====================

  /// 获取指定日期的安排（按时间排序）
  static Future<List<DailySchedule>> getDailySchedulesByDate(DateTime date) async {
    final db = await database;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return await (db.select(db.dailySchedules)
      ..where((t) => t.date.equals(normalizedDate))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.startTime)])
    ).get();
  }

  /// 添加安排项
  static Future<int> addDailySchedule({
    required DateTime date,
    required String startTime,
    required String endTime,
    required String title,
    String note = '',
    int sortOrder = 0,
  }) async {
    final db = await database;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return await db.into(db.dailySchedules).insert(
      DailySchedulesCompanion.insert(
        date: normalizedDate,
        startTime: startTime,
        endTime: endTime,
        title: title,
        note: Value(note),
        sortOrder: Value(sortOrder),
      ),
    );
  }

  /// 更新安排项
  static Future<bool> updateDailySchedule(int id, {
    String? startTime,
    String? endTime,
    String? title,
    String? note,
    int? sortOrder,
  }) async {
    final db = await database;
    return await (db.update(db.dailySchedules)..where((t) => t.id.equals(id))).write(
      DailySchedulesCompanion(
        startTime: startTime != null ? Value(startTime) : const Value.absent(),
        endTime: endTime != null ? Value(endTime) : const Value.absent(),
        title: title != null ? Value(title) : const Value.absent(),
        note: note != null ? Value(note) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
      ),
    ) > 0;
  }

  /// 删除安排项
  static Future<bool> deleteDailySchedule(int id) async {
    final db = await database;
    return await (db.delete(db.dailySchedules)..where((t) => t.id.equals(id))).go() > 0;
  }

  /// 检查是否需要归档（当前日期与上次活跃日期不同时触发）
  /// 保留旧数据不做删除，仅更新 lastActiveDate
  static Future<void> archiveAndResetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastActiveStr = prefs.getString('lastActiveDate');

    if (lastActiveStr != null) {
      final lastActive = DateTime.tryParse(lastActiveStr);
      if (lastActive != null && _isSameDay(lastActive, today)) {
        return; // 同一天，无需归档
      }
    }

    // 不同日期，更新 lastActiveDate（旧数据保留在数据库中，不删除）
    await prefs.setString('lastActiveDate', today.toIso8601String());
  }

  /// 获取上次活跃日期
  static Future<DateTime?> getLastActiveDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActiveStr = prefs.getString('lastActiveDate');
    if (lastActiveStr == null) return null;
    return DateTime.tryParse(lastActiveStr);
  }

  /// 判断两个日期是否同一天
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 获取今日专注模式完成次数
  static Future<int> getTodayFocusModeCount() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final records = await (db.select(db.pomodoroRecords)
      ..where((t) => t.type.equals('focus_mode') &
                     t.completed.equals(true) &
                     t.startTime.isBiggerOrEqualValue(todayStart) &
                     t.startTime.isSmallerThanValue(todayEnd))
    ).get();
    return records.length;
  }

  /// 获取今日日程数量
  static Future<int> getTodayDailyScheduleCount() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final schedules = await getDailySchedulesByDate(today);
    return schedules.length;
  }
}
