import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../../calculator/presentation/widgets/coin_controls.dart';
import '../../../calculator/presentation/widgets/number_field.dart';
import '../../../calculator/presentation/widgets/section_card.dart';
import '../../models/mirror_state.dart';
import '../mirror_controller.dart';
import '../mirror_format.dart';
import 'mirror_inputs.dart';

/// 首屏的技能参数：基础威力、硬币数量、加减算与硬币威力、普通硬币正反面。
class MirrorParamsCard extends StatelessWidget {
  const MirrorParamsCard({super.key, required this.controller});

  final MirrorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final palette = context.palette;
    return SectionCard(
      title: '技能参数',
      trailing: TextButton.icon(
        key: const ValueKey('mirror-reset'),
        onPressed: c.resetParams,
        style: TextButton.styleFrom(foregroundColor: palette.textSecondary),
        icon: Icon(Icons.restart_alt, color: palette.textSecondary),
        label: const Text('重置参数'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TwoColumnFields(
            left: MirrorFieldInput(
              controller: c,
              field: MirrorField.basePower,
              tooltip: '整数，≥ 0；与终础威力加成相加后取整得到最终基础威力（起始威力）',
            ),
            right: MirrorCountStepper(
              controller: c,
              field: MirrorField.coinCount,
              tooltip: '启用前几枚普通硬币（1～9）。减少数量时隐藏的行保留配置，不参与计算',
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 4),
          SignedPowerInput(
            isAdd: c.coinPowerAdd,
            onAddChanged: c.setCoinPowerAdd,
            controller: c.fieldText(MirrorField.coinPower),
            error: c.errorOf(MirrorField.coinPower.path),
            fieldKey: const ValueKey('mirror-field-coinPower'),
            signKey: const ValueKey('mirror-coin-power-sign'),
            prefixKey: const ValueKey('mirror-coin-power-prefix'),
            onFocusLost: () => c.commitField(MirrorField.coinPower),
            tooltip: '正面时对当前威力应用的变化值；反面不应用。“硬币威力加成”在高级参数中单独设置',
            footer: _EffectivePower(controller: c),
          ),
          const SizedBox(height: AppSpacing.lg + 4),
          MirrorFacePicker(controller: c, group: FaceGroup.coins),
        ],
      ),
    );
  }
}

/// 实际基础硬币威力与最终硬币威力（含加成），避免加成改变符号后误解。
class _EffectivePower extends StatelessWidget {
  const _EffectivePower({required this.controller});

  final MirrorController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final r = controller.result;
    String signed(double v) => v > 0 ? '+${mirrorNum(v)}' : mirrorNum(v);
    return Text(
      s == null || r == null
          ? '输入有误，暂无生效值'
          : '实际基础硬币威力 ${signed(s[MirrorField.coinPower])}'
                ' · 最终硬币威力 ${signed(r.finalCoin)}'
                '（含硬币威力加成 ${signed(s[MirrorField.coinBonus])}）',
      key: const ValueKey('mirror-coin-power-effective'),
      style: numeric(context.textStyles.bodySmall),
    );
  }
}

/// 一组硬币（普通硬币或重投）的正反面选择：分段控件 + 逐枚按钮。
class MirrorFacePicker extends StatelessWidget {
  const MirrorFacePicker({
    super.key,
    required this.controller,
    required this.group,
  });

  final MirrorController controller;
  final FaceGroup group;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final rows = [
      for (var i = group.offset; i < group.offset + mirrorMainCoins; i++)
        if (c.isRowShown(i)) i,
    ];
    final isReroll = group == FaceGroup.rerolls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(
          isReroll ? '重投正反面' : '硬币正反面',
          tooltip:
              '命中阶段的投掷结果：正面应用最终硬币威力，反面不应用，已有累计保留到之后的硬币。'
              '反面不等于未命中，仍造成伤害并结算追伤；不影响暴击，也不改变拼点点数。',
        ),
        SegmentedChoice<FaceSelection>(
          key: ValueKey('mirror-face-mode-${group.name}'),
          options: [for (final m in FaceSelection.values) (m, m.label)],
          selected: c.faceMode(group),
          onChanged: (m) => c.setFaceMode(group, m),
        ),
        const SizedBox(height: AppSpacing.md),
        if (rows.isEmpty)
          Text(
            isReroll ? '当前没有启用的重投。' : '当前没有启用的硬币。',
            style: context.textStyles.bodySmall,
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final row in rows)
                CoinFaceTile(
                  inkKey: ValueKey('mirror-face-toggle-$row'),
                  heads: c.faceOf(row) == MirrorFace.heads,
                  caption: isReroll
                      ? '重${row - group.offset + 1}'
                      : '${row + 1}',
                  semanticLabel:
                      '${isReroll ? '重投' : '硬币'}${row - group.offset + 1}：'
                      '${c.faceOf(row).label}面，点击切换',
                  onTap: () => c.toggleFace(row),
                ),
            ],
          ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('点击单枚可切换正反面', style: context.textStyles.bodySmall),
        ],
      ],
    );
  }
}

