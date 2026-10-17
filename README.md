# LangoBei

高考英语背单词 App，按桌面《修改方案》从零重写。Flutter 3.47 / Android，词库是桌面那份《高考英语3500词》。

## 一、按方案做的事

### 1. 改名与引导
- 应用名 **LangoBei**，包名 `com.codingtools.langobei`
- 首次启动四页引导：
  1. 介绍页：主标语「源于世界上最负责的英语老师催促我背单词」，小字 `github 开源：LangoBei`，底部落款「——高三生 Ligret」
  2. 词库选择：高考词汇（保底）3014 词 / 高考词汇（高分）3540 词；四级、雅思 6.5 已预留入口并标「敬请期待」
  3. 是否即将参加高考：选「是」后再选年份（2027 / 2028 / 2029），并实时显示剩余天数
  4. 「一切准备就绪 / 祝你好运」，点「开始背单词」进入 App
- 之后每次打开都有加载页，显示 **距离高考仅有 xx 天**

### 2. 算法（三种状态）
| 状态 | 判定 |
| --- | --- |
| 已掌握 | 最近三次有效评价**全部是「认识」**（`最近3次 = [认识, 认识, 认识]`） |
| 错题本 | 在「知新」里选了「不认识」 |
| 未掌握 | 其余情况 |

- 每个单词记录「认识 / 模糊 / 不认识」各被选过多少次（`WordProgress.knowCount / fuzzyCount / unknownCount`）
- **首轮才有的「确定认识」**：只在这个词还没被任何一次评价过时出现，点了直接进已掌握
- **3 秒隐形规则**：卡片停留超过 3 秒的，不管你点的是「认识」还是「不认识」，掌握度判定一律按「模糊」记录。界面当场不给任何提示，只有正确率/掌握度会被悄悄影响（明面上的选项次数照实统计）
- **每 5 个词插一张错题**：答完 5 个新词后立刻从错题本抽一张插入（实时抽，不是开队列时预抽），选「认识」移出错题本，选另外两项保留

### 3. 四个板块
| 板块 | 内容 |
| --- | --- |
| **知新** | 卡片学习：翻面看释义 → 不认识 / 模糊 / 认识（+ 首轮的确定认识）。选「不认识」进错题本；换词时有右滑淡入动画；顶部显示今日次数、错题本数、已掌握数 |
| **反思** | 与知新同样的布局，但只有「认识 / 不认识」两个选项，单词全部来自错题本；认识→移出，不认识→保留。错题本空了显示空状态 |
| **量化** | 距离高考天数、已连续天数、今日正确率、已掌握数量 + 百分比进度条、错题本数量、最近七天每天选择次数的柱状图 |
| **更多** | 外观设置（深色模式、主题色四选一）、当前词库/词数/高考年份、分级图例、**导出学习数据**、版本信息，以及「清空进度重新走引导」 |

## 二、外观（更多 → 外观）

- **深色模式**：跟随系统 / 浅色 / 深色 三档，切换后立即生效，走 `MaterialApp.themeMode`
- **主题色四选一**：默认（蓝）/ 深绿 / 紫色，第四格**先留空**——画成虚线圈标「待定」，点它只给一句提示，不会改主题
  - 选中项带勾与加粗标签，右侧同步显示当前预设名与色值（如 `默认 · #1A44FF`）
  - 色值在 `models/word.dart` 的 `kThemePresets` 里用 **HSL** 描述（默认 229/100%/55%、深绿 152/62%/36%、紫色 272/70%/52%），以后要放自定义取色，直接复用这条 HSL 通路
  - **只染醒目位，不染白**：页面标题、大标题、主按钮、进度条、滑块、选中态、导航栏选中项用主题色；卡片、页面底色、正文与次要文字一律走固定中性色（`theme.dart` 里的 `kLight*` / `kDark*` 常量），白色区域永远保持纯白。做法是拿中性灰生成基底配色，再只把 `primary` 系列换成主题色
- 老数据兼容：之前存过自由 HSL 的，升级时按色相就近迁移到预设（差距超过 24° 就回到默认），不会突然跳色
- 清空学习进度时会**保留**外观偏好

## 三、词库

`assets/words_gaokao.json`（551 KB，3540 词）由桌面 `高考英语3500词.txt` 解析生成：

- 字段：`word / phonetic / pos / meaning / level / tier`
- `level`：easy 1553、normal 887、hard 574、extra 526
- `tier`：`core`（easy+normal+hard = 3014 词，保底词库）/ `ext`（extra 526 词，高分词库在保底基础上追加）
- 分级在界面上**直接显示原文** `easy / normal / hard / extra`，并按 **easy 绿、normal 黄、hard 橙、extra 红** 上色（深浅色各一套，见 `theme.dart` 的 `levelColor`）；单词卡的正面与释义面都带这个标签，「更多 → 当前设置」里还有一整行四色图例带词数

