# whk-learn 日程与日历模块功能实现详情 (2026-08-02)

## 一、理想时间表独立化改造
1. 数据库逻辑：DailySchedules表中ideal类型条目增加date字段区分，无需修改表结构，仅调整查询逻辑
2. 数据库服务变更：
   - `getIdealSchedules()` 改名为 `getIdealSchedulesByDate(DateTime date)`
   - `addIdealSchedule()` 新增必填date参数
   - 永久删除迁移类方法 `migrateIdealToActual`、`migrateAllIdealToActual`
3. 页面变更：
   - 理想时间表Tab随选中日期同步切换，使用FutureProvider.family按日期获取数据
   - 移除所有"迁移到实际"相关按钮、提示和逻辑

## 二、实际时间表编辑功能完善
- 实际时间表卡片支持点击弹出编辑对话框，可修改时间、标题、备注
- 保留原左滑删除功能，操作体验与理想时间表完全对齐

## 三、课程表新增日历全功能
1. 数据库升级到v5，新增CalendarEvents表，支持两种事项类型：
   - 长期安排：周几重复、起止时间
   - 时间点事项：具体日期+时间
   - 支持自定义提前提醒分钟数
2. 页面实现：
   - TabBar切换"课程表"（原有周视图）和"日历"两个视图
   - 月历使用Flutter内置GridView实现，不引入第三方日历依赖
   - 支持事项的增删改查，日期点击查看当日所有事项
3. 提醒功能：
   - 基于已有的flutter_local_notifications实现本地通知
   - 应用启动时自动调度所有待提醒事项，到达时间时弹窗/通知提醒
4. 技术约束：全程未引入新依赖，支持深浅色模式，通过flutter analyze校验
