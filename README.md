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
| **我的** | 按方案「暂不开发」：只放版本、当前词库/词数/高考年份，以及「清空进度重新走引导」 |

## 二、词库

`assets/words_gaokao.json`（551 KB，3540 词）由桌面 `高考英语3500词.txt` 解析生成：

- 字段：`word / phonetic / pos / meaning / level / tier`
- `level`：easy 1553、normal 887、hard 574、extra 526
- `tier`：`core`（easy+normal+hard = 3014 词，保底词库）/ `ext`（extra 526 词，高分词库在保底基础上追加）

重新生成：

```powershell
python tool\build_vocab.py     # 改路径后重新跑即可
```

## 三、代码结构

```
lib/
  main.dart                  入口 + 路由（引导 / 加载页 / 主界面）
  app_state.dart             词库、设置、学习档案、队列、算法、持久化
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
    mine_screen.dart         我的
```

持久化用 `shared_preferences` 存一个 JSON（进度、每日统计、设置、连续天数），连续点选时 600ms 防抖写盘。

## 四、开发命令

```powershell
cd C:\Users\Ligret\Documents\deepseek-harness\default-workspace\langobei
flutter pub get
flutter run                 # 模拟器/真机热重载
flutter build apk --release # 产物 build\app\outputs\flutter-apk\app-release.apk
flutter analyze
flutter test                # 17 个测试，覆盖三态判定与 3 秒规则
```

## 五、已知情况

- **release 关闭了 R8**（`android/app/build.gradle.kts`）。AGP 9 默认压缩会裁掉插件反射调用的 Pigeon 方法，装上就崩 `NoSuchMethodError`；等插件适配后可改回 `isMinifyEnabled = true` 并补 keep 规则。
- release 包目前用 debug 签名，上架前要换成自己的 keystore。
- 词库只有单词/音标/词性/释义，没有例句和发音；需要的话可以再接 TTS 或补例句字段。
- 「github 开源：LangoBei」里的仓库地址是占位，等真的建仓库后改成实际地址。
