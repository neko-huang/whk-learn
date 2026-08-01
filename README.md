# 学助 (StudyHelper)

一款基于 Flutter 的高中文科辅助学习 App，帮助学生高效管理易错点，通过艾宾浩斯遗忘曲线科学复习。

## 功能特性

### 核心功能
- **易错点管理**：记录各科目易错点，支持文字描述+题目图片
- **科目分类**：预设高中9大科目（语数英物化生政史地），支持自定义科目
- **章节管理**：按章节分类易错点，方便定位
- **标签系统**：自定义标签，灵活标记易错类型
- **难度标记**：5级难度评级，辅助复习优先级

### 智能复习
- **艾宾浩斯提醒**：基于遗忘曲线自动安排复习时间
- **本地通知**：到期推送复习提醒
- **复习追踪**：记录复习次数和状态

### 数据统计
- **今日概览**：新增数量、待复习数量、总计
- **7天趋势**：可视化每日新增趋势
- **科目分布**：饼图展示各科目占比
- **难度分布**：柱状图展示难度等级分布
- **复习进度**：复习完成率进度条

### 其他特性
- **深色模式**：护眼模式切换
- **搜索功能**：全局搜索易错点
- **数据导出**：支持导出 PDF 文档
- **学段切换**：预留初中、大学扩展支持
- **本地存储**：SQLite 数据库，数据安全

## 技术栈

- **框架**：Flutter 3.x (Dart)
- **状态管理**：Riverpod
- **数据库**：drift (SQLite)
- **路由**：go_router
- **图片处理**：image_picker
- **本地通知**：flutter_local_notifications
- **图表**：fl_chart
- **PDF导出**：pdf + printing

## 项目结构

```
study_helper/
├── lib/
│   ├── main.dart                    # 入口
│   ├── app.dart                     # App 根组件（主题、路由）
│   ├── models/                      # 数据模型
│   │   ├── database.dart            # 数据库定义
│   │   ├── mistake.dart             # 易错点模型
│   ├── screens/                     # 页面
│   │   ├── home/
│   │   ├── mistakes/
│   │   ├── statistics/
│   │   └── settings/
│   ├── services/                    # 服务层
│   │   ├── database_service.dart
│   │   ├── image_service.dart
│   │   ├── notification_service.dart
│   │   └── export_service.dart
│   └── utils/                       # 工具类
│       └── spaced_repetition.dart   # 艾宾浩斯算法
├── android/                         # Android 配置
├── ios/                             # iOS 配置
└── pubspec.yaml                     # 依赖配置
```

## 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

### 安装依赖

```bash
flutter pub get
```

### 生成数据库代码

```bash
dart run build_runner build
```

### 运行项目

```bash
# Android
flutter run

# iOS
flutter run -d ios

# 指定设备
flutter devices
flutter run -d <device_id>
```

### 打包发布

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## Git 工作流

### 初始化

```bash
git init
git config user.name "你的名字"
git config user.email "your.email@example.com"
git add .
git commit -m "feat: 初始化项目结构"
```

### 提交规范

使用约定式提交格式：
- `feat:` 新功能
- `fix:` 修复 Bug
- `refactor:` 重构
- `docs:` 文档
- `chore:` 构建/工具

## 开发计划

- [x] M1: 项目初始化 + 数据库搭建
- [x] M2: 主界面框架（导航+主题）
- [x] M3: 添加易错点（含图片）
- [x] M4: 列表+详情+搜索
- [x] M5: 科目管理
- [x] M6: 学习统计
- [ ] M7: 艾宾浩斯提醒（待完善）
- [ ] M8: 导出 PDF
- [ ] M9: 多学段扩展
- [ ] M10: 打包发布

## License

MIT
