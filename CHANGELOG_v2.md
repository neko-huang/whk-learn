# whk-learn Flutter 项目功能扩展 - 修改说明

## 新增功能

### 1. 课程表模块
- **新增文件**: `lib/screens/schedule/schedule_screen.dart`
- 周视图展示课程，支持切换星期
- 添加/编辑/删除课程（科目、时间、地点）
- 点击课程可跳转对应科目易错点
- 底部导航第3个tab

### 2. 学习计划模块
- **新增文件**: `lib/screens/plans/plans_screen.dart`
- Tab分组展示（进行中/待开始/已完成）
- 创建/编辑/删除计划，可关联科目
- 进度条展示（已完成时长/目标时长）
- 计划详情弹窗，显示关联的番茄钟记录
- 底部导航第4个tab

### 3. 番茄钟计时模块
- **新增文件**: `lib/screens/pomodoro/pomodoro_screen.dart`
- 三种模式：专注(25min)、短休息(5min)、长休息(15min)
- 圆形进度条+大数字时间显示
- 开始/暂停/重置控制
- 可选关联科目和学习计划
- 基于 DateTime 计算，支持后台计时
- 完成自动记录到数据库
- 首页快捷入口

### 4. 学习统计增强
- **修改文件**: `lib/screens/statistics/statistics_screen.dart`
- 新增"今日学习"卡片（学习时长、番茄数、连续打卡天数）
- 新增"学习时长趋势"柱状图（7天）
- 新增"科目学习时间"饼图（从番茄钟记录统计）
- 保留原有易错点统计

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `lib/models/database.dart` | 新增3张表（class_schedules, study_plans, pomodoro_records），schemaVersion→2，添加migration逻辑 |
| `lib/services/database_service.dart` | 新增课程表/学习计划/番茄钟的CRUD方法，新增统计查询方法 |
| `lib/app.dart` | 使用StatefulShellRoute实现底部导航栏（4个tab），新增路由 |
| `lib/screens/home/home_screen.dart` | 快捷操作区新增番茄钟、课程表、学习计划入口 |
| `lib/screens/statistics/statistics_screen.dart` | 新增番茄钟相关统计卡片和图表 |

## 新增文件

| 文件 | 说明 |
|------|------|
| `lib/screens/schedule/schedule_screen.dart` | 课程表页面 |
| `lib/screens/plans/plans_screen.dart` | 学习计划页面 |
| `lib/screens/pomodoro/pomodoro_screen.dart` | 番茄钟页面 |

## 底部导航结构

```
[首页] [易错点] [课程表] [学习计划]
```

独立页面（不在底部导航）：统计、设置、番茄钟、易错点详情

## 数据库迁移

- `schemaVersion`: 1 → 2
- 新增表：`class_schedules`、`study_plans`、`pomodoro_records`
- 迁移逻辑在 `onUpgrade` 中，v1→v2 自动创建新表

## 编译说明

修改 `database.dart` 后需运行代码生成以更新 `database.g.dart`：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

之后即可正常编译运行。
