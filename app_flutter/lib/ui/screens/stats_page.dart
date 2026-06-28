import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/stats.dart';
import '../../engine/strategy.dart' as st;
import '../../state/appearance_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/stats_provider.dart';
import '../auth_screen.dart';
import '../theme/appearance.dart';
import '../widgets/game_button.dart';

const _good = Color(0xFF6EE7B7);
const _ok = Color(0xFFF0C84A);
const _warn = Color(0xFFFC8181);

// Match the Account page's grouped-card look.
const _cardBg = Color(0x14FFFFFF);
const _tileBg = Color(0x24FFFFFF);
const _divider = Color(0x12FFFFFF);

const _recentLimit = 5;
const _chartWindow = 10;

String _actionName(st.Action a) => switch (a) {
      st.Action.hit => 'Hit',
      st.Action.stand => 'Stand',
      st.Action.double => 'Double',
      st.Action.split => 'Split',
      st.Action.surrender => 'Surrender',
    };

Color _accColor(double pct) => pct >= 80 ? _good : (pct >= 60 ? _ok : _warn);

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authStateProvider).value != null;
    if (!loggedIn) return const _StatsSignInGate();

    final theme = ref.watch(appearanceProvider);
    final stats = ref.watch(statsProvider);
    final hasLive = stats.currentSession != null && stats.currentSession!.hands.isNotEmpty;
    final allSessions = [
      ...stats.sessions,
      if (hasLive) stats.currentSession!,
    ];

    if (allSessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Play some hands to see your stats here.',
              style: TextStyle(color: AppTokens.textSecondary, fontSize: 16)),
        ),
      );
    }

    final summaries = allSessions.map(summarizeSession).toList();
    // Newest first (the live session, if any, sits at the end of allSessions).
    final recentFirst = summaries.reversed.toList();
    final mistakes = getCommonMistakes(allSessions);
    final categories = getMistakeCategories(allSessions);

    final allHands = allSessions.expand((s) => s.hands).toList();
    final totalHands = allHands.length;
    final overallAccuracy =
        totalHands > 0 ? (allHands.where((h) => h.wasCorrect).length / totalHands * 100).round() : 0;
    final totalPL = summaries.fold<int>(0, (a, s) => a + s.profitLoss);
    final bestStreak = computeLongestStreak(allHands);
    final eligible = summaries.where((s) => s.handsPlayed >= 5).map((s) => s.correctPct);
    final bestSession = eligible.isEmpty ? 0.0 : eligible.reduce((a, b) => a > b ? a : b);

    final shownSessions = recentFirst.take(_recentLimit).toList();
    final topMistakes = mistakes.take(5).toList();

    // Chart shows only the most recent sessions so the axis stays readable.
    final chartSummaries = summaries.length > _chartWindow
        ? summaries.sublist(summaries.length - _chartWindow)
        : summaries;
    final chartStart = summaries.length - chartSummaries.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _Section(
          title: 'Overview',
          children: [
            _StatRow(icon: Icons.style_outlined, label: 'Total hands', value: '$totalHands'),
            _StatRow(
              icon: Icons.track_changes,
              label: 'Overall accuracy',
              value: '$overallAccuracy%',
              valueColor: _accColor(overallAccuracy.toDouble()),
            ),
            _StatRow(
              icon: Icons.local_fire_department_outlined,
              label: 'Best streak',
              value: '$bestStreak',
              valueColor: bestStreak >= 10 ? _good : (bestStreak >= 5 ? _ok : null),
            ),
            _StatRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Total P&L',
              value: '${totalPL >= 0 ? '+' : ''}\$$totalPL',
              valueColor: totalPL >= 0 ? _good : _warn,
            ),
            _StatRow(icon: Icons.history, label: 'Sessions', value: '${stats.sessions.length}'),
            if (bestSession > 0)
              _StatRow(
                icon: Icons.emoji_events_outlined,
                label: 'Best session',
                value: '${bestSession.toStringAsFixed(0)}%',
                valueColor: bestSession >= 90 ? _good : _ok,
              ),
          ],
        ),
        if (recentFirst.length > 1) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Accuracy over sessions',
            trailing: summaries.length > _chartWindow
                ? const Text('last $_chartWindow',
                    style: TextStyle(color: AppTokens.textSecondary, fontSize: 12))
                : null,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 200,
                  child: _AccuracyChart(
                      summaries: chartSummaries, startIndex: chartStart, color: theme.gold),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'Session history',
          trailing: Text('${recentFirst.length} total',
              style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
          children: [
            for (var i = 0; i < shownSessions.length; i++) ...[
              if (i > 0) const _Divider(),
              _SessionTile(s: shownSessions[i], theme: theme),
            ],
            if (recentFirst.length > shownSessions.length) ...[
              const _Divider(),
              _StatRow(
                icon: Icons.unfold_more,
                label: 'View all ${recentFirst.length} sessions',
                onTap: () => _showAllSessions(context, theme, recentFirst),
              ),
            ],
          ],
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Common mistakes',
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: SizedBox(
                  height: 220,
                  child: _MistakesChart(categories: categories.take(5).toList(), color: theme.gold),
                ),
              ),
              for (final m in topMistakes) ...[
                const _Divider(),
                _MistakeTile(m: m),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'Manage',
          children: [
            _StatRow(
              icon: Icons.delete_sweep_outlined,
              label: 'Clear history',
              danger: true,
              onTap: () => _confirmClear(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  void _showAllSessions(BuildContext context, AppearanceTheme theme, List<SessionSummary> sessions) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: theme.feltDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: theme.feltBorder),
            left: BorderSide(color: theme.feltBorder),
            right: BorderSide(color: theme.feltBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTokens.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 6),
                  child: Text('All sessions',
                      style: TextStyle(
                          color: AppTokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const _Divider(),
                    itemBuilder: (_, i) => _SessionTile(s: sessions[i], theme: theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all session history?'),
        content: const Text('This removes all saved sessions. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: withHaptic(() => Navigator.pop(context)),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: withHaptic(() {
              ref.read(statsProvider.notifier).clearHistory();
              Navigator.pop(context);
            }),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const _Section({required this.title, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: _divider, margin: const EdgeInsets.symmetric(vertical: 2));
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool danger;
  const _StatRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? _warn : AppTokens.textPrimary;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _tileBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (value != null)
            Text(value!,
                style: TextStyle(
                    color: valueColor ?? AppTokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold))
          else if (onTap != null)
            const Icon(Icons.chevron_right, color: AppTokens.textSecondary, size: 20),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: withHaptic(onTap), child: row);
  }
}

class _SessionTile extends StatelessWidget {
  final SessionSummary s;
  final AppearanceTheme theme;
  const _SessionTile({required this.s, required this.theme});

  @override
  Widget build(BuildContext context) {
    final accColor = _accColor(s.correctPct);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (s.isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration:
                      BoxDecoration(color: theme.gold, borderRadius: BorderRadius.circular(12)),
                  child: Text('LIVE',
                      style: TextStyle(
                          color: theme.feltDark, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Text(_date(s.date),
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${s.profitLoss >= 0 ? '+' : ''}\$${s.profitLoss}',
                style: TextStyle(
                    color: s.profitLoss >= 0 ? _good : _warn,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text('${s.handsPlayed} hands',
                  style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
              const Text('  ·  ', style: TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
              Text('${s.correctCount}/${s.handsPlayed} · ${s.correctPct.toStringAsFixed(0)}%',
                  style: TextStyle(color: accColor, fontSize: 12, fontWeight: FontWeight.w600)),
              if (s.longestStreak >= 10)
                Text('  🔥${s.longestStreak}',
                    style: const TextStyle(color: _ok, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}/${d.year}';
  }
}

class _MistakeTile extends StatefulWidget {
  final MistakeSummary m;
  const _MistakeTile({required this.m});

  @override
  State<_MistakeTile> createState() => _MistakeTileState();
}

class _MistakeTileState extends State<_MistakeTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final kind = m.soft ? 'Soft ' : (m.handType == st.HandType.pair ? 'Pair of ' : 'Hard ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(() => setState(() => _expanded = !_expanded)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0x33E74C3C), borderRadius: BorderRadius.circular(12)),
                  child: Text('${m.count}×',
                      style:
                          const TextStyle(color: _warn, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('$kind${m.playerTotal} vs dealer ${m.dealerUpcard}',
                      style: const TextStyle(
                          color: AppTokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.expand_more, color: AppTokens.textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('Played ${_actionName(m.playerAction)} → should ${_actionName(m.optimalAction)}',
                style: TextStyle(color: classicGreen.goldLight, fontSize: 13)),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(m.explanation,
                          style: const TextStyle(
                              color: AppTokens.textSecondary, height: 1.4, fontSize: 12.5)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsSignInGate extends StatelessWidget {
  const _StatsSignInGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights_outlined, size: 56, color: AppTokens.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'Track your progress',
                style: TextStyle(
                    color: AppTokens.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to save your hands and see accuracy, streaks, and your most common mistakes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTokens.textSecondary, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: withHaptic(() => showSignInSheet(context)),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccuracyChart extends StatelessWidget {
  final List<SessionSummary> summaries;
  final int startIndex;
  final Color color;
  const _AccuracyChart(
      {required this.summaries, required this.startIndex, required this.color});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < summaries.length; i++) FlSpot(i.toDouble(), summaries[i].correctPct),
    ];
    // Anchor labels at the last point and step backward so they never collide.
    final step = (summaries.length / 5).ceil();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xF20E1A13),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.x.toInt();
              final label = (i >= 0 && i < summaries.length && summaries[i].isLive)
                  ? 'Now'
                  : 'S${startIndex + i + 1}';
              return LineTooltipItem(
                '$label\n${s.y.toStringAsFixed(0)}%',
                TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              );
            }).toList(),
          ),
          getTouchedSpotIndicator: (bar, indexes) => indexes
              .map((_) => TouchedSpotIndicatorData(
                    FlLine(color: color.withValues(alpha: 0.45), strokeWidth: 1),
                    FlDotData(
                      getDotPainter: (s, _, _, _) => FlDotCirclePainter(
                        radius: 4,
                        color: color,
                        strokeColor: const Color(0xFF0E1A13),
                        strokeWidth: 2,
                      ),
                    ),
                  ))
              .toList(),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 25,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                  style: const TextStyle(color: AppTokens.textSecondary, fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= summaries.length) return const SizedBox.shrink();
                if ((summaries.length - 1 - i) % step != 0) return const SizedBox.shrink();
                final label = summaries[i].isLive ? 'Now' : 'S${startIndex + i + 1}';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label,
                      style: const TextStyle(color: AppTokens.textSecondary, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, _, _) =>
                  FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakesChart extends StatelessWidget {
  final List<MistakeCategory> categories;
  final Color color;
  const _MistakesChart({required this.categories, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxCount = categories.fold<int>(0, (m, c) => c.count > m ? c.count : m);
    final stepRaw = (maxCount / 4).ceil();
    final step = stepRaw < 1 ? 1 : stepRaw;
    final maxY = ((maxCount ~/ step) + 1) * step;
    return BarChart(
      BarChartData(
        maxY: maxY.toDouble(),
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: step.toDouble(),
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xF20E1A13),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItem: (group, _, rod, _) {
              final c = categories[group.x.toInt()];
              return BarTooltipItem(
                '${c.label}\n${c.count}×',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: step.toDouble(),
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: const TextStyle(color: AppTokens.textSecondary, fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= categories.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: 62,
                    child: Text(categories[i].label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTokens.textSecondary, fontSize: 9, height: 1.2)),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < categories.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: categories[i].count.toDouble(),
                width: 26,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.06)],
                ),
              ),
            ]),
        ],
      ),
    );
  }
}
