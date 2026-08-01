# CI/CD 配置说明

## GitHub Actions 自动构建

本项目配置了 GitHub Actions 工作流，每次推送代码到 `main` 分支时会自动构建 Android APK。

### 工作流功能

- ✅ 自动获取依赖
- ✅ 代码静态分析
- ✅ 运行单元测试
- ✅ 构建 debug APK
- ✅ 构建 release APK
- ✅ 上传构建产物（保留30天）
- ✅ 打标签时自动创建 Release

### 触发条件

1. **Push 到 main 分支**：自动触发构建
2. **Pull Request**：自动触发构建（用于验证）
3. **手动触发**：在 Actions 页面点击 "Run workflow"

### 获取构建产物

#### 方式一：从 Actions 页面下载

1. 进入仓库的 **Actions** 标签页
2. 选择对应的工作流运行记录
3. 在页面底部的 **Artifacts** 区域下载：
   - `app-debug`：调试版 APK
   - `app-release`：发布版 APK

#### 方式二：从 Release 页面下载（仅标签版本）

当推送带版本号的标签（如 `v1.0.0`）时，会自动创建 Release：

```bash
# 创建标签
git tag v1.0.0
git push origin v1.0.0
```

然后在 **Releases** 页面可以下载 APK。

### 本地构建

如果需要在本地构建 APK：

```bash
# 构建 debug 版
flutter build apk --debug

# 构建 release 版
flutter build apk --release

# APK 位置
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

### 签名配置（生产环境）

当前使用默认签名，如需发布到应用商店，需要配置正式签名：

1. 生成签名密钥：
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. 在 `android/key.properties` 中配置：
```properties
storePassword=<密码>
keyPassword=<密码>
keyAlias=upload
storeFile=<keystore路径>
```

3. 修改 `android/app/build.gradle` 添加签名配置

### 环境变量（可选）

如需在 CI 中使用签名，可将以下内容添加到仓库 Secrets：

- `KEY_STORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS`

然后在 workflow 中引用：
```yaml
env:
  KEY_STORE_PASSWORD: ${{ secrets.KEY_STORE_PASSWORD }}
```
