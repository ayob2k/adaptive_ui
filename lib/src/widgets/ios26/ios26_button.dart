import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../style/sf_symbol.dart';

/// iOS 26 native button styles (Liquid Glass design)
enum IOS26ButtonStyle {
  /// Filled button with solid background (primary action)
  filled,

  /// Tinted button with translucent background
  tinted,

  /// Gray button with subtle background
  gray,

  /// Bordered button with outline
  bordered,

  /// Plain text button without background
  plain,

  /// Glass effect button with translucent blur
  glass,

  /// Prominent glass button with enhanced blur effect
  prominentGlass,
}

/// iOS 26 button size presets matching native design
enum IOS26ButtonSize {
  /// Small button (height: 28)
  small,

  /// Medium button (height: 36) - default
  medium,

  /// Large button (height: 44)
  large,
}

/// iOS 26 "Liquid Glass" style button implemented entirely with Flutter.
///
/// Historically this widget embedded a native UIKit button through a
/// `UiKitView` platform view. Platform views are composited on a separate
/// layer from the rest of the Flutter UI, which caused three recurring bugs:
///
///   * the native button painted *above* bottom sheets, dialogs and pushed
///     pages (z-order bleed),
///   * hiding it during route transitions produced a visible flash,
///   * returning to a page recreated the view and re-ran its entry animation.
///
/// Rendering the button with pure Flutter widgets eliminates all of those
/// problems: it lives in the normal widget tree and behaves exactly like any
/// other Flutter button. The glass styles reproduce the iOS 26 look with a
/// real [BackdropFilter] blur, a specular top highlight and a fine glass edge.
class IOS26Button extends StatefulWidget {
  /// Creates an iOS 26 style button with a text label
  const IOS26Button({
    super.key,
    required this.onPressed,
    required this.label,
    this.style = IOS26ButtonStyle.filled,
    this.size = IOS26ButtonSize.medium,
    this.color,
    this.textColor,
    this.enabled = true,
    this.padding,
    this.borderRadius,
    this.minSize,
    this.useSmoothRectangleBorder = true,
  }) : child = null,
       isChildMode = false,
       sfSymbol = null,
       alignment = Alignment.center;

  /// Creates an iOS 26 style button with a custom child widget
  const IOS26Button.child({
    super.key,
    required this.onPressed,
    required this.child,
    this.style = IOS26ButtonStyle.filled,
    this.size = IOS26ButtonSize.medium,
    this.color,
    this.enabled = true,
    this.padding,
    this.borderRadius,
    this.minSize,
    this.useSmoothRectangleBorder = true,
    this.alignment = Alignment.center,
  }) : label = '',
       textColor = null,
       isChildMode = true,
       sfSymbol = null;

  /// Creates an iOS 26 style button with an SF Symbol icon
  const IOS26Button.sfSymbol({
    super.key,
    required this.onPressed,
    required this.sfSymbol,
    this.style = IOS26ButtonStyle.glass,
    this.size = IOS26ButtonSize.medium,
    this.color,
    this.enabled = true,
    this.padding,
    this.borderRadius,
    this.minSize,
    this.useSmoothRectangleBorder = true,
  }) : label = '',
       textColor = null,
       child = null,
       isChildMode = false,
       alignment = Alignment.center;

  /// The callback that is called when the button is tapped
  final VoidCallback? onPressed;

  /// The text label of the button
  final String label;

  /// The custom child widget (used in .child() constructor)
  final Widget? child;

  /// The SF Symbol to display (used in .sfSymbol() constructor)
  final SFSymbol? sfSymbol;

  /// Whether this is child mode
  final bool isChildMode;

  /// The visual style of the button
  final IOS26ButtonStyle style;

  /// The size preset for the button
  final IOS26ButtonSize size;

  /// The color of the button (uses system blue if not specified)
  final Color? color;

  /// The color of the button text
  final Color? textColor;

  /// Whether the button is enabled
  final bool enabled;

  /// The amount of space to surround the child inside the button
  final EdgeInsetsGeometry? padding;

  /// The border radius of the button
  final BorderRadius? borderRadius;

  /// The minimum size of the button
  final Size? minSize;

  /// Whether to use smooth rectangle border (iOS 26+ only)
  /// When false, uses perfectly circular/capsule shape
  /// Default is true for smooth rectangle, set to false for circular
  final bool useSmoothRectangleBorder;

  /// How the child is aligned within the button background (child mode only).
  /// Defaults to [Alignment.center].
  final AlignmentGeometry alignment;

  @override
  State<IOS26Button> createState() => _IOS26ButtonState();
}

class _IOS26ButtonState extends State<IOS26Button> {
  bool _pressed = false;

  bool get _isEnabled => widget.enabled && widget.onPressed != null;

  bool get _isGlass =>
      widget.style == IOS26ButtonStyle.glass ||
      widget.style == IOS26ButtonStyle.prominentGlass;

