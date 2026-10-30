# LimbusCalc · 边狱巴士伤害计算器

《边狱巴士 / Limbus Company》技能伤害计算器，使用 Flutter 编写。

## 功能

应用包含两个相互独立的计算页面，切换时各自保留输入与结果。

### 基础计算

普通技能逐枚硬币的直接伤害。

- 技能参数：基础威力、硬币数量（1～10）、硬币威力（加算 / 减算）、正反面（全部正面 / 全部反面 / 自定义，可逐枚切换）。
- 伤害修正：攻击 / 防御等级、物理与罪孽抗性倍率、拼点轮数、暴击、进攻方 / 受击方动态增减伤。
- 结果：技能直接伤害合计、每枚伤害、逐枚明细、可展开的计算过程，可一键复制计算摘要。
- 输入非法时给出明确提示，不保留旧结果。

规则说明见 [docs/calculation_rules.md](docs/calculation_rules.md)。

### 高级计算

计算模型移植自 [MirrorCalcWeb](https://github.com/f0lkskill/MirrorCalcWeb)（MIT），并扩展了加算 / 减算与逐枚正反面。

- **单技能计算**：逐行修正（呼吸法、单币乘区、单币硬币威力、终币特殊威力、固定 / 比例追伤）、重投、拼点点数、伤害构成与逐行计算过程。
- **循环统计**：第一循环 / 第二循环 / 极限循环 × 6 回合，记录时保存完整输入，可按回合恢复。
- **参数扫描**：对 12 个参数做区间扫描，输出折线图与表格，输入变化后标记结果过期。

全部正面时，计算结果与参考实现逐位一致。移植说明与差异见 [docs/mirrorcalc_port.md](docs/mirrorcalc_port.md)。

### 界面

- 自适应导航：窗口较窄时使用悬浮底栏，宽窗口使用可展开的侧栏。
- 外观设置：浅色 / 深色 / 跟随系统、预设与自定义主题色，以及系统动态取色（Android 12 及以上，或提供强调色的桌面系统）。
- 页面动画：非线性滑动 / 左右滑动 / 淡入淡出 / 关闭，并遵循系统的“减少动画”设置。
- 离线可用：打包了中文子集字体，Web 版运行时不访问外部 CDN。

## 支持的平台

| 平台 | 要求 | 状态 |
|---|---|---|
| Android | Android 7.0（API 24）及以上；arm64-v8a / armeabi-v7a / x86_64 | 支持 |
| Windows | Windows 10 / 11，x64 | 支持 |
| Web | Chrome、Edge 等现代浏览器 | 支持 |
| iOS / macOS / Linux | — | 保留了 Flutter 工程文件，尚未构建与验证 |

## 下载与运行

可从 [Releases](https://github.com/YousaHay/LimbusCalc/releases) 下载构建好的安装包（如有）。也可以自行构建，见下文。

## 构建

环境：

- Flutter 3.47（stable）/ Dart 3.13
- Android：Android SDK（platform 36、NDK 28.2）与 JDK 17 及以上
- Windows：Visual Studio 2022 及以上，并安装“使用 C++ 的桌面开发”工作负载；项目使用了插件，需开启 Windows“开发人员模式”

```bash
flutter pub get

# 运行
flutter run -d windows
flutter run -d chrome

# 构建
flutter build apk --release --split-per-abi          # 输出 build/app/outputs/flutter-apk/
flutter build windows --release                      # 输出 build/windows/x64/runner/Release/
flutter build web --release --no-web-resources-cdn   # 输出 build/web
```

Windows 版发布时需要保留 Release 目录中的全部文件（包括插件 DLL），不能只复制 exe。

## 字体

界面使用打包的 Noto Sans SC 子集字体，只包含界面实际用到的字符。新增或修改界面文字后需要重新生成：

```bash
pip install fonttools
python tool/subset_fonts.py <包含 NotoSansSC-Regular/Medium/Bold.otf 的目录>
```

源字体可从 [noto-cjk](https://github.com/notofonts/noto-cjk) 的 `Sans/SubsetOTF/SC` 获取。

## 目录结构

```
lib/
  main.dart / app.dart / home_shell.dart   入口、主题装配与应用外壳（导航、标题区、转场）
  app_theme.dart                           颜色、圆角、间距与组件主题
  shell/                                   导航、页面转场、系统栏适配
  features/calculator/                     基础计算
  features/mirror_calculator/              高级计算
  features/settings/                       设置、外观与取色
assets/                                    子集字体与第三方许可证
tool/                                      字体子集生成
docs/                                      计算规则与移植说明
```

## 参考资料

- Syx 博客《Damage Formula》：<https://blog.limbus.wiki/docs/damage_formula/>
- 灰机 Wiki《伤害计算》：<https://limbuscompany.huijiwiki.com/wiki/伤害计算>
- MirrorCalcWeb：<https://github.com/f0lkskill/MirrorCalcWeb>

## 许可证

本项目以 [GNU General Public License v3.0](LICENSE) 发布。

包含的第三方内容保留其原许可证：

- 高级计算的计算模型移植自 MirrorCalcWeb，MIT License，Copyright (c) 2026 f0lkskill，见 [assets/licenses/MirrorCalcWeb-LICENSE.txt](assets/licenses/MirrorCalcWeb-LICENSE.txt)。
- 打包的 Noto Sans SC 子集字体，SIL Open Font License 1.1，见 [assets/fonts/OFL.txt](assets/fonts/OFL.txt)。

《边狱巴士 / Limbus Company》及相关名称、素材的权利归 Project Moon 所有。

## 作者

[YousaHay](https://github.com/YousaHay)
