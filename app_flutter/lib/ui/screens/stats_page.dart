import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/stats.dart';
import '../../engine/strategy.dart' as st;
import '../../state/auth_provider.dart';
import '../../state/stats_provider.dart';
import '../auth_screen.dart';
import '../theme/appearance.dart';
import '../widgets/game_button.dart';

const _good = Color(0xFF6EE7B7);
const _ok = Color(0xFFF0C84A);
const _warn = Color(0xFFFC8181);

String _actionName(st.Action a) => switch (a) {
      st.Action.hit => 'Hit',
      st.Action.stand => 'Stand',
      st.Action.double => 'Double',
      st.Action.split => 'Split',
      st.Action.surrender => 'Surrender',
    };

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authStateProvider).value != null;
    if (!loggedIn) return const _StatsSignInGate();

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
    final chronological = summaries.reversed.toList();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Your Statistics',
                  style: TextStyle(
                      color: AppTokens.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: withHaptic(() => _confirmClear(context, ref)),
                child: const Text('Clear History'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryCard(label: 'Total Hands', value: '$totalHands'),
              _SummaryCard(
                  label: 'Overall Accuracy',
                  value: '$overallAccuracy%',
                  color: _accColor(overallAccuracy.toDouble())),
              _SummaryCard(
                  label: 'Best Streak',
                  value: '$bestStreak',
                  color: bestStreak >= 10 ? _good : (bestStreak >= 5 ? _ok : null)),
              _SummaryCard(
                  label: 'Total P&L',
                  value: '${totalPL >= 0 ? '+' : ''}\$$totalPL',
                  color: totalPL >= 0 ? _good : _warn),
              _SummaryCard(label: 'Sessions', value: '${stats.sessions.length}'),
              if (bestSession > 0)
                _SummaryCard(
                    label: 'Best Session',
                    value: '${bestSession.toStringAsFixed(0)}%',
                    color: bestSession >= 90 ? _good : _ok),
            ],
          ),
          if (chronological.length > 1) ...[
            const SizedBox(height: 28),
            _sectionTitle('Accuracy Over Sessions'),
            const SizedBox(height: 12),
            SizedBox(height: 220, child: _AccuracyChart(summaries: chronological)),
          ],
          const SizedBox(height: 28),
          _sectionTitle('Session History'),
          const SizedBox(height: 8),
          _SessionHistory(summaries: summaries),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 28),
            _sectionTitle('Most Common Mistakes'),
            const SizedBox(height: 12),
            SizedBox(height: 240, child: _MistakesChart(categories: categories.take(6).toList())),
            const SizedBox(height: 16),
            for (final m in mistakes.take(5)) _MistakeDetail(m: m),
          ],
        ],
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

  Color _accColor(double pct) => pct >= 80 ? _good : (pct >= 60 ? _ok : _warn);

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          color: AppTokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold));
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SummaryCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: color ?? AppTokens.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AccuracyChart extends StatelessWidget {
  final List<SessionSummary> summaries;
  const _AccuracyChart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < summaries.length; i++) FlSpot(i.toDouble(), summaries[i].correctPct),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
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
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= summaries.length) return const SizedBox.shrink();
                final label = summaries[i].isLive ? 'Now' : 'S${i + 1}';
                return Text(label,
                    style: const TextStyle(color: AppTokens.textSecondary, fontSize: 10));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: classicGreen.gold,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class _MistakesChart extends StatelessWidget {
  final List<MistakeCategory> categories;
  const _MistakesChart({required this.categories});

  @override
  Widget build(BuildContext context) {
    final maxY = categories.fold<int>(0, (m, c) => c.count > m ? c.count : m).toDouble();
    return BarChart(
      BarChartData(
        maxY: (maxY + 1),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: const TextStyle(color: AppTokens.textSecondary, fontSize: 10))),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 54,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= categories.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: 60,
                    child: Text(categories[i].label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTokens.textSecondary, fontSize: 9)),
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
                  color: const Color(0xD9E74C3C),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ]),
        ],
      ),
    );
  }
}

class _SessionHistory extends StatelessWidget {
  final List<SessionSummary> summaries;
  const _SessionHistory({required this.summaries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final s in summaries)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(AppTokens.radius),
              border: Border.all(
                  color: s.isLive ? classicGreen.gold.withValues(alpha: 0.4) : const Color(0x18FFFFFF)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: s.isLive
                      ? _liveBadge()
                      : Text(_date(s.date),
                          style: const TextStyle(color: AppTokens.textSecondary, fontSize: 13)),
                ),
                Expanded(child: _kv('${s.handsPlayed}', 'hands')),
                Expanded(
                  flex: 2,
                  child: _accuracyBadge(s),
                ),
                Expanded(
                  child: Text(
                    '${s.profitLoss >= 0 ? '+' : ''}\$${s.profitLoss}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: s.profitLoss >= 0 ? _good : _warn, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _liveBadge() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: classicGreen.gold, borderRadius: BorderRadius.circular(12)),
          child: Text('LIVE',
              style: TextStyle(
                  color: classicGreen.feltDark, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _kv(String v, String label) => Column(
        children: [
          Text(v,
              style: const TextStyle(color: AppTokens.textPrimary, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: AppTokens.textSecondary, fontSize: 10)),
        ],
      );

  Widget _accuracyBadge(SessionSummary s) {
    final color = s.correctPct >= 80 ? _good : (s.correctPct >= 60 ? _ok : _warn);
    return Text(
      '${s.correctCount}/${s.handsPlayed} (${s.correctPct.toStringAsFixed(0)}%)'
      '${s.longestStreak >= 10 ? '  🔥${s.longestStreak}' : ''}',
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}/${d.year}';
  }
}

class _MistakeDetail extends StatelessWidget {
  final MistakeSummary m;
  const _MistakeDetail({required this.m});

  @override
  Widget build(BuildContext context) {
    final kind = m.soft ? 'Soft ' : (m.handType == st.HandType.pair ? 'Pair of ' : 'Hard ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
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
                    style: const TextStyle(color: _warn, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('$kind${m.playerTotal} vs dealer ${m.dealerUpcard}',
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Played ${_actionName(m.playerAction)} → should ${_actionName(m.optimalAction)}',
              style: TextStyle(color: classicGreen.goldLight, fontSize: 13)),
          const SizedBox(height: 6),
          Text(m.explanation,
              style: const TextStyle(color: AppTokens.textSecondary, height: 1.4, fontSize: 13)),
        ],
      ),
    );
  }
}
