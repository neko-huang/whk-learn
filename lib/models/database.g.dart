// GENERATED CODE - DO NOT MODIFY BY HAND
// 此文件需要通过 `dart run build_runner build` 命令生成
// 请在项目目录下运行该命令完成数据库代码生成

part of 'database.dart';

// **************************************************************************
// Tables
// **************************************************************************

class $SubjectsTable extends Subjects with TableInfo<$SubjectsTable, Subject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  
  $SubjectsTable(this.attachedDatabase, [this._alias]);
  
  static const VerificationMeta _subjectIdMeta = VerificationMeta('id');
  @override
  final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultConstraints: 'PRIMARY KEY AUTOINCREMENT');
      
  static const VerificationMeta _nameMeta = VerificationMeta('name');
  @override
  final GeneratedColumn<String> name = GeneratedColumn<String>('name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true,
      $constraints: 'CHECK(LENGTH(name) >= 1 AND LENGTH(name) <= 50)');
      
  static const VerificationMeta _colorMeta = VerificationMeta('color');
  @override
  final GeneratedColumn<String> color = GeneratedColumn<String>('color', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: false, defaultValue: const Constant('#2196F3'),
      $constraints: 'CHECK(LENGTH(color) >= 1 AND LENGTH(color) <= 20)');
      
  static const VerificationMeta _sortOrderMeta = VerificationMeta('sortOrder');
  @override
  final GeneratedColumn<int> sortOrder = GeneratedColumn<int>('sort_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(0));
      
  static const VerificationMeta _isVisibleMeta = VerificationMeta('isVisible');
  @override
  final GeneratedColumn<bool> isVisible = GeneratedColumn<bool>('is_visible', aliasedName, false,
      type: DriftSqlType.bool, requiredDuringInsert: false, defaultValue: const Constant(true));
      
  static const VerificationMeta _stageMeta = VerificationMeta('stage');
  @override
  final GeneratedColumn<String> stage = GeneratedColumn<String>('stage', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: false, defaultValue: const Constant('high_school'),
      $constraints: 'CHECK(LENGTH(stage) >= 1 AND LENGTH(stage) <= 20)');

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subjects';
  
  @override
  VerificationContext validateIntegrity(Insertable<Subject> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance;
    context.setDataValidity(data);
    return context;
  }

  @override
  Set<GeneratedColumn> get $columns => {id, name, color, sortOrder, isVisible, stage};
  @override
  Set<GeneratedColumn<int>> get $autoIncrementColumns => {id};
  @override
  Subject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subject(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}color'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      isVisible: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_visible'])!,
      stage: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}stage'])!,
    );
  }

  @override
  $SubjectsTable createAlias(String alias) => $SubjectsTable(attachedDatabase, alias);
}

class Subject implements DataClass {
  final int id;
  final String name;
  final String color;
  final int sortOrder;
  final bool isVisible;
  final String stage;
  
  const Subject({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.isVisible,
    required this.stage,
  });
}

// 其他表的类似实现...
// 实际使用时需要运行 build_runner 自动生成完整代码

