import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import 'ios26/ios26_drawer.dart';

/// An adaptive drawer that applies platform-native styling.
///
/// | Platform      | Appearance |
/// |---------------|-----------|
/// | **iOS 26+**   | Liquid Glass panel: native `UIVisualEffectView` blur, specular top-highlight, right-edge separator |
/// | **iOS <26**   | Cupertino-styled drawer using iOS system background colours |
/// | **Android**   | Standard Material 3 [Drawer] |
///
/// Use as the `drawer` or `endDrawer` prop of [AdaptiveScaffold]:
///
/// ```dart
/// AdaptiveScaffold(
///   scaffoldKey: _scaffoldKey,
///   drawer: AdaptiveDrawer(
///     child: ListView(
///       padding: EdgeInsets.zero,
///       children: [
///         AdaptiveDrawerHeader(title: 'My App'),
///         ListTile(
///           leading: Icon(Icons.home),
///           title: Text('Home'),
///           onTap: () => Navigator.pop(context),
///         ),
///       ],
///     ),
///   ),
///   body: ...,
/// )
/// ```
class AdaptiveDrawer extends StatelessWidget {
  const AdaptiveDrawer({super.key, required this.child, this.width});

  /// Content to display inside the drawer.
  final Widget child;

  /// Optional width override. Defaults to the platform's standard drawer width.
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS && PlatformInfo.isIOS26OrHigher()) {
      return _buildIOS26Drawer(context);
    }
    if (!kIsWeb && Platform.isIOS) {
      return _buildCupertinoDrawer(context);
    }
    // Android — standard Material 3 Drawer
    return Drawer(width: width, child: child);
  }

  Widget _buildIOS26Drawer(BuildContext context) {
    return Drawer(
      width: width,
      elevation: 0,
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: IOS26DrawerBackground(
        // Ensure list tiles are transparent so the glass shows through
        child: Theme(
          data: Theme.of(context).copyWith(
            listTileTheme: const ListTileThemeData(
              tileColor: Colors.transparent,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCupertinoDrawer(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Drawer(
      width: width,
      elevation: 0,
      backgroundColor: isDark
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF2F2F7),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      child: child,
    );
  }
}

/// An adaptive drawer header for use inside [AdaptiveDrawer].
///
/// | Platform      | Appearance |
/// |---------------|-----------|
/// | **iOS 26+**   | Translucent glass gradient header with bottom separator |
/// | **iOS <26**   | Solid Cupertino tinted header |
/// | **Android**   | Material [DrawerHeader] |
///
/// ```dart
/// AdaptiveDrawerHeader(
///   title: 'My App',
///   subtitle: 'v1.0',
///   leading: Icon(Icons.auto_awesome, color: Colors.white),
/// )
/// ```
class AdaptiveDrawerHeader extends StatelessWidget {
  const AdaptiveDrawerHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.backgroundColor,
    this.textColor,
  });

  /// Primary title text.
  final String title;

  /// Optional subtitle beneath the title.
  final String? subtitle;

  /// Optional leading widget (icon, avatar, etc.).
  final Widget? leading;

  /// Background colour override.
  /// - iOS 26+: ignored — always uses the Liquid Glass gradient.
  /// - iOS <26: defaults to `CupertinoColors.systemBlue`.
  /// - Android: defaults to `colorScheme.primaryContainer`.
  final Color? backgroundColor;

  /// Text colour override. Defaults to white on iOS and Android coloured headers.
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS && PlatformInfo.isIOS26OrHigher()) {
      return _buildIOS26Header(context);
    }
    if (!kIsWeb && Platform.isIOS) {
      return _buildCupertinoHeader(context);
    }
    // Android — Material DrawerHeader
    final effectiveBg =
        backgroundColor ?? Theme.of(context).colorScheme.primaryContainer;
    final effectiveTextColor =
        textColor ?? Theme.of(context).colorScheme.onPrimaryContainer;
    return DrawerHeader(
      decoration: BoxDecoration(color: effectiveBg),
      child: _buildHeaderContent(effectiveTextColor),
    );
  }

  Widget _buildIOS26Header(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final effectiveTextColor =
        textColor ?? (isDark ? Colors.white : Colors.black87);

    return Container(
      height: 140,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.09),
                  Colors.white.withValues(alpha: 0.02),
                ]
              : [
                  Colors.white.withValues(alpha: 0.32),
                  Colors.white.withValues(alpha: 0.06),
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.13)
                : Colors.white.withValues(alpha: 0.50),
            width: 0.5,
          ),
        ),
      ),
      child: _buildHeaderContent(effectiveTextColor),
    );
  }

  Widget _buildCupertinoHeader(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final effectiveBg =
        backgroundColor ??
        (isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemBlue);
    final effectiveTextColor = textColor ?? CupertinoColors.white;

    return Container(
      height: 140,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      color: effectiveBg,
      child: _buildHeaderContent(effectiveTextColor),
    );
  }

  Widget _buildHeaderContent(Color effectiveTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: effectiveTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: effectiveTextColor.withValues(alpha: 0.68),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
