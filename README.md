# 🎤 语音记事本 × 双App 完整产品交付包 (Xcode Ready)

> **目标**: 2 个付费 iOS App，在苹果 App Store 盈利  
> **人群**: 欧美上班族 (VoiceMate) + 中老年 (MemoEase)  
> **定价**: 订阅制 ($4.99/$9.99 月, $49.99 年, 家庭 $14.99)  
> **交付日期**: 2026-05-09

---

## 📁 文件结构

```
voice-apps/
├── README.md                    ← 总说明
├── 竞品分析.md                  ← 竞品矩阵 + 差异化策略
├── project-config.json          ← 能力配置
├── AppStore上架指南.md          ← 元数据/截图/审核/定价
├── setup_xcode.sh               ← Mac 上一键生成 .xcodeproj
├── ReferralEngine.swift         ← 共享: 推荐裂变引擎
├── EmailManager.swift           ← 共享: 邮箱收集+备份导出
│
├── VoiceMate/                   ← 上班族版
│   ├── Package.swift            ← SwiftPM (Xcode 可直接打开)
│   ├── Sources/
│   │   ├── VoiceMateApp.swift   ← 语音/AI/日历/IAP
│   │   ├── Views.swift          ← 全部UI+照片+链接+推荐
│   │   ├── ReferralEngine.swift
│   │   └── EmailManager.swift
│   └── Resources/
│       └── Info.plist
│
└── MemoEase/                    ← 中老年版
    ├── Package.swift
    ├── Sources/
    │   ├── MemoEaseApp.swift    ← 简易引擎+健康分类
    │   ├── Views.swift          ← 超大按钮+照片/链接+推荐
    │   ├── ReferralEngine.swift
    │   └── EmailManager.swift
    └── Resources/
        └── Info.plist
```

---

## 🚀 在 Xcode 中打开 (Mac)

### 方式 1: Package.swift 直接打开
```
Xcode → File → Open → 选择 VoiceMate/Package.swift
```
现代 Xcode (14+) 自动识别 Swift Package 作为完整项目。

### 方式 2: 一键生成 .xcodeproj
```bash
cd voice-apps
bash setup_xcode.sh
open VoiceMate/VoiceMate.xcodeproj
```

### 方式 3: 手动创建 Project
```
Xcode → New Project → iOS App
Name: VoiceMate
Interface: SwiftUI | Language: Swift | Minimum: iOS 17.0
然后把 Sources/ 里的 4 个 .swift 文件拖进项目
```

---

## 🆚 两个 App 差异化

| 维度 | VoiceMate (上班族) | MemoEase (中老年) |
|---|---|---|
| **Slogan** | "Speak it. Schedule it. Done." | "Just speak. We'll remember." |
| **UI** | 现代多Tab | 单一超大按钮+语音回读 |
| **输入** | 语音/拍照/网页链接 | 语音/拍照/链接(家人分享) |
| **AI能力** | NLP实体提取+自然语言日历 | 健康关键词+吃药提醒 |
| **推荐** | 每2人→1月免费 | 每2人→1月免费 |
| **邮箱** | 第3条触发备份弹窗 | 第3条触发备份弹窗 |
| **试用期** | 7天 | 14天 |

---

## 💰 收入预测

| | VoiceMate | MemoEase | 合计 |
|---|---|---|---|
| 月下载 | 5K-10K | 3K-8K | 8K-18K |
| 付费转化 | ~10.7% | ~15% | — |
| 月收入 | $3.7K-$7.5K | $3.1K-$8.4K | **$6.9K-$15.9K** |

---

## 🔧 技术栈

- **框架**: SwiftUI + Combine
- **语音**: Apple Speech Framework (端侧)
- **NLP**: NaturalLanguage + Vision (OCR)
- **日历**: EventKit + UserNotifications
- **付费**: StoreKit (自动续期订阅)
- **推荐**: CryptoKit 推荐码 + CloudKit 同步
- **邮箱**: MessageUI + CSV 导出
