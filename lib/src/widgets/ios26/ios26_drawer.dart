import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS 26+ native drawer background with Liquid Glass appearance and animation.
///
/// Stacks:
///   1. Native `UIVisualEffectView` blur (via [UiKitView])
///   2. Flutter entrance animation: scale 0.96→1.0 + opacity 0→1 (spring curve)
///   3. One-shot diagonal glint sweep (the Liquid Glass "shimmer" signature)
///   4. The user's Flutter content
class IOS26DrawerBackground extends StatefulWidget {
  const IOS26DrawerBackground({
    super.key,
    required this.child,
    this.blurStyle = 'systemUltraThinMaterial',
    this.tintColor,
  });

  /// Flutter content rendered on top of the glass.
  final Widget child;

  /// `UIBlurEffect.Style` name sent to the native layer.
  /// Defaults to `systemUltraThinMaterial`.
  final String blurStyle;

  /// Optional colour tint applied at ~18 % opacity over the blur.
  final Color? tintColor;

  @override
  State<IOS26DrawerBackground> createState() => _IOS26DrawerBackgroundState();
}

class _IOS26DrawerBackgroundState extends State<IOS26DrawerBackground>
    with TickerProviderStateMixin {

  // ── Method-channel ───────────────────────────────────────────────────────
  MethodChannel? _channel;
  bool? _lastIsDark;

  bool get _isDark => MediaQuery.platformBrightnessOf(context) == Brightness.dark;

  int _colorToARGB(Color c) =>
      ((c.a * 255).round() & 0xff) << 24 |
      ((c.r * 255).round() & 0xff) << 16 |
      ((c.g * 255).round() & 0xff) << 8  |
      ((c.b * 255).round() & 0xff);

  // ── Entrance animation (scale + fade) ─────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  // ── Glint animation ──────────────────────────────────────────────────────
  late final AnimationController _glintCtrl;
  late final Animation<double> _glintProgress;

  @override
  void initState() {
    super.initState();

    // --- Entrance ---
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    // Scale: 0.96 → 1.0 with spring-like overshoot feel
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.fastEaseInToSlowEaseOut),
    );

    // Opacity: 0 → 1, snappy early ramp
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );

    // --- Glint ---
    _glintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Progress travels from -0.3 (off-screen left) to 1.3 (off-screen right)
    _glintProgress = Tween<double>(begin: -0.3, end: 1.3).animate(
      CurvedAnimation(parent: _glintCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entranceCtrl.forward();
      // Launch glint once the glass has started materialising
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _glintCtrl.forward();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNativeIfNeeded();
  }

  @override
  void didUpdateWidget(IOS26DrawerBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blurStyle != widget.blurStyle) {
      _channel?.invokeMethod('setBlurStyle', {'blurStyle': widget.blurStyle});
    }
    if (oldWidget.tintColor != widget.tintColor) {
      final tc = widget.tintColor;
      if (tc != null) {
        _channel?.invokeMethod('setTintColor', {'tintColor': _colorToARGB(tc)});
      } else {
        _channel?.invokeMethod('setTintColor', <String, dynamic>{});
      }
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _glintCtrl.dispose();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _syncNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      try {
        await ch.invokeMethod('setBrightness', {'isDark': isDark});
        _lastIsDark = isDark;
      } catch (_) {}
    }
  }

  void _onPlatformViewCreated(int id) {
    final ch = MethodChannel('adaptive_ui/ios26_drawer_$id');
    _channel = ch;
    _lastIsDark = _isDark;
    final tc = widget.tintColor;
    if (tc != null) {
      ch.invokeMethod('setTintColor', {'tintColor': _colorToARGB(tc)});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return AnimatedBuilder(
        animation: Listenable.merge([_entranceCtrl, _glintCtrl]),
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              alignment: Alignment.centerRight, // scale from the right edge inward
              child: child,
            ),
          );
        },
        child: Stack(
          children: [
            // 1. Native Liquid Glass background
            Positioned.fill(
              child: UiKitView(
                viewType: 'adaptive_ui/ios26_drawer',
                creationParams: {
                  'isDark': _isDark,
                  'blurStyle': widget.blurStyle,
                  if (widget.tintColor != null)
                    'tintColor': _colorToARGB(widget.tintColor!),
                },
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: _onPlatformViewCreated,
              ),
            ),

            // 2. Diagonal glint sweep (Liquid Glass signature shimmer)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glintProgress,
                builder: (context, _) => CustomPaint(
                  painter: _GlintPainter(
                    progress: _glintProgress.value,
                    isDark: _isDark,
                  ),
                ),
              ),
            ),

            // 3. Flutter content
            widget.child,
          ],
        ),
      );
    }

    // Non-iOS fallback
    return widget.child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glint painter
// ─────────────────────────────────────────────────────────────────────────────

/// Paints a single diagonal light-streak that sweeps across the drawer surface.
/// This is the characteristic Liquid Glass "glint" animation.
class _GlintPainter extends CustomPainter {
  final double progress; // -0.3 … 1.3
  final bool isDark;

  const _GlintPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Only paint when the glint is actually crossing the surface
    if (progress <= 0.0 || progress >= 1.0) return;

    // Centre x of the glint band
    final cx = size.width * progress;
    // Width of the glint band (~40 % of drawer width)
    final bandW = size.width * 0.42;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // The gradient is centred on cx, fading to transparent on both sides
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: isDark ? 0.06 : 0.16),
          Colors.white.withValues(alpha: isDark ? 0.09 : 0.22),
          Colors.white.withValues(alpha: isDark ? 0.06 : 0.16),
          Colors.transparent,
        ],
        stops: [
          math.max(0.0, (cx - bandW) / size.width),
          math.max(0.0, (cx - bandW * 0.25) / size.width),
          (cx / size.width).clamp(0.0, 1.0),
          math.min(1.0, (cx + bandW * 0.25) / size.width),
          math.min(1.0, (cx + bandW) / size.width),
        ],
      ).createShader(rect);

    // Slight diagonal tilt (classic Liquid Glass glint angle)
    canvas.save();
    canvas.transform(
      Matrix4.skewX(-0.12).storage, // ~7° tilt
    );
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlintPainter old) =>
      progress != old.progress || isDark != old.isDark;
}
