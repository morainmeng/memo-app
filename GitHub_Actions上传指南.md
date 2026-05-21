# 🚀 GitHub Actions 自动构建+签名+上传 App Store 完整指南

> 无需 Mac，在 Windows 上操作 GitHub 网页端即可完成

---

## 一、前置准备（一次性，约 20 分钟）

### 1.1 创建 GitHub 仓库

1. 打开 https://github.com/new
2. Repository name: `voice-apps`
3. 选择 **Private**（代码包含 IAP 配置）
4. 不要勾选任何初始化选项
5. 点击 Create repository

### 1.2 上传代码到 GitHub

在项目目录打开终端（PowerShell）：

```powershell
cd C:\Users\29161\.openclaw-autoclaw\workspace\voice-apps

git init
git add .
git commit -m "VoiceMate + MemoEase initial release"
git branch -M main
git remote add origin https://github.com/你的用户名/voice-apps.git
git push -u origin main
```

---

## 二、获取 App Store Connect API 密钥（一次性）

### 2.1 生成 API Key

1. 打开 https://appstoreconnect.apple.com
2. 登录 → 点击右上角头像 → **Users and Access**
3. 选择 **Integrations** 标签 → **App Store Connect API**
4. 点击 **+** → 创建 API Key
   - Name: `GitHub Actions`
   - Access: **App Manager**
5. 下载 `.p8` 文件 → **妥善保存**（只能下载一次！）
6. 记录显示的 **Issuer ID** 和 **Key ID**

### 2.2 获取 Team ID

1. 打开 https://developer.apple.com/account
2. Membership 页面 → 复制 **Team ID**

---

## 三、配置 GitHub Secrets（一次性）

打开你的仓库 → **Settings** → **Secrets and variables** → **Actions**

添加以下 5 个 Secrets：

| Secret 名称 | 值 | 说明 |
|---|---|---|
| `APPSTORE_CONNECT_API_KEY` | p8 文件的 Base64 编码 | 见下方生成命令 |
| `APPSTORE_KEY_ID` | 你记录的 Key ID | 如 `ABC123DEFG` |
| `APPSTORE_ISSUER_ID` | 你记录的 Issuer ID | 如 `12345678-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `APPLE_TEAM_ID` | 你的 Team ID | 如 `123ABC456D` |
| `MATCH_PASSWORD` | 随意设一个密码 | 如 `MySecurePass123` |

### 生成 Base64 编码的 API Key

```powershell
# Windows PowerShell
$keyPath = "C:\Users\29161\Downloads\AuthKey_XXXXXX.p8"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($keyPath)) | Set-Clipboard
```

然后粘贴到 GitHub Secret `APPSTORE_CONNECT_API_KEY`。

---

## 四、触发构建（每次发布时操作）

### 4.1 进入 Actions 页面

GitHub 仓库 → **Actions** → 左侧选择 **Build & Upload to App Store**

### 4.2 点击 Run workflow

填入参数：

| 参数 | 值 | 说明 |
|---|---|---|
| App to build | VoiceMate / MemoEase / Both | 选要构建的 App |
| Version number | 1.0.0 | 版本号 |
| Build number | 1 | 构建号（每次+1） |
| Upload to App Store? | yes | 是否直接上传 |

### 4.3 等待完成

- 构建时间：约 5-8 分钟
- 完成后自动上传到 App Store Connect
- 在 https://appstoreconnect.apple.com → TestFlight 可以看到上传的版本

---

## 五、首次构建注意事项

### ⚠️ 需要先在 App Store Connect 创建 App 记录

在上传 IPA 之前，必须先在网页端创建 App：

1. App Store Connect → My Apps → +
2. New App → 填写：
   - Platform: iOS
   - Name: VoiceMate / MemoEase
   - Primary Language: English
   - Bundle ID: com.yourcompany.voicemate
   - SKU: VOICEMATE001
3. 创建后才能在 CI 中上传

### ⚠️ 首次构建可能失败

第一次构建 GitHub Actions 会自动：
1. 生成 Xcode 项目
2. 创建签名证书
3. 注册设备
4. 创建 Provisioning Profile

如果失败，检查：
- API Key 权限是否为 App Manager
- Team ID 是否正确
- Bundle ID 是否已在 App Store Connect 注册

---

## 六、完整发布流程

```
┌─────────────┐    ┌──────────────┐    ┌───────────────┐
│ 在网页端     │    │ 在 GitHub      │    │ 在网页端       │
│ 创建App记录  │ → │ Actions中     │ → │ 提交审核       │
│ + IAP产品    │    │ 触发构建上传   │    │                │
└─────────────┘    └──────────────┘    └───────────────┘
    5分钟              点一下              等结果
```

### 每次发布只需要：
1. 在 GitHub Actions 点击 Run workflow
2. 输入版本号 → 点确定
3. 5-8 分钟后去 App Store Connect 提交审核

---

## 七、执行顺序总结（按顺序做）

```
Step 1: 创建 GitHub 仓库 + 推送代码
Step 2: App Store Connect 创建 API Key + 下载 p8
Step 3: App Store Connect 创建两个 App 记录 + 所有 IAP 产品
Step 4: 在 GitHub Settings 添加 5 个 Secrets
Step 5: 在 GitHub Actions 触发 VoiceMate 构建
Step 6: 验证 TestFlight 能收到版本
Step 7: 触发 MemoEase 构建
Step 8: 两个 App 都上传后，在 App Store Connect 提交审核
```
