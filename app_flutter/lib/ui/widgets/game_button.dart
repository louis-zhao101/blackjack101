import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/appearance.dart';

/// Wraps any tappable child with a quick press-scale animation and a light
/// haptic on tap. Disabled when [onPressed] is null.
class TappableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  const TappableScale({super.key, required this.child, this.onPressed});

  @override
  State<TappableScale> createState() => _TappableScaleState();
}

class _TappableScaleState extends State<TappableScale> {
  double _scale = 1;
  bool get _enabled => widget.onPressed != null;
  void _set(double s) {
    if (_enabled) setState(() => _scale = s);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(0.93),
      onTapUp: (_) => _set(1),
      onTapCancel: () => _set(1),
      onTap: _enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

enum GameBtn { gold, outlined }

/// Themed pill button with built-in press animation + haptic.
class GameButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final GameBtn variant;
  final AppearanceTheme theme;

  /// When true the button fills the width given by its parent (e.g. inside an
  /// Expanded). When false it sizes to its label — required inside Wrap/Row so
  /// the Container's alignment doesn't make it expand to full width.
  final bool expand;

  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.variant = GameBtn.outlined,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final filled = variant == GameBtn.gold;
    final fg = filled ? theme.feltDark : AppTokens.textPrimary;
    return TappableScale(
      onPressed: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: filled ? theme.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: filled ? null : Border.all(color: theme.feltBorder, width: 1.5),
          ),
          alignment: expand ? Alignment.center : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                maxLines: 1,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}

/// Wraps a callback so it also fires a selection haptic. Use on Material
/// buttons (TextButton, NavigationBar, PopupMenu) that aren't [GameButton].
/// Returns null when [cb] is null so disabled states are preserved.
VoidCallback? withHaptic(VoidCallback? cb) => cb == null
    ? null
    : () {
        HapticFeedback.selectionClick();
        cb();
      };
