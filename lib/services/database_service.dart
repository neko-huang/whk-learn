import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'database.dart';

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

    // 在移动端使用 sqlite3_flutter_libs 提供的原生库
    await applyWorkaroundToOpenDb();

    final db = AppDatabase(file);
    
    // 初始化默认科目（仅首次启动时）
    await _initDefaultSubjects(db);
    
    return db;
  }

  /// 初始化默认科目
  static Future<void> _initDefaultSubjects(AppDatabase db) async {
    final count = await db.select(db.subjects).get();
    if (count.isNotEmpty) return; // 已有数据，跳过

    final defaultSubjects = [
      SubjectsCompanion.insert(name: '语文', color: '#F44336', sortOrder: 1),
      SubjectsCompanion.insert(name: '数学', color: '#2196F3', sortOrder: 2),
      SubjectsCompanion.insert(name: '英语', color: '#4CAF50', sortOrder: 3),
      SubjectsCompanion.insert(name: '物理', color: '#FF9800', sortOrder: 4),
      SubjectsCompanion.insert(name: '化学', color: '#9C27B0', sortOrder: 5),
      SubjectsCompanion.insert(name: '生物', color: '#8BC34A', sortOrder: 6),
      SubjectsCompanion.insert(name: '政治', color: '#795548', sortOrder: 7),
      SubjectsCompanion.insert(name: '历史', color: '#607D8B', sortOrder: 8),
      SubjectsCompanion.insert(name: '地理', color: '#00BCD4', sortOrder: 9),
    ];

    for (final subject in defaultSubjects) {
      await db.into(db.subjects).insert(subject);
    }
  }

  /// 关闭数据库
  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ==================== 科目相关操作 ====================

  /// 获取所有可见科目
  static Future<List<Subject>> getVisibleSubjects() async {
    final db = await database;
    return await (db.select(db.subjects)
      ..where((t) => t.isVisible.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
    ).get();
  }

  /// 获取所有科目（包括隐藏的）
  static Future<List<Subject>> getAllSubjects() async {
    final db = await database;
    return await (db.select(db.subjects)
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
    ).get();
  }

  /// 添加自定义科目
  static Future<int> addSubject(String name, String color) async {
    final db = await database;
    final maxOrder = await db.select(db.subjects).get();
    final nextOrder = maxOrder.isEmpty ? 1 : maxOrder.last.sortOrder + 1;
    
    return await db.into(db.subjects).insert(
      SubjectsCompanion.insert(name: name, color: color, sortOrder: nextOrder),
    );
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
        sortOrder: sortOrder,
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
    return await (db.delete(db.mistakes)..where((t) => t.id.equals(id))).get() > 0;
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
    
    return await (db.delete(db.mistakeImages)..where((t) => t.id.equals(imageId))).get() > 0;
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
}
