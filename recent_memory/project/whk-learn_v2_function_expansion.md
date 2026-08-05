# whk-learn Flutter项目 v2 功能扩展详情
## 完成时间
2026-08-02
## 扩展内容
为原有study_helper学习辅助项目新增三大功能模块：课程表、学习计划、番茄钟计时，联动学习统计。
### 修改文件清单
1. lib/models/database.dart：新增class_schedules、study_plans、pomodoro_records三张数据库表，schemaVersion升级到2，添加migration.onUpgrade v1→v2迁移逻辑
2. lib/services/database_service.dart：新增300+行CRUD与统计查询方法，覆盖新表全量操作、今日学习时长统计、科目分布统计、连续打卡天数统计、学习时长趋势统计
3. lib/app.dart：使用StatefulShellRoute.indexedStack实现4-tab底部导航（首页/易错点/课程表/学习计划），新增所有新页面路由配置
4. lib/screens/home/home_screen.dart：快捷操作从3个扩展为6个，新增番茄钟、课程表、学习计划快速入口
5. lib/screens/statistics/statistics_screen.dart：新增今日学习时长卡片、科目学习分布饼图、学习时长趋势图、连续打卡天数统计模块，保留原有易错点统计
### 新增文件清单
1. lib/screens/schedule/schedule_screen.dart：535行，周视图课程表页面，支持课程增删改、跳转对应科目易错点
2. lib/screens/plans/plans_screen.dart：661行，学习计划分组列表页面，按状态分组展示，带进度条，支持计划增删改、查看关联番茄钟记录
3. lib/screens/pomodoro/pomodoro_screen.dart：582行，番茄钟计时器页面，支持专注/短休息/长休息三种模式，基于DateTime差值实现后台持续计时，无需依赖Timer持续运行，完成自动写入记录
### 约束遵守情况
全程使用已有依赖包drift、fl_chart、flutter_riverpod、go_router、intl，未引入任何新依赖
### 编译注意事项
修改database.dart后必须先执行flutter pub run build_runner build --delete-conflicting-outputs重新生成database.g.dart，才可正常编译运行
