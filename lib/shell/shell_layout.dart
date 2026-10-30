import 'package:flutter/material.dart';

import '../features/settings/app_settings.dart';

/// 一级导航目的地。高级计算内部的“单技能计算 / 循环统计 / 参数扫描”属于页面内导航。
enum AppDestination {
  basic('基础计算', Icons.calculate_outlined, Icons.calculate),
  mirror('高级计算', Icons.insights_outlined, Icons.insights),
  settings('设置', Icons.settings_outlined, Icons.settings);

  const AppDestination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 实际使用的导航形态。
enum ShellNav {
  bottomBar('底部栏'),
  compactRail('紧凑侧栏'),
  expandedRail('展开侧栏');

  const ShellNav(this.label);
  final String label;

  bool get isRail => this != bottomBar;
}

/// 导航断点，按应用外壳的可用逻辑宽度判断（不看平台或横竖屏）。
abstract final class ShellBreakpoints {
  /// 自动模式下达到此宽度显示侧栏。
  static const double rail = 600;

  /// 达到此宽度侧栏可展开。
  static const double expandedRail = 840;

  /// 强制侧栏时的最小宽度；更窄时正文过窄，降级为底部栏。
  static const double forcedRailMin = 360;
}

@immutable
class ShellNavLayout {
  const ShellNavLayout(
    this.nav, {
    this.canExpand = false,
    this.degraded = false,
  });

  final ShellNav nav;

  /// 当前宽度是否允许展开侧栏（显示展开 / 收起按钮）。
  final bool canExpand;

  /// 用户偏好因窗口过窄未能完全满足（强制侧栏 → 紧凑侧栏或底部栏）。
  final bool degraded;
}

/// 由外壳宽度与用户偏好得出导航形态；纯函数，便于测试断点。
ShellNavLayout resolveShellNav({
  required double width,
  required NavLayoutPreference preference,
  required bool railExpanded,
}) {
  // 840 以下只使用紧凑侧栏。
  ShellNavLayout rail() => width >= ShellBreakpoints.expandedRail
      ? ShellNavLayout(
          railExpanded ? ShellNav.expandedRail : ShellNav.compactRail,
          canExpand: true,
        )
      : const ShellNavLayout(ShellNav.compactRail);

  switch (preference) {
    case NavLayoutPreference.bottom:
      return const ShellNavLayout(ShellNav.bottomBar);
    case NavLayoutPreference.rail:
      if (width < ShellBreakpoints.forcedRailMin) {
        return const ShellNavLayout(ShellNav.bottomBar, degraded: true);
      }
      return rail();
    case NavLayoutPreference.auto:
      if (width < ShellBreakpoints.rail) {
        return const ShellNavLayout(ShellNav.bottomBar);
      }
      return rail();
  }
}
