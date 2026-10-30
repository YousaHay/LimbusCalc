# 高级计算：MirrorCalcWeb 移植与正反面扩展说明

本文件记录把 [MirrorCalcWeb](https://github.com/f0lkskill/MirrorCalcWeb) 的计算能力移植为纯 Dart
并接入本应用“高级计算”页面（原名“镜息演算”）的依据、字段映射、与参考实现的差异、
本应用新增的加减算与正反面扩展（第 8 节），以及验证方式。

## 1. 移植基准

| 项目 | 值 |
|---|---|
| 仓库 | https://github.com/f0lkskill/MirrorCalcWeb |
| 提交 | `d7f538d2b279e8649f78c2248aab5317697024d9`（2026-10-29，main 分支当前提交） |
| `index.html` blob | `6a579d29b9921e8b40edebcd58b3429815b6025d` |
| 许可证 | MIT，Copyright (c) 2026 f0lkskill（全文见 `tool/mirrorcalc_reference/LICENSE.MirrorCalcWeb`） |

用户提供的解压目录 `MirrorCalcWeb-main/` 中 `index.html`、`LICENSE`、`README.md`、`镜息演算-项目交接.md`
四个文件的 git blob 哈希均与上述提交一致（`git hash-object` 对比 GitHub API），移植过程中未切换版本。

参考计算代码只用于**开发期差分验证**（`tool/mirrorcalc_reference/`），应用内的正式计算全部由 Dart 实现，
不包含 WebView 或 JavaScript 运行时。

## 2. 移植的函数

| 参考函数（index.html） | Dart 实现 | 说明 |
|---|---|---|
| `num` | `numOf` | 非有限数 → 0 |
| `excelRound` | `excelRound` | Excel ROUND，含参考的 1e6 / 1e-9 修正 |
| `excelInt` | `excelInt` | Excel INT，1e-9 内吸附到整数 |
| `Math.round` | `jsRound` | 半整数向 +∞（`-2.5 → -2`），与 Dart `round()` 不同 |
| `sanitizeNumber` | `sanitizeNumber` | 输入规范化：整数字段取整、非负 / 最小值钳制 |
| `clearInactiveCoins` | `clearInactiveCoins` | 未启用行清零 |
| `blankCoin` / `defaultState` / `normalize` | `MirrorCoin.blank` / `MirrorState.initial` / `normalize` | |
| `compute` | `computeMirror` | 核心计算 |
| `loopAvg` | `loopAverageClash` | 平均拼点 |
| `SWEEP_DEF` / `SWEEP_LABEL` / `applySweep` / `runSweep` | `SweepParam` / `applySweep` / `planSweep` / `runSweepSync` | 参数扫描 |
| `nextTurn` | `MirrorController.recordCurrent` | 只移植“写入回合”，见第 6 节差异 |

页面实际执行顺序（已核对 `bindEvents.writeBinding` → `refresh`）：

1. 每次输入：`sanitizeNumber(path, raw)` 写入状态；
2. 刷新：`clearInactiveCoins(S)` **修改状态**，随后 `compute(S)`；
3. 参数扫描：对状态快照逐点 `applySweep` → `normalize` → `compute`。

Dart 侧保持同样的调用顺序，差分测试覆盖整条管线，而不只是 `compute`。

## 3. 字段映射

（详见第 4 节公式。“整数”指输入时按 `Math.round` 取整。）

### 技能与全局参数

| 参考字段 | 界面名称 | 类型 / 单位 | 输入规则 |
|---|---|---|---|
| `coinCount` | 硬币数量 | 整数，枚 | 0～9 |
| `basePower` | 基础威力 | 整数 | ≥ 0 |
| `coinPower` | 硬币威力 | 整数 | ≥ 0（负向修正用“硬币威力加成”） |
| `capacity` | 攻击容量 | 整数倍数 | ≥ 1 |
| `atkLevel` | 攻击等级 | 整数 | ≥ 0 |
| `atkLevelBonus` | 攻击等级加成 | 整数 | 可为负 |
| `enemyLevel` | 敌方等级 | 整数 | ≥ 0 |
| `baseBonus` | 终础威力加成 | 整数 | 可为负 |
| `coinBonus` | 硬币威力加成 | 整数 | 可为负 |
| `clashBonus` | 拼点威力加成 | 整数 | 可为负；只影响拼点点数 |
| `z1` | 技能第一乘区 | **小数倍率**（0.1 = +10%） | 不取整 |
| `z2` | 技能第二乘区 | **小数倍率** | 不取整 |
| `counter` | 不可拼点反击 | 是 / 否 | |
| `joinClash` | 是否参与拼点 | 是 / 否 | |
| `crit` | 必定暴击 | 是 / 否 | |
| `reroll` | 是否重投 | 是 / 否 | |
| `rerollCount` | 重投次数 | 整数，次 | 0～9 |
| `rerollClash` | 重投是否参与拼点 | 是 / 否 | |
| `skillName` | 方案名称 | 文本 | 仅用于标识，不参与计算 |

参考的 `character`（人格名）未移植：本阶段不做人格系统。

### 逐行参数（硬币 1～9、重投 1～9，共 18 行）

| 参考字段 | 界面名称 | 类型 / 单位 | 作用范围 |
|---|---|---|---|
| `breath` | 呼吸法强度 | 整数，层，≥ 0 | 仅当前行（暴击部分） |
| `z2` | 单币第二乘区 | 小数倍率 | 仅当前行 |
| `h` | 单币硬币威力 | 整数 | **累计**：计入当前行及之后所有启用行的威力；计入拼点 |
| `i` | 终币特殊威力 | 整数 | **累计**：计入当前行及之后所有启用行的威力；**不**计入拼点 |
| `fixed` | 固定追伤 | 整数 | 仅当前行，**乘攻击容量**后加到伤害 |
| `extra` | 比例追伤（是否追伤） | 是 / 否 | 仅当前行 |
| `coef` | 追伤系数 | 小数倍率（0.5 = 50%） | 仅当前行，以本行已取整的 J 为基数 |

### 循环数据

| 参考字段 | 含义 | 空值规则 |
|---|---|---|
| `loop1`/`loop2`/`loop3` | 三组 × 6 回合伤害 | 参考中空输入视为 0；本应用区分“未填写”，求和时同样按 0 计 |
| `loop1c`/`loop2c`/`loop3c` | 三组 × 6 回合拼点 | `null` 不参与平均；本应用再细分“未填写”与“不参与平均”，两者都对应 `null` |

## 4. 计算公式（参考 compute 的实际行为）

```
levelDiff  = atkLevel + atkLevelBonus − enemyLevel
levelMod   = levelDiff / (|levelDiff| + 25)                 // 分母取绝对值
finalBase  = INT(basePower + baseBonus + (counter ? levelDiff/3 : 0))
finalCoin  = coinPower + coinBonus
powerTotal = basePower + baseBonus + finalCoin × coinCount  // 仅展示

逐行（idx 0..17，前 9 行为硬币，后 9 行为重投；k 为组内序号 1..9）：
  active  = 硬币行: k ≤ coinCount；重投行: reroll 且 k ≤ rerollCount
  sumH   += active ? h : 0;  sumI += active ? i : 0      // 含当前行
  N       = 硬币行: k；重投行: coinCount + k
  critPart = crit ? 0.2 : MIN(breath × 0.05 × 0.2, 0.2)
  F       = ROUND(critPart + z1 + levelMod, 2)           // 单币第一乘区
  m1      = 1 + z1 + F                                   // z1 在此再次出现，见第 5 节
  m2      = 1 + z2 + 单币z2
  powerBase = finalBase + finalCoin × N + sumH + sumI
  rawJ    = powerBase × m1 × m2 × capacity
  J       = active ? MAX(1, INT(rawJ)) : null            // 不计算追伤伤害，保底 1
  Nv      = extra ? INT((J ?? 0) × coef) : 0             // 比例追伤，基数为已取整的 J
  O       = active ? INT(J + Nv + fixed × capacity) : null

合计（只计启用行）：sumJ = ΣJ，sumN = ΣNv，sumK = Σfixed（未乘容量），total = sumO = ΣO
拼点 = (counter 或 不参与拼点) ? 0 : INT(
         basePower + baseBonus + finalCoin × coinCount + levelDiff/3 + clashBonus
       + (reroll 且 rerollClash ? finalCoin × rerollCount : 0)
       + Σh(启用硬币行) + (rerollClash ? Σh(启用重投行) : 0))
平均拼点 = 有值回合的 jsRound(平均)，无有值回合时为 0
```

## 5. 参考模型的行为与简化假设（原样保留，未修改）

1. **z1 计入两次**：`F` 中含 `z1`，`m1 = 1 + z1 + F` 又加一次 `z1`。实际效果是技能第一乘区按约两倍计入。
   本移植**原样保留**，差分测试用非零 z1 样例验证与参考一致；是否符合游戏机制未验证。
2. **全正面累计**：参考中每枚硬币的威力 = 基础 + 最终硬币威力 × 序号 N，相当于所有硬币均为正面。
   本应用在此基础上增加了正反面（第 8 节）；选择全部正面时与参考逐位一致。
3. **呼吸法为简化折算**：暴击部分 = `MIN(呼吸法 × 5% × 0.2, 0.2)`，即“暴击率 × 暴击加成”的线性折算，
   不是逐枚硬币的概率枚举，也不是精确的伤害期望。
4. **拼点为点数**：输出是拼点点数（硬币全正面时的威力总和），不是拼点胜率。
5. 拼点使用原始 `basePower + baseBonus`（不取整、不含反击加成），且不计终币特殊威力。
6. 伤害保底为 1（`MAX(1, INT(…))`），**没有**基础模式中的“威力 5%”保底、抗性、攻防等级乘区等。
7. 循环数据为手工记录的统计，不是战斗模拟。
8. 未启用行在页面刷新时被清零（`clearInactiveCoins`）。

高级计算与基础计算的公式**完全独立**，没有混合。

## 6. 与参考页面的有意差异（仅限界面层，不改变计算结果）

对合法输入，计算结果与参考完全一致；以下差异只影响“何时计算”与“如何输入”。

| 项目 | 参考页面 | 本应用 | 原因 |
|---|---|---|---|
| 非数字输入（字母、NaN、Infinity、科学计数法） | `num()` 视为 0 继续计算 | 显示错误，不输出结果 | 避免把误输入当作 0 |
| 硬币数量 / 重投次数留空 | 视为 0，刷新时**清空全部硬币行** | 视为未完成输入，暂停计算，不清空 | 防止删除数字重输时丢失数据 |
| 硬币数量 / 重投次数 > 9 | 输入框 max=9，但 `sanitizeNumber` 不钳制，刷新前按原值计算 | 显示“范围 0～9” | 与 `normalize` 的 0～9 一致 |
| 数值绝对值 | 无限制 | ≤ 99999 | 界面校验 |
| 整数字段的回写 | 键入时立即回写取整值 | 立即按取整值计算，失焦时回写 | 不打断输入 |
| 未启用行 | 刷新时清零（数据丢失） | 计算前对**计算副本**清零（结果与参考一致）；编辑器保留隐藏行的修正与正反面，重新启用时恢复 | 减少数量不应丢失配置 |
| 循环伤害留空 | 等同 0 | 显示为“未填写”，求和仍按 0 | 区分 0 与未填写 |
| 循环拼点 | `null` 不参与平均 | 区分“未填写”与“不参与平均”，两者都按 `null` | 同上 |
| 下一回合（nextTurn） | 写入、**自动存档**、**轻重置（清空硬币明细）**、回合前进 | “记录并进入下一回合”只写入并前进，不清空；另有“记录当前结果”。每次记录在内存中保存含正反面的完整输入快照，可“恢复此回合配置” | 记录不应悄悄清空参数 |
| 硬币威力输入 | 非负整数 | “加算 / 减算” + 非负数值，状态保存带符号值 | 支持减算硬币 |
| 扫描区间输入 | 非法值按 0 | 非法值显示错误，不允许开始 | 同第一行 |
| 扫描执行 | 同步一次算完，写入 localStorage | 每批 20 点让出事件循环，可取消；新任务使旧任务失效；输入变化后标记过期 | 不阻塞界面、避免误读 |
| 扫描结论 | 红点标“最佳取值” | “扫描区间内总伤害最高”，并注明不代表实战最优；图中另画拼点折线 | 不做未经证明的结论 |

新增的派生值（不在参考 `compute` 返回值中，由领域层在同一循环中累加）：

- `sumFixedPart`：启用行 Σ(固定追伤 × 攻击容量)，用于伤害构成；
- `compositionRemainder`：总伤害 −（直接伤害 + 比例追伤 + 固定追伤×容量），整数输入下为 0。

未移植：人格名 `character`、技能预设、存档与文件夹、拖拽、对比、撤销 / 重做、导入导出、分享、主题、开场动画与装饰、快捷键面板。

## 7. 验证方式

### 差分测试（参考 JavaScript ↔ Dart）

```bash
# 1. 从参考 index.html 原文提取计算代码（校验 blob 哈希，不匹配则拒绝）
node tool/mirrorcalc_reference/extract.mjs MirrorCalcWeb-main/index.html
# 2. 运行原始 JavaScript 生成期望值（确定性；重复生成哈希不变）
node tool/mirrorcalc_reference/generate_cases.mjs
# 3. Dart 读取期望值逐项比对
flutter test test/features/mirror_calculator/reference_diff_test.dart
```

fixture（`test/features/mirror_calculator/fixtures/reference_cases.json`，约 3 MB）包含：

| 部分 | 数量 | 比对内容 |
|---|---|---|
| 数值辅助函数 | 42 个输入 | `Math.round`、`excelRound(v, 2)`、`excelRound(v, 0)`、`excelInt`；覆盖负数、半整数、浮点整数边界、NaN / Infinity |
| 计算用例 | 289 个（手工 33、搜索得到的浮点吸附 6、固定种子 20261030 随机 250） | 规范化与清理后的状态、被清空的行、每行全部中间量（N、暴击、F、m1、m2、Σh、Σi、威力基数、乘区积、rawJ、J、取整损失、追伤取整前、追伤、固定追伤×容量、伤害）、各项合计、拼点、循环合计、平均拼点 |
| 直接 compute | 其中 99 个 | 不经 clearInactiveCoins 的 compute，覆盖未启用行带数据时的行为 |
| 参数扫描 | 26 个（含 4 个错误分支） | 错误文案、每点取值 / 总伤害 / 拼点，并确认扫描不修改状态 |

**容差为 0**：Dart 与 JavaScript 都使用 IEEE 754 双精度，移植保留了参考的运算顺序，
因此包括浮点中间值在内全部要求精确相等。差异报告会定位到“阶段 · 行 · 字段”。

变异检验（验证测试有效性，已还原）：

- 去掉 z1 的第二次计入 → 200 余个用例失败（例如 `page.sumJ: dart=48 js=53`）；
- 去掉 `excelInt` 的 1e-9 吸附 → 数值样本与 6 个搜索用例失败（`rawJ = 7.999999999999999` 等）。

### 其他测试

- `test/features/mirror_calculator/mirror_page_test.dart`：在界面中输入参考用例参数，结果与 fixture 一致；
  取整回写、非法输入、清空与撤销、模式切换保留状态、循环记录与平均、扫描过期标记、窄屏与文字放大无溢出；
- `test/features/mirror_calculator/sweep_controller_test.dart`：分批、取消、新任务覆盖旧任务、过期判定；
- `test/features/mirror_calculator/mirror_faces_test.dart`：正反面扩展的独立推导用例（见第 8 节）；
- `test/features/mirror_calculator/mirror_controller_test.dart`：旧状态载入（负硬币威力、缺省正反面）、快照恢复、扫描新增位置与符号；
- `integration_test/app_test.dart`：Windows 真机上的高级计算流程（输入、正反面切换、记录循环、扫描）。

### 尚未验证

- 参考模型本身与游戏实际伤害是否一致（包括 z1 计入两次是否为游戏机制）；
- Android、iOS、macOS、Linux 未构建。

## 8. 加减算与正反面扩展（本应用新增，参考项目没有）

### 8.1 正反面如何参与计算

普通硬币（第 1～9 行）与重投（第 1～9 行）各自选择 全部正面 / 全部反面 / 自定义，并可逐枚切换；
默认全部正面。正反面只改变威力累计中“最终硬币威力”被应用的次数 N：

```
普通硬币第 k 行：N = k − （截至本行的反面数）
重投第 k 行：    N = （硬币数量 − 已启用普通硬币中的反面数） + （k − 重投中截至本行的反面数）
威力 = 最终基础威力 + 最终硬币威力 × N + Σ单币硬币威力 + Σ终币特殊威力
```

即：起始威力为最终基础威力；正面应用最终硬币威力，反面不应用；已有累计（含逐币修正）保留到之后的硬币；
每次命中使用当时的累计威力。全部正面时 N 退化为参考的 `k` 与 `硬币数量 + k`，
浮点运算逐位相同，因此原有 358 项参考差分测试不需要任何改动即全部通过。

中性条件（等级差 0、乘区 0、无暴击、容量 1）下的验收用例：

| 序列 | 威力 | 总伤害 |
|---|---|---|
| 基础 4，+3，正正正 | 7、10、13 | 30 |
| 基础 4，+3，正反正 | 7、7、10 | 24 |
| 基础 4，+3，反正反 | 4、7、7 | 18 |
| 基础 4，+3，反反反 | 4、4、4 | 12 |
| 基础 10，−3，正正正 | 7、4、1 | 12 |
| 基础 10，−3，反反反 | 10、10、10 | 30 |

### 8.2 各项的处理

| 项目 | 行为 |
|---|---|
| 硬币威力 | “加算 / 减算” + 非负数值；状态保存带符号值。最终硬币威力 = 带符号硬币威力 + 硬币威力加成（加成只应用一次）。界面同时显示实际基础硬币威力与最终硬币威力 |
| 单币硬币威力 / 终币特殊威力 | 保持参考语义：**手动修正**，无论正反面都计入本行及之后的累计；不自动解析游戏技能的触发条件，本轮未增加“仅正面 / 仅反面”触发选项 |
| 单币第二乘区、呼吸法、固定追伤、比例追伤 | 只作用于本行，与正反面无关 |
| 反面 | 不等于未命中：仍造成伤害，照常结算固定追伤与比例追伤 |
| 比例追伤 | 以本行**实际**（含正反面）的不计算追伤伤害 J 为基数 |
| 暴击 | 与正反面相互独立；呼吸法暴击仍为线性折算的估算 |
| 拼点点数 | 保留参考算法与其全正面假设，**不随**命中正反面变化；界面以 Tooltip 说明；不是胜率 |
| 重投（简化模型） | 在全部普通硬币之后结算，从此时的累计威力继续，按重投自身的正反面逐次应用最终硬币威力；关闭重投时不影响任何伤害、累计或拼点 |
| 隐藏行 | 减少硬币数量 / 关闭重投时不参与计算，编辑器保留其修正与正反面，重新启用时恢复 |

### 8.3 状态、循环与扫描

- `MirrorState.faces`（18 行）缺失时默认全部正面；`loadState` 把负的硬币威力映射为“减算 + 绝对值”。
  本应用目前没有持久化或导入导出，因此不存在需要版本迁移的存储数据。
- 循环记录在内存中保存含正反面、加减算与隐藏行的完整输入快照；“恢复此回合配置”还原原序列。
  界面区分“已保存的记录结果”与“当前按编辑器参数重新计算的结果”，数值被手动修改的回合会标注。
- 参数扫描保留当前正反面与其他未扫描参数；扫描硬币数量 / 重投次数时，新增位置按**正面、无逐币修正**；
  扫描硬币威力时扫描值带上当前加减算符号；输入、正反面或符号变化后旧结果标记为过期。

### 8.4 保留的边界与简化（本轮未改动）

- 伤害保底仍为参考的 `MAX(1, INT(…))`：威力降至 0 以下时伤害仍为 1，不像基础计算那样拒绝输出；
- 单币第一乘区 ROUND 2 位、伤害 INT、z1 计入两次等规则不变；
- 不引入基础计算的抗性、攻防等级乘区、5% 保底等规则。

### 8.5 验证

- 混合正反面是参考项目不存在的能力，期望值按 8.1 的规则手工推导（`mirror_faces_test.dart`），不向参考项目索取答案；
- 全部正面兼容由原有参考差分测试与“旧状态默认全部正面”用例共同覆盖；
- 界面测试覆盖：顶部按钮与逐币表同步、加减算与加成、隐藏行保留、重投独立正反面、循环快照恢复、扫描保持序列并标记过期。
