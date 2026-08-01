import 'package:drift/drift.dart';

part 'database.g.dart';

/// 科目表
class Subjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get color => text().withLength(min: 1, max: 20).withDefault(const Constant('#2196F3'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  TextColumn get stage => text().withLength(min: 1, max: 20).withDefault(const Constant('high_school'))();
}

/// 易错点表
class Mistakes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get subjectId => integer().references(Subjects, #id)();
  TextColumn get chapter => text().withLength(max: 100).withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))(); // JSON 数组格式
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get nextReviewDate => dateTime().nullable()(); // 下次复习日期（艾宾浩斯）
  IntColumn get reviewCount => integer().withDefault(const Constant(0))();
  IntColumn get difficultyLevel => integer().withDefault(const Constant(1))(); // 1-5 难度等级
}

/// 易错点图片表
class MistakeImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mistakeId => integer().references(Mistakes, #id, onDelete: KeyAction.cascade)();
  TextColumn get imagePath => text()(); // 本地文件路径
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 学习记录表
class StudyRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().references(Subjects, #id)();
  DateTimeColumn get studyDate => dateTime()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))(); // 学习时长（分钟）
  IntColumn get mistakeCount => integer().withDefault(const Constant(0))(); // 当天记录的易错点数量
}

/// 复习记录表（记录每次复习的时间）
class ReviewRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mistakeId => integer().references(Mistakes, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get reviewDate => dateTime().withDefault(currentDateAndTime)();
  IntColumn get reviewInterval => integer().withDefault(const Constant(1))(); // 复习间隔（天）
}

/// 课程表
class ClassSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekday => integer()(); // 1-7，周一到周日
  TextColumn get startTime => text()(); // HH:mm 格式
  TextColumn get endTime => text()(); // HH:mm 格式
  TextColumn get location => text().withDefault(const Constant(''))();
  TextColumn get color => text().nullable()(); // 可选自定义颜色
}

/// 学习计划表
class StudyPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get subjectId => integer().nullable()(); // 可选关联科目
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  IntColumn get targetHours => integer().withDefault(const Constant(0))(); // 目标学习小时数
  IntColumn get completedHours => integer().withDefault(const Constant(0))(); // 已完成小时数（分钟存储，界面转换）
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending/in_progress/completed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 番茄钟记录表
class PomodoroRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get subjectId => integer().nullable()(); // 可选关联科目
  IntColumn get planId => integer().nullable()(); // 可选关联学习计划
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  IntColumn get duration => integer()(); // 持续时长（分钟）
  TextColumn get type => text().withDefault(const Constant('focus'))(); // focus/short_break/long_break
  BoolColumn get completed => boolean().withDefault(const Constant(true))();
}

@DriftDatabase(tables: [Subjects, Mistakes, MistakeImages, StudyRecords, ReviewRecords, ClassSchedules, StudyPlans, PomodoroRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // v1 -> v2: 添加课程表、学习计划、番茄钟记录表
        await m.createTable(classSchedules);
        await m.createTable(studyPlans);
        await m.createTable(pomodoroRecords);
      }
    },
  );
}
