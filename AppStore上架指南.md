# 🚀 App Store 上架完整指南
# VoiceMate & MemoEase 双 App 发布流程

---

## 一、前置准备

### 1.1 苹果开发者账号
- 注册 [Apple Developer Program](https://developer.apple.com/programs/) — $99/年
- 一个账号可上传 **3 个 App**（你刚好有 2 个，绰绰有余）

### 1.2 创建 App ID
1. 登录 [developer.apple.com](https://developer.apple.com)
2. Certificates, Identifiers & Profiles → Identifiers → +
3. 分别创建：
   - `com.yourcompany.voicemate`
   - `com.yourcompany.memoease`
4. 各启用能力：SiriKit, Speech Recognition, In-App Purchase, Push Notifications, CloudKit

### 1.3 创建 App Store Connect 记录
1. 登录 [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. My Apps → + → New App
3. 填写两个 App 的元数据

---

## 二、App Store 元数据模板

### VoiceMate（上班族版）

| 字段 | 内容 |
|---|---|
| **名称** | VoiceMate - AI Voice Scheduler |
| **副标题** | Speak your schedule into existence |
| **分类** | 主: Productivity / 副: Business |
| **价格** | Free (with IAP) |
| **年龄分级** | 4+ |

**App 描述**:
```
VoiceMate turns your voice into action. Just speak — we'll handle the rest.

🎤 SPEAK NATURALLY
"Schedule a meeting with John Thursday at 3pm about Q2 budget" — VoiceMate understands and creates the calendar event instantly.

✨ AI-POWERED SUMMARIES
Every recording gets an intelligent summary. Key people, places, and action items are extracted automatically.

📅 AUTO CALENDAR SYNC
Meetings, calls, and deadlines go straight to your Apple Calendar. No typing required.

🌍 30+ LANGUAGES
English, Mandarin, Japanese, Korean, Spanish, French, German, and more.

🔔 SMART REMINDERS
"Remind me to follow up with the client tomorrow" — done. VoiceMate sets the reminder with the right time.

⏱️ SAVE 2+ HOURS/WEEK
The average professional spends 2+ hours weekly typing calendar events and reminders. VoiceMate cuts that to seconds.

=== PREMIUM FEATURES ===
VoiceMate Basic ($4.99/month):
• 20 recordings/day
• 3 languages
• Basic summaries
• Calendar sync

VoiceMate Pro ($9.99/month or $49.99/year):
• Unlimited recordings
• All 30+ languages
• Advanced AI summaries
• Team sharing
• Cloud sync across devices
• Priority support

Terms: https://yourcompany.com/terms
Privacy: https://yourcompany.com/privacy
```

**关键词（100字符）**:
```
voice,calendar,schedule,meeting,reminder,transcription,speech,text,dictation,ai,assistant,productivity,note,organizer
```

---

### MemoEase（中老年版）

| 字段 | 内容 |
|---|---|
| **名称** | MemoEase - Voice Reminder |
| **副标题** | Just speak. We'll remember for you. |
| **分类** | 主: Productivity / 副: Health & Fitness |
| **价格** | Free (with IAP) |
| **年龄分级** | 4+ |

**App 描述**:
```
Never forget what matters. Just tap the big button and speak.

👴 DESIGNED FOR EVERYONE
Extra-large text, one-button operation, and clear voice confirmation. If you can talk, you can use MemoEase.

💊 PILL REMINDERS MADE SIMPLE
"Take my blood pressure pill every morning at 8" — MemoEase understands and sets up daily reminders automatically.

🏥 NEVER MISS AN APPOINTMENT
Doctor visits, checkups, therapy sessions — speak once, and MemoEase puts it in your calendar with reminders.

👨‍👩‍👧 FAMILY SHARING (Pro)
Let your children or caregivers help manage your reminders. Everyone stays in sync.

🔊 VOICE CONFIRMATION
MemoEase speaks back to confirm: "Got it. Take your medication at 8 AM." No reading required.

📋 SIMPLE HISTORY
All your reminders in one place. Filter by health, appointments, shopping, family, and more.

🔒 PRIVATE & SECURE
Your voice stays on your iPhone. No data leaves your device without your permission.

=== PRICING ===
MemoEase Basic ($4.99/month):
• 10 reminders/day
• Basic categories
• Voice confirmation

MemoEase Pro ($9.99/month or $49.99/year):
• Unlimited reminders
• Family sharing
• Health tracking
• Medication schedules
• Priority support

Terms: https://yourcompany.com/terms
Privacy: https://yourcompany.com/privacy
```

**关键词（100字符）**:
```
reminder,voice,pill,medication,senior,elderly,health,appointment,calendar,memory,assistant,family,simple,easy,caregiver
```

---

## 三、截图要求（每种设备 5 张）

### iPhone 6.7" (1290x2796px):
1. 主屏幕录音界面
2. 转写中界面
3. AI 摘要结果
4. 日历集成界面
5. 设置/订阅界面

### iPhone 6.5" (1242x2688px):
同上尺寸适配

---

## 四、审核要点

### ⚠️ 常见被拒原因及对策：

| 被拒原因 | 解决方法 |
|---|---|
| 隐私描述不充分 | 已按要求写清楚，勿改 |
| 语音识别权限弹窗 | 首次使用时引导用户点击允许 |
| IAP 未正确配置 | App Store Connect 创建完全一致的 Product ID |
| 缺少恢复购买按钮 | Settings 页必须有 Restore Purchases |
| 功能不完整 | 确保免费试用后可正常使用基本功能 |
| 4.2 最低功能要求 | 已提供完整可用的核心功能链 |

---

## 五、发布流程

1. ✅ 在 Xcode 中为每个 App 创建独立的 Target
2. ✅ Archive → Validate App → 修复任何警告
3. ✅ Upload to App Store Connect
4. ✅ 在 App Store Connect 完善所有元数据
5. ✅ 提交审核
6. ✅ 审核通过后手动发布或自动发布

---

## 六、定价配置（App Store Connect IAP）

### VoiceMate:
| Product ID | 类型 | 价格 | 试用 |
|---|---|---|---|
| com.voicemate.monthly.basic | 自动续期订阅 | $4.99 | 7天 |
| com.voicemate.monthly.pro | 自动续期订阅 | $9.99 | 7天 |
| com.voicemate.yearly.pro | 自动续期订阅 | $49.99 | 14天 |
| com.voicemate.family.monthly | 自动续期订阅 (家庭) | $14.99 | 14天 |

### MemoEase:
| Product ID | 类型 | 价格 | 试用 |
|---|---|---|---|
| com.memoease.monthly.basic | 自动续期订阅 | $4.99 | 14天 |
| com.memoease.monthly.pro | 自动续期订阅 | $9.99 | 14天 |
| com.memoease.yearly.pro | 自动续期订阅 | $49.99 | 14天 |
| com.memoease.family.monthly | 自动续期订阅 (家庭) | $14.99 | 14天 |

> 🔥 推荐裂变: 每推荐 2 人 → 免费获得 1 个月个人版
> 👨‍👩‍👧 家庭计划: 最多 5 位家庭成员共享 Pro 功能
