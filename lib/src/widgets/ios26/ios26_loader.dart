import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native iOS 26 loader widget with Liquid Glass card design.
///
/// Renders a `UIActivityIndicatorView` inside a `UIGlassEffect` card via a
/// platform view. Use this directly when you need the raw iOS 26 component;
/// prefer [AdaptiveLoader] for cross-platform code.
///
/// The card sizes itself to the [size] parameter. When [message] is provided
/// the default height is taller to accommodate the label below the spinner.
class IOS26Loader extends StatefulWidget {
  const IOS26Loader({
    super.key,
    this.message,
    this.color,
    this.size,
  });

  /// Optional label displayed below the spinner inside the glass card.
  final String? message;

  /// Tint colour of the activity indicator. Defaults to the system style.
  final Color? color;

  /// Explicit size for the glass card. If omitted, a sensible default is used:
  /// 88×88 when there is no [message], 120×128 when there is one.
  final Size? size;

  @override
  State<IOS26Loader> createState() => _IOS26LoaderState();
}

class _IOS26LoaderState extends State<IOS26Loader> {
  static int _nextId = 0;
  late final int _id;
  late final MethodChannel _channel;
  bool? _lastIsDark;

  @override
  void initState() {
    super.initState();
    _id = _nextId++;
    _channel = MethodChannel('adaptive_ui/ios26_loader_$_id');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    if (_lastIsDark != isDark) {
      try {
        await _channel.invokeMethod('setBrightness', {'isDark': isDark});
        _lastIsDark = isDark;
      } catch (_) {
        // Platform view may not be ready yet; safe to ignore.
      }
    }
  }

  Size get _resolvedSize {
    if (widget.size != null) return widget.size!;
    return widget.message != null && widget.message!.isNotEmpty
        ? const Size(120, 128)
        : const Size(88, 88);
  }

  Map<String, dynamic> _buildCreationParams() {
    return {
      'id': _id,
      'isDark': MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      if (widget.message != null && widget.message!.isNotEmpty)
        'message': widget.message,
      if (widget.color != null) 'color': _colorToARGB(widget.color!),
    };
  }

  int _colorToARGB(Color color) {
    return (((color.a * 255.0).round() & 0xFF) << 24) |
        (((color.r * 255.0).round() & 0xFF) << 16) |
        (((color.g * 255.0).round() & 0xFF) << 8) |
        ((color.b * 255.0).round() & 0xFF);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      final s = _resolvedSize;
      return SizedBox(
        width: s.width,
        height: s.height,
        child: UiKitView(
          viewType: 'adaptive_ui/ios26_loader',
          creationParams: _buildCreationParams(),
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }

    // Fallback — plain Cupertino indicator.
    return CupertinoActivityIndicator(color: widget.color);
  }
}
