import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/strategy.dart' as st;
import '../../engine/variants.dart';
import '../../state/settings_provider.dart';
import '../theme/appearance.dart';

const _dealerRanks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'];
const _hardTotals = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
const _softTotals = [13, 14, 15, 16, 17, 18, 19, 20];
const _pairRanks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'];

({Color bg, Color fg}) _actionStyle(st.Action a) {
  switch (a) {
    case st.Action.hit:
      return (bg: const Color(0x8CEAB308), fg: const Color(0xFF1A1A1A));
    case st.Action.stand:
      return (bg: const Color(0x8C22C55E), fg: const Color(0xFF1A1A1A));
    case st.Action.double:
      return (bg: const Color(0x8C3B82F6), fg: Colors.white);
    case st.Action.split:
      return (bg: const Color(0x8CA855F7), fg: Colors.white);
    case st.Action.surrender:
      return (bg: const Color(0x8CEF4444), fg: Colors.white);
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
    final surrenderAllowed = ruleSet.surrender != Surrender.none;

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
        _legend(surrenderAllowed),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(),
              for (final row in rows) _dataRow(handType, row.label, row.value, surrenderAllowed),
            ],
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 12),
          _explanation(handType, surrenderAllowed),
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
    return Wrap(
      spacing: 8,
      children: [
        for (final t in _ChartTab.values)
          ChoiceChip(
            label: Text(labels[t]!),
            selected: _tab == t,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() {
                _tab = t;
                _selected = null;
              });
            },
          ),
      ],
    );
  }

  Widget _legend(bool surrenderAllowed) {
    final items = [
      (st.Action.hit, 'H = Hit'),
      (st.Action.stand, 'S = Stand'),
      (st.Action.double, 'D = Double'),
      (st.Action.split, 'P = Split'),
      if (surrenderAllowed) (st.Action.surrender, 'R = Surrender'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final (a, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 14, color: _actionStyle(a).bg),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
            ],
          ),
      ],
    );
  }

  Widget _headerRow() {
    return Row(
      children: [
        _cell('', isHeader: true),
        for (final r in _dealerRanks) _cell(r, isHeader: true),
      ],
    );
  }

  Widget _dataRow(st.HandType handType, String label, Object value, bool surrenderAllowed) {
    return Row(
      children: [
        _cell(label, isRowHeader: true),
        for (final dr in _dealerRanks)
          _actionCell(handType, value, dr, surrenderAllowed),
      ],
    );
  }

  Widget _actionCell(st.HandType handType, Object value, String dealer, bool surrenderAllowed) {
    final action = st.getChartAction(handType, value, dealer, surrenderAllowed);
    final style = _actionStyle(action);
    final key = '${handType.name}|$value|$dealer';
    final selected = _selected == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selected = key);
      },
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(4),
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: Text(st.actionCode(action),
            style: TextStyle(color: style.fg, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _cell(String text, {bool isHeader = false, bool isRowHeader = false}) {
    return Container(
      width: isRowHeader ? 44 : 30,
      height: 30,
      margin: const EdgeInsets.all(1),
      alignment: Alignment.center,
      child: Text(text,
          style: TextStyle(
              color: AppTokens.textSecondary,
              fontSize: isRowHeader ? 11 : 12,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _explanation(st.HandType handType, bool surrenderAllowed) {
    final parts = _selected!.split('|');
    final dealer = parts[2];
    final rawValue = parts[1];
    final value =
        handType == st.HandType.pair ? rawValue : (int.tryParse(rawValue) ?? rawValue);
    final action = st.getChartAction(handType, value, dealer, surrenderAllowed);
    final style = _actionStyle(action);
    final desc = switch (handType) {
      st.HandType.pair => 'Pair of ${rawValue}s',
      st.HandType.soft => 'Soft $rawValue',
      st.HandType.hard => 'Hard $rawValue',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
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
    );
  }
}
