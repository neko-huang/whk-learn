## 2026-08-02 study_helper Flutter项目改造记录
技术栈：Flutter+Riverpod+drift+go_router，无新增第三方依赖。

### 4项改造完成内容
1. **理想→实际日程迁移**（daily_schedule_screen.dart）：理想卡片菜单新增迁移选项，点击后复制数据生成actual类型实际安排，成功后刷新两个provider、弹出SnackBar提示，空状态页面新增迁移提示。
2. **日历独立出课程表**：schedule_screen.dart移除TabBar/日历全部代码，仅保留课程表内容，AppBar新增日历跳转按钮；新建calendar_screen.dart承载完整日历功能；app.dart新增/calendar路由，独立push打开，底部导航保持5个tab不变。
3. **修复日历灰屏Bug**：替换原嵌套Expanded+GridView的布局方案，改用Wrap/手动行列渲染网格，彻底规避布局约束冲突导致点击切换日期后显示0高度灰屏问题。
4. **新增date_range跨天时间段日程**：数据库schemaVersion升到6，CalendarEvents新增rangeStartDate/rangeEndDate两个可空DateTime字段，补全数据库迁移逻辑；database_service.dart所有日历查询/写入/提醒方法新增date_range类型支持；日历UI新增时间段日程选项，用绿色图标区分，跨天覆盖日期显示标记点，支持多日期范围展示。

### 涉及文件清单
- 修改：daily_schedule_screen.dart、schedule_screen.dart、app.dart、database.dart、database.g.dart、database_service.dart
- 新建：calendar_screen.dart