class $MistakesTable extends Mistakes with TableInfo<$MistakesTable, Mistake> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  
  $MistakesTable(this.attachedDatabase, [this._alias]);

  @override
  final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultConstraints: 'PRIMARY KEY AUTOINCREMENT');
  @override
  final GeneratedColumn<String> title = GeneratedColumn<String>('title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true,
      $constraints: 'CHECK(LENGTH(title) >= 1 AND LENGTH(title) <= 200)');
  @override
  final GeneratedColumn<String> description = GeneratedColumn<String>('description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: false, defaultValue: const Constant(''));
  @override
  final GeneratedColumn<int> subjectId = GeneratedColumn<int>('subject_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  final GeneratedColumn<String> chapter = GeneratedColumn<String>('chapter', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: false, defaultValue: const Constant(''),
      $constraints: 'CHECK(LENGTH(chapter) <= 100)');
  @override
  final GeneratedColumn<String> tags = GeneratedColumn<String>('tags', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: false, defaultValue: const Constant(''));
  @override
  final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>('created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: false, defaultValue: currentDateAndTime);
  @override
  final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>('updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: false, defaultValue: currentDateAndTime);
  @override
  final GeneratedColumn<DateTime?> nextReviewDate = GeneratedColumn<DateTime?>('next_review_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  final GeneratedColumn<int> reviewCount = GeneratedColumn<int>('review_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(0));
  @override
  final GeneratedColumn<int> difficultyLevel = GeneratedColumn<int>('difficulty_level', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(1));

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mistakes';

  @override
  Mistake map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mistake(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      subjectId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}subject_id'])!,
      chapter: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}chapter'])!,
      tags: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      nextReviewDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}next_review_date']),
      reviewCount: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}review_count'])!,
      difficultyLevel: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}difficulty_level'])!,
    );
  }

  @override
  $MistakesTable createAlias(String alias) => $MistakesTable(attachedDatabase, alias);

  @override
  Set<GeneratedColumn> get $columns => {id, title, description, subjectId, chapter, tags, createdAt, updatedAt, nextReviewDate, reviewCount, difficultyLevel};
  
  @override
  Set<GeneratedColumn<int>> get $autoIncrementColumns => {id};
}

class Mistake implements DataClass {
  final int id;
  final String title;
  final String description;
  final int subjectId;
  final String chapter;
  final String tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nextReviewDate;
  final int reviewCount;
  final int difficultyLevel;
  
  const Mistake({
    required this.id,
    required this.title,
    required this.description,
    required this.subjectId,
    required this.chapter,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.nextReviewDate,
    required this.reviewCount,
    required this.difficultyLevel,
  });

  bool get needsReview {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }
}

class $MistakeImagesTable extends MistakeImages with TableInfo<$MistakeImagesTable, MistakeImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  
  $MistakeImagesTable(this.attachedDatabase, [this._alias]);

  @override
  final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultConstraints: 'PRIMARY KEY AUTOINCREMENT');
  @override
  final GeneratedColumn<int> mistakeId = GeneratedColumn<int>('mistake_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  final GeneratedColumn<String> imagePath = GeneratedColumn<String>('image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  final GeneratedColumn<int> sortOrder = GeneratedColumn<int>('sort_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(0));
  @override
  final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>('created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: false, defaultValue: currentDateAndTime);

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mistake_images';

  @override
  MistakeImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MistakeImage(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mistakeId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}mistake_id'])!,
      imagePath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MistakeImagesTable createAlias(String alias) => $MistakeImagesTable(attachedDatabase, alias);

  @override
  Set<GeneratedColumn> get $columns => {id, mistakeId, imagePath, sortOrder, createdAt};
  
  @override
  Set<GeneratedColumn<int>> get $autoIncrementColumns => {id};
}

class MistakeImage implements DataClass {
  final int id;
  final int mistakeId;
  final String imagePath;
  final int sortOrder;
  final DateTime createdAt;
  
  const MistakeImage({
    required this.id,
    required this.mistakeId,
    required this.imagePath,
    required this.sortOrder,
    required this.createdAt,
  });
}

class $StudyRecordsTable extends StudyRecords with TableInfo<$StudyRecordsTable, StudyRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  
  $StudyRecordsTable(this.attachedDatabase, [this._alias]);

  @override
  final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultConstraints: 'PRIMARY KEY AUTOINCREMENT');
  @override
  final GeneratedColumn<int> subjectId = GeneratedColumn<int>('subject_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  final GeneratedColumn<DateTime> studyDate = GeneratedColumn<DateTime>('study_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>('duration_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(0));
  @override
  final GeneratedColumn<int> mistakeCount = GeneratedColumn<int>('mistake_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(0));

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_records';

  @override
  StudyRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyRecord(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      subjectId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}subject_id'])!,
      studyDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}study_date'])!,
      durationMinutes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}duration_minutes'])!,
      mistakeCount: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}mistake_count'])!,
    );
  }

  @override
  $StudyRecordsTable createAlias(String alias) => $StudyRecordsTable(attachedDatabase, alias);

  @override
  Set<GeneratedColumn> get $columns => {id, subjectId, studyDate, durationMinutes, mistakeCount};
  
  @override
  Set<GeneratedColumn<int>> get $autoIncrementColumns => {id};
}