/// 重投设置（可折叠）：是否重投、次数、是否参与拼点与重投正反面。
class MirrorRerollCard extends StatelessWidget {
  const MirrorRerollCard({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final MirrorController controller;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final reroll = c.flag(MirrorFlag.reroll);
    final count = c.lastValid[MirrorField.rerollCount];
    final hasError = c.errorOf(MirrorField.rerollCount.path) != null;
    return CollapsibleCard(
      key: const ValueKey('mirror-reroll-card'),
      title: '重投',
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      summaryIsError: hasError,
      summary: hasError
          ? '重投次数输入有误'
          : !reroll
          ? '未启用'
          : '${mirrorNum(count)} 次 · ${c.faceMode(FaceGroup.rerolls).label}'
                ' · ${c.flag(MirrorFlag.rerollClash) ? '参与拼点' : '不参与拼点'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldGrid(
            children: [
              MirrorSwitchField(
                controller: c,
                flag: MirrorFlag.reroll,
                tooltip: '否：重投行不影响任何伤害、累计或拼点，配置保留',
              ),
              MirrorCountStepper(
                controller: c,
                field: MirrorField.rerollCount,
                enabled: reroll,
                tooltip: '启用前几行重投（1～9），在全部普通硬币之后依次结算',
              ),
              MirrorSwitchField(
                controller: c,
                flag: MirrorFlag.rerollClash,
                tooltip: '是：重投的最终硬币威力与单币硬币威力计入拼点点数（按全正面假设）',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg + 4),
          MirrorFacePicker(controller: c, group: FaceGroup.rerolls),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '简化重投模型：重投从全部普通硬币结算后的累计威力继续，'
            '按重投自身的正反面逐次应用最终硬币威力；不代表所有游戏重投技能的实际规则。',
            style: context.textStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// 高级参数（可折叠）：方案名称、威力加成、攻防等级与容量、拼点与暴击、技能乘区。
class MirrorAdvancedCard extends StatelessWidget {
  const MirrorAdvancedCard({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final MirrorController controller;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  static const _fields = {
    MirrorField.capacity,
    MirrorField.atkLevel,
    MirrorField.baseBonus,
    MirrorField.coinBonus,
    MirrorField.clashBonus,
    MirrorField.atkLevelBonus,
    MirrorField.enemyLevel,
    MirrorField.z1,
    MirrorField.z2,
  };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final counter = c.flag(MirrorFlag.counter);
    final errorCount = _fields.where((f) => c.errorOf(f.path) != null).length;
    String t(MirrorField f) => c.fieldText(f).text.trim();

    Widget field(MirrorField f, {String? tip, String? suffix}) =>
        MirrorFieldInput(controller: c, field: f, tooltip: tip, suffix: suffix);

    Widget group(String title, List<Widget> children, {String? tip}) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GroupTitle(title, tooltip: tip),
          FieldGrid(children: children),
        ],
      ),
    );

    return CollapsibleCard(
      key: const ValueKey('mirror-advanced-card'),
      title: '高级参数',
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      summaryIsError: errorCount > 0,
      summary: errorCount > 0
          ? '$errorCount 项输入有误'
          : '攻 ${t(MirrorField.atkLevel)} / 敌 ${t(MirrorField.enemyLevel)}'
                ' · 容量 ${t(MirrorField.capacity)}'
                ' · z1 ${t(MirrorField.z1)} / z2 ${t(MirrorField.z2)}\n'
                '加成 ${t(MirrorField.baseBonus)} / ${t(MirrorField.coinBonus)}'
                ' / ${t(MirrorField.clashBonus)}'
                ' · ${counter ? '反击' : '非反击'}'
                ' · ${c.flag(MirrorFlag.crit) ? '必定暴击' : '暴击按呼吸法'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('方案名称', tooltip: '仅用于标识当前配置，不参与计算'),
          ShellTextField(
            fieldKey: const ValueKey('mirror-plan-name'),
            controller: c.planName,
            keyboardType: TextInputType.text,
            hintText: '未命名方案',
          ),
          const SizedBox(height: AppSpacing.xl),
          group('威力加成', [
            field(MirrorField.baseBonus, tip: '整数，可为负；计入最终基础威力与拼点'),
            field(
              MirrorField.coinBonus,
              tip: '整数，可为负；与带符号的基础硬币威力相加得到最终硬币威力（只应用一次）',
            ),
            field(MirrorField.clashBonus, tip: '整数，可为负；只影响拼点点数'),
          ]),
          group('攻防等级与容量', [
            field(MirrorField.atkLevel, tip: '整数，≥ 0'),
            field(MirrorField.atkLevelBonus, tip: '整数，可为负'),
            field(MirrorField.enemyLevel, tip: '整数，≥ 0。重置参数时保留'),
            field(
              MirrorField.capacity,
              tip: '整数倍数，≥ 1。不计算追伤伤害与固定追伤都乘以容量；比例追伤以已乘容量的伤害为基数',
            ),
          ], tip: '等级差 = 攻击等级 + 攻击等级加成 − 敌方等级；修正 = 差 ÷ (|差| + 25)'),
          group('拼点与暴击', [
            MirrorSwitchField(
              controller: c,
              flag: MirrorFlag.counter,
              tooltip: '是：拼点点数为 0，最终基础威力额外加上 等级差 ÷ 3',
            ),
            MirrorSwitchField(
              controller: c,
              flag: MirrorFlag.joinClash,
              enabled: !counter,
              disabledText: '反击时不参与',
              tooltip: '否：拼点点数为 0',
            ),
            MirrorSwitchField(
              controller: c,
              flag: MirrorFlag.crit,
              tooltip: '是：暴击部分恒为 0.2，呼吸法强度不再生效。与正反面相互独立',
            ),
          ]),
          group('技能乘区', [
            field(
              MirrorField.z1,
              tip: '小数倍率（0.1 = +10%）。参考模型中会计入两次：进入单币第一乘区，并在乘区中再加一次',
              suffix: '倍率',
            ),
            field(
              MirrorField.z2,
              tip: '小数倍率（0.1 = +10%），与单币第二乘区相加',
              suffix: '倍率',
            ),
          ]),
        ],
      ),
    );
  }
}
