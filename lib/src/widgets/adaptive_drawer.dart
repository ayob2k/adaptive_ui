import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import 'ios26/ios26_drawer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

/// Visual style variants for [AdaptiveDrawer].
///
/// On iOS 26+ all glass variants use native `UIVisualEffectView` blur;
/// on iOS <26 and Android they use [BackdropFilter] as a polyfill.
enum AdaptiveDrawerStyle {
  /// **Liquid Glass** — ultra-thin, very transparent blur (default).
  ///
  /// iOS 26+: `systemUltraThinMaterial` — lets the content behind show through
  /// clearly.  Identical to the material used in Apple's own iOS 26 sidebars.
  glass,

  /// **Frosted Glass** — regular material, noticeably more opaque than [glass].
  ///
  /// Good when the background content is visually busy and legibility matters.
  frosted,

  /// **Tinted Glass** — ultra-thin glass with a colour overlay.
  ///
  /// Set [AdaptiveDrawer.backgroundColor] to pick the tint.
  /// Defaults to the primary colour at low opacity when no colour is provided.
  tinted,

  /// **Filled** — fully opaque solid background, no blur effect.
  ///
  /// [AdaptiveDrawer.backgroundColor] controls the colour.
  filled,
}

// ─────────────────────────────────────────────────────────────────────────────
// AdaptiveDrawer
// ─────────────────────────────────────────────────────────────────────────────

/// An adaptive navigation drawer that applies platform-native styling.
///
/// | Platform    | `glass` / `frosted` / `tinted`               | `filled`               |
/// |-------------|----------------------------------------------|------------------------|
/// | iOS 26+     | Native `UIVisualEffectView` Liquid Glass blur | Solid opaque panel     |
/// | iOS <26     | `BackdropFilter` frosted-glass polyfill      | Solid opaque panel     |
/// | Android     | `BackdropFilter` frosted-glass polyfill      | Material 3 `Drawer`    |
///
/// ### Quick start
/// ```dart
/// AdaptiveScaffold(
///   scaffoldKey: _scaffoldKey,
///   drawer: AdaptiveDrawer(
///     child: Column(children: [
///       AdaptiveDrawerHeader(title: 'My App'),
///       AdaptiveDrawerItem(icon: Icons.home, label: 'Home', onTap: () {}),
///     ]),
///   ),
///   body: ...,
/// )
/// ```
///
/// ### Styles
/// ```dart
/// // Glassy (default)
/// AdaptiveDrawer(child: ...)
///
/// // More opaque frosted glass
/// AdaptiveDrawer(style: AdaptiveDrawerStyle.frosted, child: ...)
///
/// // Glass tinted blue
/// AdaptiveDrawer(
///   style: AdaptiveDrawerStyle.tinted,
///   backgroundColor: Colors.blue,
///   child: ...,
/// )
///
/// // Solid dark surface
/// AdaptiveDrawer(
///   style: AdaptiveDrawerStyle.filled,
///   backgroundColor: const Color(0xFF1C1C1E),
///   child: ...,
/// )
/// ```
class AdaptiveDrawer extends StatelessWidget {
  const AdaptiveDrawer({
    super.key,
    required this.child,
    this.style = AdaptiveDrawerStyle.glass,
    this.backgroundColor,
    this.width,
  });

  /// Content displayed inside the drawer.
  final Widget child;

  /// Visual style.  Defaults to [AdaptiveDrawerStyle.glass].
  final AdaptiveDrawerStyle style;

  /// Background colour.
  ///
  /// - `glass` / `frosted`: ignored (blur handles the look).
  /// - `tinted`: used as the tint colour at ~18 % opacity over the blur.
  ///   Defaults to the platform primary colour when null.
  /// - `filled`: the solid background.  Defaults to the iOS system background
  ///   or the Material surface colour.
  final Color? backgroundColor;

  /// Optional width override.  Defaults to each platform's standard value.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isIOS26 = !kIsWeb && Platform.isIOS && PlatformInfo.isIOS26OrHigher();
    final isIOS   = !kIsWeb && Platform.isIOS;

    if (style == AdaptiveDrawerStyle.filled) {
      return _buildFilledDrawer(context, isIOS: isIOS, isIOS26: isIOS26);
    }