class StudyRecord implements DataClass {
  final int id;
  final int subjectId;
  final DateTime studyDate;
  final int durationMinutes;
  final int mistakeCount;
  
  const StudyRecord({
    required this.id,
    required this.subjectId,
    required this.studyDate,
    required this.durationMinutes,
    required this.mistakeCount,
  });
}

class $ReviewRecordsTable extends ReviewRecords with TableInfo<$ReviewRecordsTable, ReviewRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  
  $ReviewRecordsTable(this.attachedDatabase, [this._alias]);

  @override
  final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultConstraints: 'PRIMARY KEY AUTOINCREMENT');
  @override
  final GeneratedColumn<int> mistakeId = GeneratedColumn<int>('mistake_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  final GeneratedColumn<DateTime> reviewDate = GeneratedColumn<DateTime>('review_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: false, defaultValue: currentDateAndTime);
  @override
  final GeneratedColumn<int> reviewInterval = GeneratedColumn<int>('review_interval', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const Constant(1));

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_records';

  @override
  ReviewRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewRecord(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mistakeId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}mistake_id'])!,
      reviewDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}review_date'])!,
      reviewInterval: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}review_interval'])!,
    );
  }

  @override
  $ReviewRecordsTable createAlias(String alias) => $ReviewRecordsTable(attachedDatabase, alias);

  @override
  Set<GeneratedColumn> get $columns => {id, mistakeId, reviewDate, reviewInterval};
  
  @override
  Set<GeneratedColumn<int>> get $autoIncrementColumns => {id};
}

class ReviewRecord implements DataClass {
  final int id;
  final int mistakeId;
  final DateTime reviewDate;
  final int reviewInterval;
  
  const ReviewRecord({
    required this.id,
    required this.mistakeId,
    required this.reviewDate,
    required this.reviewInterval,
  });
}

/// 伴随类（用于插入数据）
class SubjectsCompanion extends UpdateCompanion<Subject> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> color;
  final Value<int> sortOrder;
  final Value<bool> isVisible;
  final Value<String> stage;
  
  const SubjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.stage = const Value.absent(),
  });

  SubjectsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.stage = const Value.absent(),
  }) : name = Value(name);
}

class MistakesCompanion extends UpdateCompanion<Mistake> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> description;
  final Value<int> subjectId;
  final Value<String> chapter;
  final Value<String> tags;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> nextReviewDate;
  final Value<int> reviewCount;
  final Value<int> difficultyLevel;
  
  const MistakesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.chapter = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.nextReviewDate = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.difficultyLevel = const Value.absent(),
  });

  MistakesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    required int subjectId,
    this.chapter = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.nextReviewDate = const Value.absent(),
    this.reviewCount = const Value.absent(),
    this.difficultyLevel = const Value.absent(),
  }) : title = Value(title), subjectId = Value(subjectId);
}

class MistakeImagesCompanion extends UpdateCompanion<MistakeImage> {
  final Value<int> id;
  final Value<int> mistakeId;
  final Value<String> imagePath;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  
  const MistakeImagesCompanion({
    this.id = const Value.absent(),
    this.mistakeId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });

  MistakeImagesCompanion.insert({
    this.id = const Value.absent(),
    required int mistakeId,
    required String imagePath,
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : mistakeId = Value(mistakeId), imagePath = Value(imagePath);
}

/// 数据库主类
abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  
  late final $SubjectsTable subjects = $SubjectsTable(this);
  late final $MistakesTable mistakes = $MistakesTable(this);
  late final $MistakeImagesTable mistakeImages = $MistakeImagesTable(this);
  late final $StudyRecordsTable studyRecords = $StudyRecordsTable(this);
  late final $ReviewRecordsTable reviewRecords = $ReviewRecordsTable(this);
  
  @override
  Iterable<TableInfo<Table, Object?>?> get allTables => [
    subjects,
    mistakes,
    mistakeImages,
    studyRecords,
    reviewRecords,
  ];
}
