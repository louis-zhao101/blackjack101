import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/strategy.dart' as st;
import '../../engine/variants.dart';
import '../../state/appearance_provider.dart';
import '../../state/settings_provider.dart';
import '../theme/appearance.dart';
import 'game_button.dart';

const _dealerRanks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'];
const _hardTotals = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
const _softTotals = [13, 14, 15, 16, 17, 18, 19, 20];
const _pairRanks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'];

({Color bg, Color fg}) _actionStyle(st.Action a) {
  switch (a) {
    case st.Action.hit:
      return (bg: const Color(0xFFD98C45), fg: const Color(0xFF21160A)); // amber
    case st.Action.stand:
      return (bg: const Color(0xFF49A178), fg: const Color(0xFF0C1A12)); // green
    case st.Action.double:
      return (bg: const Color(0xFF5285C4), fg: Colors.white); // blue
    case st.Action.split:
      return (bg: const Color(0xFF9270C4), fg: Colors.white); // purple
    case st.Action.surrender:
      return (bg: const Color(0xFFBE5A5A), fg: Colors.white); // red
  }
}

String _actionFull(st.Action a) => switch (a) {
      st.Action.hit => 'Hit',
      st.Action.stand => 'Stand',
      st.Action.double => 'Double',
      st.Action.split => 'Split',
      st.Action.surrender => 'Surrender',
    };

enum _ChartTab { hard, soft, pair }

class StrategyChart extends ConsumerStatefulWidget {
  const StrategyChart({super.key});

  @override
  ConsumerState<StrategyChart> createState() => _StrategyChartState();
}

class _StrategyChartState extends ConsumerState<StrategyChart> {
  _ChartTab _tab = _ChartTab.hard;
  String? _selected; // "tab|value|dealer"

  @override
  Widget build(BuildContext context) {
    final ruleSet = ref.watch(settingsProvider).ruleSet;

    final rows = switch (_tab) {
      _ChartTab.hard => _hardTotals.map((t) => (label: '$t', value: t as Object)).toList(),
      _ChartTab.soft =>
        _softTotals.map((t) => (label: 'A,${t - 11}', value: t as Object)).toList(),
      _ChartTab.pair => _pairRanks.map((r) => (label: '$r,$r', value: r as Object)).toList(),
    };
    final handType = switch (_tab) {
      _ChartTab.hard => st.HandType.hard,
      _ChartTab.soft => st.HandType.soft,
      _ChartTab.pair => st.HandType.pair,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tabs(),
        const SizedBox(height: 10),
        _legend(ruleSet),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            const headerW = 40.0;
            final col = (c.maxWidth - headerW) / _dealerRanks.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: headerW, height: 22),
                    for (final r in _dealerRanks)
                      Expanded(
                        child: SizedBox(
                          height: 22,
                          child: Center(
                            child: Text(r,
                                style: const TextStyle(
                                    color: AppTokens.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                ),
                for (final row in rows)
                  Row(
                    children: [
                      SizedBox(
                        width: headerW,
                        height: col,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(row.label,
                                style: const TextStyle(
                                    color: AppTokens.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      for (final dr in _dealerRanks)
                        Expanded(child: _actionCell(handType, row.value, dr, ruleSet, col)),
                    ],
                  ),
              ],
            );
          },
        ),
        if (_selected != null) ...[
          const SizedBox(height: 12),
          _explanation(handType, ruleSet),
        ],
      ],
    );
  }

  Widget _tabs() {
    final labels = {
      _ChartTab.hard: 'Hard Totals',
      _ChartTab.soft: 'Soft Totals',
      _ChartTab.pair: 'Pairs',
    };
    final gold = ref.watch(appearanceProvider).gold;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in _ChartTab.values)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              selectionHaptic();
              setState(() {
                _tab = t;
                _selected = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _tab == t
                    ? gold.withValues(alpha: 0.16)
                    : const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _tab == t ? gold : const Color(0x22FFFFFF),
                  width: _tab == t ? 1.5 : 1,
                ),
              ),
              child: Text(labels[t]!,
                  style: TextStyle(
                      color: _tab == t ? gold : AppTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _legend(RuleSet ruleSet) {
    final items = [
      (st.Action.hit, 'H = Hit'),
      (st.Action.stand, 'S = Stand'),
      (st.Action.double, 'D = Double'),
      (st.Action.split, 'P = Split'),
      if (ruleSet.surrender != Surrender.none) (st.Action.surrender, 'R = Surrender'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final (a, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _actionStyle(a).bg,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
            ],
          ),
      ],
    );
  }

  Widget _actionCell(
      st.HandType handType, Object value, String dealer, RuleSet ruleSet, double col) {
    final action = st.getChartAction(handType, value, dealer, ruleSet);
    final style = _actionStyle(action);
    final key = '${handType.name}|$value|$dealer';
    final selected = _selected == key;
    return GestureDetector(
      onTap: () {
        selectionHaptic();
        setState(() => _selected = key);
      },
      child: SizedBox(
        height: col,
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: Container(
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(6),
              border: selected ? Border.all(color: Colors.white, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text(st.actionCode(action),
                style: TextStyle(color: style.fg, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _explanation(st.HandType handType, RuleSet ruleSet) {
    final parts = _selected!.split('|');
    final dealer = parts[2];
    final rawValue = parts[1];
    final value =
        handType == st.HandType.pair ? rawValue : (int.tryParse(rawValue) ?? rawValue);
    final action = st.getChartAction(handType, value, dealer, ruleSet);
    final style = _actionStyle(action);
    final desc = switch (handType) {
      st.HandType.pair => 'Pair of ${rawValue}s',
      st.HandType.soft => 'Soft $rawValue',
      st.HandType.hard => 'Hard $rawValue',
    };
    final explanation = st.chartExplanation(handType, value, dealer, ruleSet);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ref.watch(appearanceProvider).gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration:
                    BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(4)),
                alignment: Alignment.center,
                child: Text(st.actionCode(action),
                    style: TextStyle(color: style.fg, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${_actionFull(action)} — $desc vs dealer $dealer',
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTokens.textSecondary, size: 18),
                onPressed: () => setState(() => _selected = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(explanation,
              style: const TextStyle(
                  color: AppTokens.textSecondary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
