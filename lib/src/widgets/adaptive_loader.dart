import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../platform/platform_info.dart';
import 'ios26/ios26_loader.dart';

/// An adaptive loading indicator that renders platform-native styles.
///
/// On iOS 26+: A native Liquid Glass card with a `UIActivityIndicatorView`
/// inside (via a platform view). Appears as a frosted-glass popup.
///
/// On iOS <26: A [CupertinoActivityIndicator].
///
/// On Android: A Material [CircularProgressIndicator].
///
/// ## Inline usage
/// ```dart
/// const AdaptiveLoader()
/// ```
///
/// ## Overlay usage
/// ```dart
/// final controller = AdaptiveLoader.show(context, message: 'Saving…');
/// // … later …
/// controller.dismiss();
/// ```
class AdaptiveLoader extends StatelessWidget {
  const AdaptiveLoader({
    super.key,
    this.message,
    this.color,
    this.size,
  });

  /// Optional label shown below the spinner (iOS 26+ only in the glass card).
  final String? message;

  /// Tint colour of the spinner. Falls back to the platform default.
  final Color? color;

  /// Overrides the default glass card size on iOS 26+. Ignored on other
  /// platforms.
  final Size? size;

  // ---------------------------------------------------------------------------
  // Overlay API
  // ---------------------------------------------------------------------------

  /// Inserts a full-screen overlay containing a centred [AdaptiveLoader].
  ///
  /// Returns an [AdaptiveLoaderController] whose [AdaptiveLoaderController.dismiss]
  /// removes the overlay.
  ///
  /// ```dart
  /// final controller = AdaptiveLoader.show(context, message: 'Loading…');
  /// await doWork();
  /// controller.dismiss();
  /// ```
  static AdaptiveLoaderController show(
    BuildContext context, {
    String? message,
    Color? color,
    Size? size,

    /// Background scrim colour. Defaults to 30 % opaque black.
    Color? barrierColor,

    /// Whether tapping the scrim dismisses the loader. Defaults to false.
    bool barrierDismissible = false,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _LoaderOverlay(
        message: message,
        color: color,
        size: size,
        barrierColor: barrierColor,
        onBarrierTap: barrierDismissible ? () => entry.remove() : null,
      ),
    );
    overlay.insert(entry);
    return AdaptiveLoaderController._(entry);
  }

  // ---------------------------------------------------------------------------
  // Widget build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS26OrHigher()) {
      return IOS26Loader(message: message, color: color, size: size);
    }
    if (PlatformInfo.isIOS) {
      return CupertinoActivityIndicator(color: color);
    }
    return CircularProgressIndicator(
      color: color,
      strokeWidth: 3,
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Returned by [AdaptiveLoader.show]. Call [dismiss] to remove the overlay.
class AdaptiveLoaderController {
  AdaptiveLoaderController._(this._entry);

  final OverlayEntry _entry;

  /// Removes the loader overlay from the screen.
  void dismiss() {
    _entry.remove();
  }
}

// ---------------------------------------------------------------------------
// Internal overlay widget
// ---------------------------------------------------------------------------

class _LoaderOverlay extends StatelessWidget {
  const _LoaderOverlay({
    this.message,
    this.color,
    this.size,
    this.barrierColor,
    this.onBarrierTap,
  });

  final String? message;
  final Color? color;
  final Size? size;
  final Color? barrierColor;
  final VoidCallback? onBarrierTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBarrierTap,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: barrierColor ?? Colors.black.withValues(alpha: 0.30),
        child: Center(
          child: AdaptiveLoader(message: message, color: color, size: size),
        ),
      ),
    );
  }
}