重新生成：

```powershell
python tool\build_vocab.py     # 改路径后重新跑即可
```

## 四、导出学习数据（更多 → 数据）

三个入口，互相兜底：

| 按钮 | 做什么 |
|---|---|
| **导出为文件** | 生成 `langobei-年月日-时分秒.json` 写进系统**「下载」目录**（Android 10+ 走 MediaStore，不需要存储权限；老系统没权限时退回应用外部目录并回报实际路径），提示条上带「复制路径」 |
| **复制 JSON** | 整份 JSON 进剪贴板，体积约 1-2 KB（只有已学的词才占地方） |
| **分享文本** | 走系统分享面板把 JSON 文本发出去（微信/文件传输助手/邮件都行） |

导出内容：

```jsonc
{
  "app": "LangoBei",
  "format": 1,                     // 格式版本，以后改字段往上加
  "exportedAt": "2026-10-17T22:30:45.123",
  "utcOffsetMinutes": 480,
  "summary": {                     // 给人看的汇总，和界面上的数字一致
    "bank": "ext", "examYear": 2027, "bankTotal": 3540,
    "studied": 12, "mastered": 3, "wrong": 5, "accuracy": 0.46,
    "know": 9, "fuzzy": 2, "unknown": 1,
    "streak": 3, "levelCounts": { "easy": 1553, "normal": 887, "hard": 574, "extra": 526 },
    "themeMode": "system", "themePreset": "default",
    "today": { "date": "2026-10-17", "choices": 71, "correct": 33 }
  },
  "data": {                        // 与本地存档同构，可直接用来恢复
    "progress": { "apple-easy-1": { "k": 3, "f": 1, "u": 0, "r": [2,2,2], "w": false, "t": 1792246982044 } },
    "daily": { "2026-10-17": { "c": 71, "r": 33 } },
    "settings": { "onboarded": true, "bank": "ext", "examYear": 2027, "themeMode": "system", "preset": "default" },
    "streak": 3, "lastStudyDay": "2026-10-17"
  }
}
```

要点：

- `data` 段和 `AppState.toSnapshot()` 是**同一份实现**，落盘和导出不会各写一套；因此以后加「导入」时直接把 `data` 喂回 `AppState` 即可
- 导出走 `ExportService`（`lib/export_service.dart`），原生侧是 `MainActivity.kt` 里的 `langobei/export` 通道；没装原生实现时（比如桌面调试）会返回「当前平台不支持」而不是崩
- 导出**不会**修改任何状态，也不包含词库本身（词库在安装包里，导出只带进度）
- 「清空进度」不会删掉已经导出的文件

## 五、代码结构

```
lib/
  main.dart                  入口 + 路由（引导 / 加载页 / 主界面）
  app_state.dart             词库、设置、学习档案、队列、算法、持久化
  export_service.dart        数据导出（JSON 组装 + 原生通道）
  theme.dart                 Material 3 主题
  models/word.dart           Word / WordProgress / DayStat / Settings
  widgets/flip_card.dart     3D 翻转卡（正面单词，背面释义）
  screens/
    onboarding_screen.dart   四页引导
    splash_screen.dart       加载页 + 高考倒计时
    shell.dart               四个 tab
    study_screen.dart        知新
    reflect_screen.dart      反思
    quant_screen.dart        量化
    more_screen.dart         更多（外观设置 + 数据导出 + 关于）
android/app/src/main/kotlin/com/codingtools/langobei/MainActivity.kt
                             原生通道：写「下载」目录、拉起分享面板
```

持久化用 `shared_preferences` 存一个 JSON（进度、每日统计、设置、连续天数），连续点选时 600ms 防抖写盘。

## 六、开发命令

```powershell
cd C:\Users\Ligret\Documents\deepseek-harness\default-workspace\langobei
flutter pub get
flutter run                 # 模拟器/真机热重载
flutter build apk --release # 产物 build\app\outputs\flutter-apk\app-release.apk
flutter analyze
flutter test                # 49 个测试，覆盖三态判定、3 秒规则、分级配色、外观设置、白底不被主题色污染、数据导出
```

## 七、已知情况


- **release 关闭了 R8**（`android/app/build.gradle.kts`）。AGP 9 默认压缩会裁掉插件反射调用的 Pigeon 方法，装上就崩 `NoSuchMethodError`；等插件适配后可改回 `isMinifyEnabled = true` 并补 keep 规则。
- release 包目前用 debug 签名，上架前要换成自己的 keystore。
- 词库只有单词/音标/词性/释义，没有例句和发音；需要的话可以再接 TTS 或补例句字段。
- 「github 开源：LangoBei」里的仓库地址是占位，等真的建仓库后改成实际地址。
