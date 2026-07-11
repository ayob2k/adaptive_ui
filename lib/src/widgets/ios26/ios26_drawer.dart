import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS 26+ native drawer background using Liquid Glass.
///
/// Wraps the native `iOS26DrawerPlatformView` Swift implementation which
/// provides a `UIVisualEffectView` blur, a top specular highlight gradient,
/// and a right-edge separator for the authentic Apple Liquid Glass look.
///
/// The [child] is rendered on top of the native glass layer via a [Stack].
class IOS26DrawerBackground extends StatefulWidget {
  const IOS26DrawerBackground({super.key, required this.child});

  /// Flutter content rendered on top of the native glass background.
  final Widget child;

  @override
  State<IOS26DrawerBackground> createState() => _IOS26DrawerBackgroundState();
}

class _IOS26DrawerBackgroundState extends State<IOS26DrawerBackground> {
  MethodChannel? _channel;
  bool? _lastIsDark;

  bool get _isDark =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      try {
        await ch.invokeMethod('setBrightness', {'isDark': isDark});
        _lastIsDark = isDark;
      } catch (_) {
        // Ignore — platform view may not be ready yet
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return Stack(
        children: [
          // Native Liquid Glass layer fills the entire drawer area
          Positioned.fill(
            child: UiKitView(
              viewType: 'adaptive_ui/ios26_drawer',
              creationParams: {'isDark': _isDark},
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: (int id) {
                _channel = MethodChannel('adaptive_ui/ios26_drawer_$id');
                _lastIsDark = _isDark;
              },
            ),
          ),
          // Flutter content sits on top of the native glass
          widget.child,
        ],
      );
    }
    // Non-iOS fallback — render child without native layer
    return widget.child;
  }
}
