# 第三方数据与许可

## ECDICT

- 项目：ECDICT — Free English to Chinese Dictionary Database
- 地址：<https://github.com/skywind3000/ECDICT>
- 用途：App 内置词典（查词）以及四级 / 六级 / 雅思 / 考研四个内置词库的词条、音标、释义
- 许可：MIT License，Copyright © 2025 Linwei，原文见 [third_party/ECDICT-LICENSE.txt](third_party/ECDICT-LICENSE.txt)
- 处理方式：只保留「有中文释义」且「有考试大纲标签 / 牛津三千 / 柯林斯星级 / 词频前 3 万」的词条，字段缩写后按首字母分片；处理脚本见 [tool/build_dict.py](tool/build_dict.py)

除上述数据外，两个高考词库（3014 / 3540 词）、学习逻辑与界面代码均为本项目自有内容。
