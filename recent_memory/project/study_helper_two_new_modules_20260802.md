# study_helper 两大新功能模块实现记录 2026-08-02

项目路径：/app/data/所有对话/主对话/study_helper/

## 完成内容总览
本次新增两大功能，全程未引入额外依赖，遵循原有drift ORM、Riverpod状态管理、go_router路由规范，兼容深浅色模式。

### 一、每日时间安排模块
1. 数据库变更：新增DailySchedules表，schemaVersion升级到v3，onUpgrade处理from<3时创建daily_schedules表
2. 数据库服务新增全量CRUD方法：按日期获取日程、增删改、跨天归档检查（基于SharedPreferences存储lastActiveDate）
3. 新增完整日程页面：支持日期切换/日期选择、新增编辑删除日程、历史日期只读、空状态展示
4. 导航变更：底部tab从4个扩展到5个，日程tab放在课程表和学习计划之间，新增/daily-schedule路由

### 二、离开手机（专注模式）模块
1. 新增专注模式入口页面：支持15/30/45/60/90/120分钟时长选择
2. 新增全屏专注页面：大字体倒计时、随机鼓励语、三步强制退出验证流程（长按3秒+解两位数数学题+输入确认文字"我确定要放弃"）
3. 记录复用原有PomodoroRecords表，type设为focus_mode，已全量更新统计逻辑将focus_mode纳入所有统计计算
4. 首页快捷操作区新增"离开手机"和"日程"快捷入口，统计页面新增专注模式完成次数展示
5. 应用启动时自动触发跨天日程归档检查

## 注意事项
所有数据库相关修改完成后，需执行`flutter pub run build_runner build`重新生成database.g.dart文件，该文件已在.gitignore中不会被提交。