  double get _height {
    switch (widget.size) {
      case IOS26ButtonSize.small:
        return 28.0;
      case IOS26ButtonSize.medium:
        return 36.0;
      case IOS26ButtonSize.large:
        return 44.0;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case IOS26ButtonSize.small:
        return 13.0;
      case IOS26ButtonSize.medium:
        return 15.0;
      case IOS26ButtonSize.large:
        return 17.0;
    }
  }

  FontWeight get _fontWeight =>
      widget.size == IOS26ButtonSize.large ? FontWeight.w600 : FontWeight.w500;

  BorderRadius _resolveRadius() {
    if (widget.borderRadius != null) return widget.borderRadius!;
    if (!widget.useSmoothRectangleBorder) {
      return BorderRadius.circular(1000); // capsule
    }
    switch (widget.size) {
      case IOS26ButtonSize.small:
        return BorderRadius.circular(8);
      case IOS26ButtonSize.medium:
        return BorderRadius.circular(10);
      case IOS26ButtonSize.large:
        return BorderRadius.circular(12);
    }
  }

  EdgeInsetsGeometry _resolvePadding() {
    if (widget.padding != null) return widget.padding!;
    // Icon-only buttons keep tight, symmetric padding so they can live inside
    // small fixed-size boxes (e.g. a 38x38 circular icon button).
    if (widget.sfSymbol != null) return const EdgeInsets.all(6);
    switch (widget.size) {
      case IOS26ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 4);
      case IOS26ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case IOS26ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
    }
  }

  Color get _accent => widget.color ?? CupertinoColors.activeBlue;

  bool _isDark(BuildContext context) =>
      CupertinoTheme.of(context).brightness == Brightness.dark ||
      MediaQuery.maybeOf(context)?.platformBrightness == Brightness.dark;

  void _handleTap() {
    if (!_isEnabled) return;
    HapticFeedback.mediumImpact();
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget button = _buildDecoratedButton(context);

    if (!widget.isChildMode) {
      button = ConstrainedBox(
        constraints: BoxConstraints(minHeight: _height),
        child: button,
      );
    }

    button = AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _isEnabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 120),
        child: button,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isEnabled ? _handleTap : null,
      onTapDown: _isEnabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _isEnabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _isEnabled ? () => setState(() => _pressed = false) : null,
      child: button,
    );
  }

  Widget _buildDecoratedButton(BuildContext context) {
    final radius = _resolveRadius();
    final content = Padding(
      padding: _resolvePadding(),
      child: FittedBox(fit: BoxFit.scaleDown, child: _buildContent(context)),
    );

    if (_isGlass) {
      return _buildGlass(context, radius, content);
    }
    return _buildSolid(context, radius, content);
  }

  // ── Solid (non-glass) styles ───────────────────────────────────────────────

  Widget _buildSolid(
    BuildContext context,
    BorderRadius radius,
    Widget content,
  ) {
    final isDark = _isDark(context);
    Color? background;
    BoxBorder? border;

    switch (widget.style) {
      case IOS26ButtonStyle.filled:
        background = _accent;
        break;
      case IOS26ButtonStyle.tinted:
        background = _accent.withValues(alpha: 0.15);
        break;
      case IOS26ButtonStyle.gray:
        background = isDark
            ? const Color(0xFF48484A) // systemGray4 dark
            : const Color(0xFFE5E5EA); // systemGray5 light
        break;
      case IOS26ButtonStyle.bordered:
        background = Colors.transparent;
        border = Border.all(color: _accent, width: 1.5);
        break;
      case IOS26ButtonStyle.plain:
        background = Colors.transparent;
        break;
      case IOS26ButtonStyle.glass:
      case IOS26ButtonStyle.prominentGlass:
        break; // handled elsewhere
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: border,
      ),
      child: content,
    );
  }

  // ── Liquid Glass styles ─────────────────────────────────────────────────────

  Widget _buildGlass(
    BuildContext context,
    BorderRadius radius,
    Widget content,
  ) {
    final isDark = _isDark(context);
    final prominent = widget.style == IOS26ButtonStyle.prominentGlass;

    // Base translucent fill. Prominent glass leans on the accent color for a
    // richer, more saturated pane; plain glass stays near-neutral so whatever
    // is behind it shows through.
    final Color fill;
    if (prominent) {
      fill = _accent.withValues(alpha: isDark ? 0.55 : 0.78);
    } else {
      fill = (widget.color ?? Colors.white).withValues(
        alpha: widget.color != null ? 0.28 : (isDark ? 0.18 : 0.30),
      );
    }

    final borderColor = Colors.white.withValues(alpha: isDark ? 0.20 : 0.55);

    // Specular highlight — a soft light band across the top that sells the
    // "glass" sheen. Stronger in light mode.
    final highlight = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: isDark ? 0.22 : 0.45),
        Colors.white.withValues(alpha: 0.06),
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.45, 1.0],
    );

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              // Subtle inner-edge lift, kept inside the clip.
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.15),
                blurRadius: 0.5,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: highlight,
                  ),
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    );
  }

  // ── Content (label / child / icon) ──────────────────────────────────────────

  Widget _buildContent(BuildContext context) {
    final foreground = _foregroundColor(context);

    if (widget.isChildMode) {
      return DefaultTextStyle.merge(
        style: TextStyle(
          color: foreground,
          fontSize: _fontSize,
          fontWeight: _fontWeight,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: widget.child!,
        ),
      );
    }

    if (widget.sfSymbol != null) {
      return Icon(
        _iconForSFSymbol(widget.sfSymbol!.name),
        size: widget.sfSymbol!.size,
        color: widget.sfSymbol!.color ?? foreground,
      );
    }

    return Text(
      widget.label,
      style: TextStyle(
        color: foreground,
        fontSize: _fontSize,
        fontWeight: _fontWeight,
        letterSpacing: -0.2,
      ),
    );
  }

  Color _foregroundColor(BuildContext context) {
    if (widget.textColor != null) return widget.textColor!;
    final isDark = _isDark(context);
    switch (widget.style) {
      case IOS26ButtonStyle.filled:
        return Colors.white;
      case IOS26ButtonStyle.tinted:
      case IOS26ButtonStyle.bordered:
      case IOS26ButtonStyle.plain:
        return _accent;
      case IOS26ButtonStyle.gray:
        return isDark ? Colors.white : Colors.black;
      case IOS26ButtonStyle.glass:
        return isDark ? Colors.white : Colors.black;
      case IOS26ButtonStyle.prominentGlass:
        return Colors.white;
    }
  }

  /// Maps common SF Symbol names to their closest [CupertinoIcons] equivalent
  /// so `.sfSymbol` buttons still render meaningfully without a native view.
  IconData _iconForSFSymbol(String name) {
    switch (name) {
      case 'chevron.left':
      case 'chevron.backward':
        return CupertinoIcons.chevron_left;
      case 'chevron.right':
      case 'chevron.forward':
        return CupertinoIcons.chevron_right;
      case 'chevron.up':
        return CupertinoIcons.chevron_up;
      case 'chevron.down':
        return CupertinoIcons.chevron_down;
      case 'heart':
        return CupertinoIcons.heart;
      case 'heart.fill':
        return CupertinoIcons.heart_fill;
      case 'star':
        return CupertinoIcons.star;
      case 'star.fill':
        return CupertinoIcons.star_fill;
      case 'bookmark':
        return CupertinoIcons.bookmark;
      case 'bookmark.fill':
        return CupertinoIcons.bookmark_fill;
      case 'square.and.arrow.up':
        return CupertinoIcons.share;
      case 'square.and.arrow.down':
        return CupertinoIcons.arrow_down_doc;
      case 'ellipsis':
        return CupertinoIcons.ellipsis;
      case 'ellipsis.circle':
        return CupertinoIcons.ellipsis_circle;
      case 'plus':
        return CupertinoIcons.plus;
      case 'plus.circle':
        return CupertinoIcons.plus_circle;
      case 'plus.circle.fill':
        return CupertinoIcons.plus_circle_fill;
      case 'minus':
        return CupertinoIcons.minus;
      case 'xmark':
        return CupertinoIcons.xmark;
      case 'xmark.circle.fill':
        return CupertinoIcons.xmark_circle_fill;
      case 'checkmark':
        return CupertinoIcons.checkmark;
      case 'trash':
        return CupertinoIcons.delete;
      case 'trash.fill':
        return CupertinoIcons.delete_solid;
      case 'pencil':
        return CupertinoIcons.pencil;
      case 'gear':
      case 'gearshape':
        return CupertinoIcons.gear;
      case 'square.and.pencil':
        return CupertinoIcons.square_pencil;
      case 'magnifyingglass':
        return CupertinoIcons.search;
      case 'bell':
        return CupertinoIcons.bell;
      case 'bell.fill':
        return CupertinoIcons.bell_fill;
      case 'person':
        return CupertinoIcons.person;
      case 'person.fill':
        return CupertinoIcons.person_fill;
      case 'house':
        return CupertinoIcons.house;
      case 'house.fill':
        return CupertinoIcons.house_fill;
      case 'paperplane':
        return CupertinoIcons.paperplane;
      case 'paperplane.fill':
        return CupertinoIcons.paperplane_fill;
      case 'arrow.left':
        return CupertinoIcons.arrow_left;
      case 'arrow.right':
        return CupertinoIcons.arrow_right;
      case 'arrow.clockwise':
        return CupertinoIcons.arrow_clockwise;
      case 'square.grid.2x2':
        return CupertinoIcons.square_grid_2x2;
      case 'list.bullet':
        return CupertinoIcons.list_bullet;
      default:
        return CupertinoIcons.circle_fill;
    }
  }
}
