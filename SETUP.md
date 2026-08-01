# 学助 (StudyHelper) 本地运行指南

## 🚀 快速开始（5分钟搞定）

### 第1步：创建 Flutter 项目

在你本地终端执行：

```bash
flutter create study_helper
cd study_helper
```

### 第2步：替换项目文件

将以下文件复制/替换到 `study_helper/` 目录下：

```
study_helper/
├── pubspec.yaml              ← 替换（依赖配置）
├── lib/
│   ├── main.dart             ← 替换
│   ├── app.dart              ← 新增
│   ├── models/
│   │   ├── database.dart     ← 新增
│   │   ├── database.g.dart   ← 新增（数据库生成代码）
│   │   └── mistake.dart      ← 新增
│   ├── screens/
│   │   ├── home/
│   │   │   └── home_screen.dart          ← 新增
│   │   ├── mistakes/
│   │   │   ├── mistake_list_screen.dart  ← 新增
│   │   │   ├── add_mistake_screen.dart   ← 新增
│   │   │   └── mistake_detail_screen.dart ← 新增
│   │   ├── statistics/
│   │   │   └── statistics_screen.dart    ← 新增
│   │   └── settings/
│   │       └── settings_screen.dart      ← 新增
│   ├── services/
│   │   ├── database_service.dart      ← 新增
│   │   ├── image_service.dart         ← 新增
│   │   └── notification_service.dart  ← 新增
│   └── utils/
│       └── spaced_repetition.dart     ← 新增
└── .gitignore                ← 替换
```

### 第3步：安装依赖

```bash
flutter pub get
```

### 第4步：生成数据库代码

```bash
dart run build_runner build
```

> 💡 如果提示找不到 `build_runner`，先运行 `flutter pub get` 安装依赖

### 第5步：运行项目

**Android:**
```bash
flutter run
```

**iOS (需要 Mac):**
```bash
flutter run -d ios
```

**指定设备运行:**
```bash
flutter devices          # 查看可用设备
flutter run -d <id>      # 指定设备ID运行
```

---

## ⚠️ 常见问题

### 1. 数据库代码生成失败

**解决方法：**
```bash
# 清理缓存重新生成
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2. Android 权限问题

在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

### 3. iOS 权限问题

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSCameraUsageDescription</key>
<string>需要访问相机以拍摄题目图片</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以选择题目图片</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存导出的文件</string>
```

### 4. 通知不工作

**Android:** 确保在 `MainActivity.kt` 中初始化：

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin

class MainActivity: FlutterActivity() {
    // 无需额外代码，插件会自动初始化
}
```

**iOS:** 在 `AppDelegate.swift` 中：

```swift
// ios/Runner/AppDelegate.swift
import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 5. 深色模式不生效

确保在 `AndroidManifest.xml` 中设置主题：

```xml
<activity
    android:name=".MainActivity"
    android:theme="@style/LaunchTheme"
    ...>
```

---

## 📱 Git 初始化

```bash
# 初始化 Git
git init
git config user.name "你的名字"
git config user.email "your.email@example.com"

# 首次提交
git add .
git commit -m "feat: 初始化项目 - 易错点管理核心功能"

# 推送远程（可选）
git remote add origin https://github.com/你的用户名/study_helper.git
git branch -M main
git push -u origin main
```

---

## 🎯 下一步开发

完成 M1-M6 后，接下来的任务：

| 阶段 | 任务 | 说明 |
|------|------|------|
| M7 | 艾宾浩斯提醒 | 完善通知调度逻辑 |
| M8 | 导出 PDF | 实现 PDF 生成和分享 |
| M9 | 多学段扩展 | 初中/大学模式 |
| M10 | 打包发布 | 构建 release 版本 |

---

## 📞 需要帮助？

遇到问题可以：
1. 运行 `flutter doctor` 检查环境
2. 查看 Flutter 官方文档：https://docs.flutter.dev
3. 直接问我具体报错信息

加油！🎉
