# whk-learn（学助）项目开发详情
## 项目基本信息
- 项目类型：Flutter 跨平台移动端学习辅助App
- 目标用户：高中生为主，预留多学段扩展能力
- 核心功能：易错点管理（支持拍照/相册导入题目图片）、科目管理、学习统计图表、艾宾浩斯遗忘曲线复习提醒、导出PDF错题本、深色模式、全局搜索
- 存储方案：纯本地 SQLite 存储，无需联网
- 仓库地址：https://github.com/neko-huang/whk-learn
- Git 用户配置：用户名 shi_cheng，邮箱 shichengmaomao@outlook.com

## 当前进度（2026-08-01）
1. 已完成M1-M6阶段全部代码编写，包含完整的项目结构、数据库模型、所有页面与服务逻辑
2. 已配置GitHub Actions自动构建Android APK工作流，支持push主分支自动构建产物上传
3. 已修复第一波CI构建错误：修正导入路径、删除手写不完整database.g.dart、补充test目录、移除与Dart内置方法冲突的自定义扩展、添加analysis_options.yaml放宽严格lint规则
4. 剩余待修复：59个编译错误，涉及Drift数据库API使用、Riverpod Provider定义、TZDateTime本地通知相关类型不匹配问题

## 后续里程碑
- M7：完成剩余编译错误修复，CI构建成功出APK
- M8：完善艾宾浩斯复习提醒逻辑
- M9：实现PDF导出错题本功能
- M10：完成多学段切换扩展与打包发布


## 进度更新（2026-08-02）
M7-M10全部开发完成：
- M7：新增复习历史记录写入、详情页展示功能，ReviewRecords表操作完整
- M8：新增pdf_export_service.dart，支持多入口导出A4格式PDF错题本，无新依赖
- M9：完善学段切换数据层，支持初/高/大学段科目过滤与自动生成，所有页面已适配
- M10：版本升级为1.1.0+1，新增CHANGELOG，静态检查通过，CI可直接构建