    if (isIOS26) return _buildIOS26Drawer(context);
    if (isIOS)   return _buildBlurDrawer(context, sigma: _sigmaForStyle());
    return _buildBlurDrawer(context, sigma: _sigmaForStyle());
  }

  // ── iOS 26+ — native Liquid Glass ─────────────────────────────────────────

  Widget _buildIOS26Drawer(BuildContext context) {
    final tint = _effectiveTint(context);

    return Drawer(
      width: width,
      elevation: 0,
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: IOS26DrawerBackground(
        blurStyle: _blurStyleForStyle(),
        tintColor: style == AdaptiveDrawerStyle.tinted ? tint : null,
        child: _wrapContent(context),
      ),
    );
  }

  // ── iOS <26 / Android — BackdropFilter polyfill ────────────────────────────

  Widget _buildBlurDrawer(BuildContext context, {required double sigma}) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final tint   = _effectiveTint(context);

    return Drawer(
      width: width,
      elevation: 0,
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: ClipRect(
        child: Stack(
          children: [
            // Blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Base glass tint
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withValues(alpha: 0.04),
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.04),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.30),
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0.30),
                          ],
                  ),
                ),
              ),
            ),
            // Colour tint for tinted style
            if (style == AdaptiveDrawerStyle.tinted)
              Positioned.fill(
                child: Container(color: tint.withValues(alpha: 0.18)),
              ),
            // Specular top highlight
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, 0.4),
                    colors: isDark
                        ? [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.transparent,
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
            // Right-edge separator
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 0.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),
            // Content
            _wrapContent(context),
          ],
        ),
      ),
    );
  }

  // ── Filled (all platforms) ─────────────────────────────────────────────────

  Widget _buildFilledDrawer(
    BuildContext context, {
    required bool isIOS,
    required bool isIOS26,
  }) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    Color bgColor;

    if (backgroundColor != null) {
      bgColor = backgroundColor!;
    } else if (isIOS) {
      bgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    } else {
      bgColor = Theme.of(context).colorScheme.surface;
    }

    return Drawer(
      width: width,
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      child: child,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _wrapContent(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        listTileTheme: const ListTileThemeData(tileColor: Colors.transparent),
      ),
      child: child,
    );
  }

  Color _effectiveTint(BuildContext context) {
    if (backgroundColor != null) return backgroundColor!;
    if (!kIsWeb && Platform.isIOS) return CupertinoTheme.of(context).primaryColor;
    return Theme.of(context).colorScheme.primary;
  }

  String _blurStyleForStyle() {
    switch (style) {
      case AdaptiveDrawerStyle.glass:
      case AdaptiveDrawerStyle.tinted:
        return 'systemUltraThinMaterial';
      case AdaptiveDrawerStyle.frosted:
        return 'systemMaterial';
      case AdaptiveDrawerStyle.filled:
        return 'systemUltraThinMaterial'; // unused
    }
  }

  double _sigmaForStyle() {
    switch (style) {
      case AdaptiveDrawerStyle.glass:
      case AdaptiveDrawerStyle.tinted:
        return 18.0;
      case AdaptiveDrawerStyle.frosted:
        return 28.0;
      case AdaptiveDrawerStyle.filled:
        return 0.0;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AdaptiveDrawerHeader
// ─────────────────────────────────────────────────────────────────────────────

/// A header widget designed for use inside [AdaptiveDrawer].
///
/// | Platform    | Appearance |
/// |-------------|-----------|
/// | iOS 26+     | Translucent gradient matching the Liquid Glass panel |
/// | iOS <26     | Solid tinted header |
/// | Android     | Material [DrawerHeader] |
///
/// ```dart
/// AdaptiveDrawerHeader(
///   title: 'My App',
///   subtitle: 'Version 1.0',
///   leading: Icon(Icons.auto_awesome, color: Colors.white, size: 28),
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
    this.height = 140,
  });

  /// Primary title.
  final String title;

  /// Optional subtitle.
  final String? subtitle;

  /// Optional leading widget (icon, avatar, logo…).
  final Widget? leading;

  /// Background colour.
  /// - iOS 26+: ignored (always uses a Liquid Glass gradient).
  /// - iOS <26: defaults to `CupertinoColors.systemBlue`.
  /// - Android: defaults to `colorScheme.primaryContainer`.
  final Color? backgroundColor;

  /// Text colour.  Defaults to white on coloured backgrounds.
  final Color? textColor;

  /// Header height.  Defaults to `140`.
  final double height;

  @override
  Widget build(BuildContext context) {
    final isIOS26 = !kIsWeb && Platform.isIOS && PlatformInfo.isIOS26OrHigher();
    final isIOS   = !kIsWeb && Platform.isIOS;

    if (isIOS26) return _buildIOS26Header(context);
    if (isIOS)   return _buildCupertinoHeader(context);

    final bg  = backgroundColor ?? Theme.of(context).colorScheme.primaryContainer;
    final fg  = textColor ?? Theme.of(context).colorScheme.onPrimaryContainer;
    return DrawerHeader(
      decoration: BoxDecoration(color: bg),
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        alignment: Alignment.bottomLeft,
        child: _buildContent(fg),
      ),
    );
  }

  Widget _buildIOS26Header(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final fg     = textColor ?? (isDark ? Colors.white : Colors.black87);

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.11),
                  Colors.white.withValues(alpha: 0.03),
                ]
              : [
                  Colors.white.withValues(alpha: 0.38),
                  Colors.white.withValues(alpha: 0.07),
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.52),
            width: 0.5,
          ),
        ),
      ),
      child: _buildContent(fg),
    );
  }

  Widget _buildCupertinoHeader(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bg = backgroundColor ??
        (isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemBlue);
    final fg = textColor ?? CupertinoColors.white;

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      color: bg,
      child: _buildContent(fg),
    );
  }

  Widget _buildContent(Color fg) {
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
                  color: fg,
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
                    color: fg.withValues(alpha: 0.68),
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

// ─────────────────────────────────────────────────────────────────────────────
// AdaptiveDrawerItem
// ─────────────────────────────────────────────────────────────────────────────

/// A ready-made list item for [AdaptiveDrawer] that automatically adapts its
/// colours and shape to the current platform and drawer style.
///
/// ```dart
/// AdaptiveDrawerItem(
///   icon: Icons.home,
///   cupertinoIcon: CupertinoIcons.house_fill,
///   label: 'Home',
///   isSelected: true,
///   onTap: () { Navigator.pop(context); },
/// )
/// ```
class AdaptiveDrawerItem extends StatelessWidget {
  const AdaptiveDrawerItem({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.cupertinoIcon,
    this.trailing,
    this.isSelected = false,
    this.selectedColor,
    this.unselectedColor,
  }) : assert(
         icon != null || cupertinoIcon != null,
         'Provide at least one of icon or cupertinoIcon',
       );

  /// Label text.
  final String label;

  /// Called when the item is tapped.
  final VoidCallback onTap;

  /// Material icon (used on Android and iOS as fallback).
  final IconData? icon;

  /// Cupertino icon (used on iOS when provided).
  final IconData? cupertinoIcon;

  /// Optional trailing widget (e.g. a badge or count).
  final Widget? trailing;

  /// Whether this item represents the current navigation destination.
  final bool isSelected;

  /// Colour used for the selected state.  Defaults to the platform accent.
  final Color? selectedColor;

  /// Colour used for the unselected state.  Defaults to mid-grey.
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final isIOS    = !kIsWeb && Platform.isIOS;
    final isDark   = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final activeColor = selectedColor ??
        (isIOS
            ? CupertinoTheme.of(context).primaryColor
            : Theme.of(context).colorScheme.primary);

    final inactiveColor = unselectedColor ??
        (isDark ? Colors.white.withValues(alpha: 0.65) : Colors.black54);

    final effectiveIcon = (isIOS && cupertinoIcon != null) ? cupertinoIcon! : icon!;

    return ListTile(
      leading: Icon(
        effectiveIcon,
        color: isSelected ? activeColor : inactiveColor,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? activeColor
              : (isDark ? Colors.white : Colors.black87),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      trailing: trailing,
      selected: isSelected,
      selectedTileColor: isSelected
          ? activeColor.withValues(alpha: isDark ? 0.14 : 0.10)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isIOS ? 10 : 4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      horizontalTitleGap: 10,
      minLeadingWidth: 24,
      onTap: onTap,
    );
  }
}
