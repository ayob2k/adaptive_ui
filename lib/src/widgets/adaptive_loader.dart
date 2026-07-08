import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../platform/platform_info.dart';
import 'ios26/ios26_loader.dart';

/// An adaptive loading indicator that renders platform-native styles.
///
/// On iOS 26+: A native Liquid Glass card with a `UIActivityIndicatorView`
/// inside — presented as a real `UIViewController` so `UIGlassEffect` renders
/// correctly.
///
/// On iOS <26: A [CupertinoActivityIndicator].
///
/// On Android: A Material [CircularProgressIndicator].
///
/// ## Inline usage (spinner in the widget tree)
/// ```dart
/// const AdaptiveLoader()
/// ```
///
/// ## Popup usage (glass dialog — dismiss with Navigator.pop)
/// ```dart
/// AdaptiveLoader.show(context, message: 'Saving…');
///
/// // To dismiss:
/// Navigator.pop(context);
/// ```
class AdaptiveLoader extends StatelessWidget {
  const AdaptiveLoader({
    super.key,
    this.message,
    this.color,
    this.size,
  });

  /// Optional label shown below the spinner (iOS 26+ popup only).
  final String? message;

  /// Tint colour of the spinner. Falls back to the platform default.
  final Color? color;

  /// Overrides the default glass card size on iOS 26+ inline widget.
  final Size? size;

  // ---------------------------------------------------------------------------
  // Popup API
  // ---------------------------------------------------------------------------

  /// Shows a full-screen loader popup.
  ///
  /// On iOS 26+: presents a native `UIViewController` with a Liquid Glass card
  /// over the Flutter content. The Flutter dialog holds the navigation state.
  ///
  /// Dismiss with:
  /// ```dart
  /// Navigator.pop(context);
  /// ```
  ///
  /// Or `await` the returned Future and it completes when the popup closes.
  static Future<void> show(
    BuildContext context, {
    String? message,
    Color? color,

    /// Background scrim colour. Defaults to 30 % opaque black.
    Color? barrierColor,

    /// Whether tapping the scrim dismisses the loader. Defaults to false.
    bool barrierDismissible = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      // On iOS 26+ the native VC is transparent so Flutter's barrier is the
      // only scrim. On other platforms it sits around the Flutter spinner.
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.35),
      builder: (_) => _LoaderDialog(
        message: message,
        color: color,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Inline widget build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS26OrHigher()) {
      return IOS26Loader(message: message, color: color, size: size);
    }
    if (PlatformInfo.isIOS) {
      return CupertinoActivityIndicator(color: color);
    }
    return CircularProgressIndicator(color: color, strokeWidth: 3);
  }
}

// ---------------------------------------------------------------------------
// Internal dialog widget
// ---------------------------------------------------------------------------

/// Transparent dialog widget whose lifecycle drives the native loader.
///
/// On iOS 26+: communicates with `iOS26LoaderManager` via a method channel.
///   - `initState` → native `show`
///   - `dispose`   → native `dismiss` (triggered by Navigator.pop)
///
/// On other platforms: shows a plain Flutter spinner.
class _LoaderDialog extends StatefulWidget {
  const _LoaderDialog({
    this.message,
    this.color,
    required this.barrierDismissible,
  });

  final String? message;
  final Color? color;
  final bool barrierDismissible;

  @override
  State<_LoaderDialog> createState() => _LoaderDialogState();
}

class _LoaderDialogState extends State<_LoaderDialog> {
  static int _nextId = 0;
  late final int _id;
  static const _managerChannel = MethodChannel('adaptive_ui/ios26_loader_manager');

  @override
  void initState() {
    super.initState();
    _id = _nextId++;
    if (_isNative) _showNative();
  }

  @override
  void dispose() {
    if (_isNative) _dismissNative();
    super.dispose();
  }

  bool get _isNative =>
      !kIsWeb && Platform.isIOS && PlatformInfo.isIOS26OrHigher();

  Future<void> _showNative() async {
    try {
      await _managerChannel.invokeMethod<void>('show', {
        'id': _id,
        if (widget.message != null) 'message': widget.message,
        if (widget.color != null) 'color': _colorToARGB(widget.color!),
        'isDark':
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark,
      });
    } catch (_) {}
  }

  void _dismissNative() {
    // Fire-and-forget from dispose — no async/await.
    _managerChannel.invokeMethod<void>('dismiss', {'id': _id}).ignore();
  }

  int _colorToARGB(Color c) =>
      (((c.a * 255.0).round() & 0xFF) << 24) |
      (((c.r * 255.0).round() & 0xFF) << 16) |
      (((c.g * 255.0).round() & 0xFF) << 8) |
      ((c.b * 255.0).round() & 0xFF);

  @override
  Widget build(BuildContext context) {
    if (_isNative) {
      // The native VC renders the visible UI; nothing needed from Flutter.
      return const SizedBox.shrink();
    }

    // Non-iOS 26+: Flutter spinner centered in the dialog.
    return Center(
      child: _FlutterLoaderCard(
        message: widget.message,
        color: widget.color,
      ),
    );
  }
}

/// Flutter-rendered glass-style card for non-iOS-26 platforms.
class _FlutterLoaderCard extends StatelessWidget {
  const _FlutterLoaderCard({this.message, this.color});

  final String? message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.grey.shade900.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);

    Widget spinner = PlatformInfo.isIOS
        ? CupertinoActivityIndicator(color: color)
        : CircularProgressIndicator(
            color: color,
            strokeWidth: 3,
          );

    if (message == null || message!.isEmpty) {
      return _card(cardColor, Padding(
        padding: const EdgeInsets.all(28),
        child: spinner,
      ));
    }

    return _card(
      cardColor,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            spinner,
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Color bg, Widget child) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.30),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
