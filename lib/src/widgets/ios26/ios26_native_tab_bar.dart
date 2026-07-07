import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../adaptive_scaffold.dart';

/// Native iOS 26 tab bar using UITabBar platform view
class IOS26NativeTabBar extends StatefulWidget {
  const IOS26NativeTabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
    this.tint,
    this.unselectedItemTint,
    this.backgroundColor,
    this.height,
    this.minimizeBehavior = TabBarMinimizeBehavior.automatic,
    this.showNativeView = true,
    this.hidden = false,
  });

  final List<AdaptiveNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color? tint;
  final Color? unselectedItemTint;
  final Color? backgroundColor;
  final double? height;
  final bool showNativeView;

  /// Whether the native tab bar is hidden.
  /// Use this to hide the tab bar when showing modal bottom sheets
  /// to prevent native platform views from bleeding through.
  final bool hidden;

  /// Tab bar minimize behavior (iOS 26+)
  /// Controls how the tab bar minimizes when scrolling
  final TabBarMinimizeBehavior minimizeBehavior;

  @override
  State<IOS26NativeTabBar> createState() => _IOS26NativeTabBarState();
}

class _IOS26NativeTabBarState extends State<IOS26NativeTabBar> {
  MethodChannel? _channel;
  int? _lastIndex;
  int? _lastTint;
  int? _lastUnselectedTint;
  int? _lastBg;
  bool? _lastIsDark;
  bool? _lastIsRtl;
  double? _intrinsicHeight;
  List<String>? _lastLabels;
  List<String>? _lastSymbols;
  List<String>? _lastAssetIcons;
  List<String>? _lastSelectedAssetIcons;
  List<String>? _lastFileIcons;
  List<String>? _lastSelectedFileIcons;
  List<String>? _lastNetworkIcons;
  List<String>? _lastSelectedNetworkIcons;
  List<int?>? _lastBadgeCounts;
  TabBarMinimizeBehavior? _lastMinimizeBehavior;
  bool? _lastHidden;

  // Off-screen rendering for Widget icons
  final List<GlobalKey> _iconProbeKeys = [];
  final List<GlobalKey> _selectedIconProbeKeys = [];
  List<Uint8List?> _renderedIconBytes = [];
  List<Uint8List?> _renderedSelectedIconBytes = [];
  bool _widgetRenderScheduled = false;
  // Incremented each time new bytes are ready; compared against _lastSentBytesVersion
  // so setItems is only sent when bytes actually changed, not on every sync call.
  int _iconBytesVersion = 0;
  int _lastSentBytesVersion = -1;

  bool get _isDark =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;
  Color? get _effectiveTint =>
      widget.tint ?? CupertinoTheme.of(context).primaryColor;

  bool _hasWidgetIcons() => widget.destinations.any(
    (d) => d.icon is Widget || d.selectedIcon is Widget,
  );

  void _initIconProbes() {
    final count = widget.destinations.length;
    _iconProbeKeys.clear();
    _selectedIconProbeKeys.clear();
    _renderedIconBytes = List.filled(count, null);
    _renderedSelectedIconBytes = List.filled(count, null);
    for (int i = 0; i < count; i++) {
      _iconProbeKeys.add(GlobalKey());
      _selectedIconProbeKeys.add(GlobalKey());
    }
  }

  void _scheduleWidgetRender() {
    if (_widgetRenderScheduled) return;
    _widgetRenderScheduled = true;
    // Two frames: first to layout probes, second to paint them
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _renderWidgetIcons();
      });
    });
  }

  Future<void> _renderWidgetIcons() async {
    _widgetRenderScheduled = false;
    bool anyRendered = false;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    for (int i = 0; i < widget.destinations.length; i++) {
      final dest = widget.destinations[i];

      if (dest.icon is Widget) {
        final bytes = await _captureWidget(_iconProbeKeys[i], pixelRatio);
        if (bytes != null && bytes != _renderedIconBytes[i]) {
          _renderedIconBytes[i] = bytes;
          anyRendered = true;
        }
      }

      final selIcon = dest.selectedIcon ?? dest.icon;
      if (selIcon is Widget) {
        final key = dest.selectedIcon is Widget
            ? _selectedIconProbeKeys[i]
            : _iconProbeKeys[i];
        final bytes = await _captureWidget(key, pixelRatio);
        if (bytes != null && bytes != _renderedSelectedIconBytes[i]) {
          _renderedSelectedIconBytes[i] = bytes;
          anyRendered = true;
        }
      }
    }

    if (anyRendered && mounted) {
      _iconBytesVersion++;
      await _syncPropsToNativeIfNeeded();
    }
  }

  Future<Uint8List?> _captureWidget(GlobalKey key, double pixelRatio) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _initIconProbes();
    if (_hasWidgetIcons()) {
      _scheduleWidgetRender();
    }
  }

  @override
  void didUpdateWidget(covariant IOS26NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialise probes when destination count changes
    if (oldWidget.destinations.length != widget.destinations.length) {
      _initIconProbes();
    }
    if (_hasWidgetIcons()) {
      _scheduleWidgetRender();
    }
    _syncPropsToNativeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightnessIfNeeded();
    _syncDirectionalityIfNeeded();
    _syncPropsToNativeIfNeeded();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  int _colorToARGB(Color color) {
    // Resolve CupertinoDynamicColor if needed
    Color resolvedColor = color;
    if (color is CupertinoDynamicColor) {
      // Resolve based on current brightness
      final brightness = MediaQuery.platformBrightnessOf(context);
      resolvedColor = brightness == Brightness.dark
          ? color.darkColor
          : color.color;
    }

    return ((resolvedColor.a * 255.0).round() & 0xff) << 24 |
        ((resolvedColor.r * 255.0).round() & 0xff) << 16 |
        ((resolvedColor.g * 255.0).round() & 0xff) << 8 |
        ((resolvedColor.b * 255.0).round() & 0xff);
  }

  /// Extract SF Symbol name from an icon value.
  /// Returns empty string for non-SF-Symbol icons (asset paths, IconData, widgets).
  String _extractSymbol(Object? icon) {
    if (icon is String && !icon.contains('/')) return icon;
    return '';
  }

  /// Extract asset path from an icon value.
  /// Supports AssetImage, ImageIcon(AssetImage), and string paths containing '/'.
  /// Returns empty string for SF Symbols or other icon types.
  String _extractAssetPath(Object? icon) {
    if (icon is AssetImage) return icon.assetName;
    if (icon is ImageIcon && icon.image is AssetImage) {
      return (icon.image as AssetImage).assetName;
    }
    if (icon is String && icon.contains('/')) return icon;
    return '';
  }

  String _extractFilePath(Object? icon) {
    if (icon is FileImage) return icon.file.path;
    if (icon is ImageIcon && icon.image is FileImage) {
      return (icon.image as FileImage).file.path;
    }
    return '';
  }

  String _extractNetworkUrl(Object? icon) {
    if (icon is NetworkImage) return icon.url;
    if (icon is ImageIcon && icon.image is NetworkImage) {
      return (icon.image as NetworkImage).url;
    }
    return '';
  }

  List<String> _mapSymbols() =>
      widget.destinations.map((e) => _extractSymbol(e.icon)).toList();

  List<String> _mapAssetIcons() =>
      widget.destinations.map((e) => _extractAssetPath(e.icon)).toList();

  List<String> _mapSelectedAssetIcons() => widget.destinations
      .map((e) => _extractAssetPath(e.selectedIcon ?? e.icon))
      .toList();

  List<String> _mapFileIcons() =>
      widget.destinations.map((e) => _extractFilePath(e.icon)).toList();

  List<String> _mapSelectedFileIcons() => widget.destinations
      .map((e) => _extractFilePath(e.selectedIcon ?? e.icon))
      .toList();

  List<String> _mapNetworkIcons() =>
      widget.destinations.map((e) => _extractNetworkUrl(e.icon)).toList();

  List<String> _mapSelectedNetworkIcons() => widget.destinations
      .map((e) => _extractNetworkUrl(e.selectedIcon ?? e.icon))
      .toList();

  /// Returns pre-rendered PNG bytes for Widget icons (index-aligned, null for non-widget icons).
  List<Uint8List?> _mapImageData() => List.generate(
    widget.destinations.length,
    (i) => i < _renderedIconBytes.length ? _renderedIconBytes[i] : null,
  );

  List<Uint8List?> _mapSelectedImageData() => List.generate(
    widget.destinations.length,
    (i) => i < _renderedSelectedIconBytes.length
        ? _renderedSelectedIconBytes[i]
        : null,
  );

  /// Builds zero-size off-screen probe widgets so RepaintBoundary.toImage() works.
  Widget _buildIconProbes() {
    final probes = <Widget>[];
    for (int i = 0; i < widget.destinations.length; i++) {
      final dest = widget.destinations[i];

      if (dest.icon is Widget) {
        probes.add(
          SizedBox(
            width: 0,
            height: 0,
            child: OverflowBox(
              minWidth: 24,
              maxWidth: 24,
              minHeight: 24,
              maxHeight: 24,
              child: RepaintBoundary(
                key: _iconProbeKeys[i],
                child: dest.icon as Widget,
              ),
            ),
          ),
        );
      }

      if (dest.selectedIcon is Widget) {
        probes.add(
          SizedBox(
            width: 0,
            height: 0,
            child: OverflowBox(
              minWidth: 24,
              maxWidth: 24,
              minHeight: 24,
              maxHeight: 24,
              child: RepaintBoundary(
                key: _selectedIconProbeKeys[i],
                child: dest.selectedIcon as Widget,
              ),
            ),
          ),
        );
      }
    }
    if (probes.isEmpty) return const SizedBox.shrink();
    return Stack(children: probes);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      final labels = widget.destinations.map((e) => e.label).toList();
      final symbols = _mapSymbols();
      final assetIcons = _mapAssetIcons();
      final selectedAssetIcons = _mapSelectedAssetIcons();
      final fileIcons = _mapFileIcons();
      final selectedFileIcons = _mapSelectedFileIcons();
      final networkIcons = _mapNetworkIcons();
      final selectedNetworkIcons = _mapSelectedNetworkIcons();

      final searchFlags = widget.destinations.map((e) => e.isSearch).toList();
      final badgeCounts = widget.destinations.map((e) => e.badgeCount).toList();
      final spacerFlags = widget.destinations
          .map((e) => e.addSpacerAfter)
          .toList();

      final imageData = _mapImageData();
      final selectedImageData = _mapSelectedImageData();

      final creationParams = <String, dynamic>{
        'labels': labels,
        'sfSymbols': symbols,
        'assetIcons': assetIcons,
        'selectedAssetIcons': selectedAssetIcons,
        'fileIcons': fileIcons,
        'selectedFileIcons': selectedFileIcons,
        'networkIcons': networkIcons,
        'selectedNetworkIcons': selectedNetworkIcons,
        'imageData': imageData,
        'selectedImageData': selectedImageData,
        'searchFlags': searchFlags,
        'badgeCounts': badgeCounts,
        'spacerFlags': spacerFlags,
        'selectedIndex': widget.selectedIndex,
        'isDark': _isDark,
        'isRtl': _isRtl,
        'minimizeBehavior': widget.minimizeBehavior.index,
        if (_effectiveTint != null) 'tint': _colorToARGB(_effectiveTint!),
        if (widget.unselectedItemTint != null)
          'unselectedItemTint': _colorToARGB(widget.unselectedItemTint!),
        if (widget.backgroundColor != null)
          'backgroundColor': _colorToARGB(widget.backgroundColor!),
      };

      final platformView = widget.showNativeView
          ? UiKitView(
              viewType: 'adaptive_ui/ios26_tab_bar',
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onCreated,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                // EagerGestureRecognizer wins the arena immediately at
                // touch-down, so the full touch sequence (down → up) is
                // forwarded to UIKit in real time. TapGestureRecognizer only
                // wins at touch-up, by which point UITabBar has already missed
                // the touch and never fires tabBar(_:didSelect:).
                Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
              },
            )
          : const SizedBox.shrink();

      final h = widget.height ?? _intrinsicHeight ?? 50.0;
      // When Widget icons are present, add invisible off-screen probes so that
      // RepaintBoundary.toImage() can capture them. Wrap in IgnorePointer so
      // they never intercept taps, and in Opacity(0.005) — intentionally
      // non-zero so Flutter still paints the layer (Opacity(0) skips paint).
      final hasProbes = _hasWidgetIcons();
      if (hasProbes) {
        return SizedBox(
          height: h,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: platformView),
              IgnorePointer(
                child: Opacity(opacity: 0.005, child: _buildIconProbes()),
              ),
            ],
          ),
        );
      }
      return SizedBox(height: h, child: platformView);
    }

    // Fallback for non-iOS
    return SizedBox(
      height: widget.height ?? 50,
      child: Container(
        color:
            widget.backgroundColor ??
            CupertinoColors.systemBackground.resolveFrom(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            widget.destinations.length,
            (index) => CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => widget.onTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.circle,
                    color: index == widget.selectedIndex
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.systemGrey,
                  ),
                  Text(
                    widget.destinations[index].label,
                    style: TextStyle(
                      fontSize: 10,
                      color: index == widget.selectedIndex
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onCreated(int id) {
    final ch = MethodChannel('adaptive_ui/ios26_tab_bar_$id');
    _channel = ch;
    ch.setMethodCallHandler(_onMethodCall);
    _lastIndex = null;
    _lastTint = _effectiveTint != null ? _colorToARGB(_effectiveTint!) : null;
    _lastUnselectedTint = widget.unselectedItemTint != null
        ? _colorToARGB(widget.unselectedItemTint!)
        : null;
    _lastBg = widget.backgroundColor != null
        ? _colorToARGB(widget.backgroundColor!)
        : null;
    _lastIsDark = _isDark;
    _lastIsRtl = _isRtl;
    _lastMinimizeBehavior = widget.minimizeBehavior;
    _requestIntrinsicSize();
    _cacheItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _channel != ch) return;
      _pushInitialStateToNative(ch);
    });
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'valueChanged') {
      final args = call.arguments as Map?;
      final idx = (args?['index'] as num?)?.toInt();
      if (idx != null) {
        widget.onTap(idx);
        _lastIndex = idx;
      }
    }
    return null;
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;

    final idx = widget.selectedIndex;
    final tint = _effectiveTint != null ? _colorToARGB(_effectiveTint!) : null;
    final unselectedTint = widget.unselectedItemTint != null
        ? _colorToARGB(widget.unselectedItemTint!)
        : null;
    final bg = widget.backgroundColor != null
        ? _colorToARGB(widget.backgroundColor!)
        : null;

    if (_lastIndex != idx) {
      await ch.invokeMethod('setSelectedIndex', {'index': idx});
      _lastIndex = idx;
    }

    final style = <String, dynamic>{};
    if (_lastTint != tint && tint != null) {
      style['tint'] = tint;
      _lastTint = tint;
    }
    if (_lastUnselectedTint != unselectedTint && unselectedTint != null) {
      style['unselectedItemTint'] = unselectedTint;
      _lastUnselectedTint = unselectedTint;
    }
    if (_lastBg != bg && bg != null) {
      style['backgroundColor'] = bg;
      _lastBg = bg;
    }
    if (style.isNotEmpty) {
      await ch.invokeMethod('setStyle', style);
    }

    // Items update (for hot reload or dynamic changes)
    final labels = widget.destinations.map((e) => e.label).toList();
    final symbols = _mapSymbols();
    final assetIcons = _mapAssetIcons();
    final selectedAssetIcons = _mapSelectedAssetIcons();
    final fileIcons = _mapFileIcons();
    final selectedFileIcons = _mapSelectedFileIcons();
    final networkIcons = _mapNetworkIcons();
    final selectedNetworkIcons = _mapSelectedNetworkIcons();
    final imageData = _mapImageData();
    final selectedImageData = _mapSelectedImageData();
    final searchFlags = widget.destinations.map((e) => e.isSearch).toList();
    final badgeCounts = widget.destinations.map((e) => e.badgeCount).toList();

    // Only true when _renderWidgetIcons produced NEW bytes (version bumped).
    final imageDataChanged = _iconBytesVersion != _lastSentBytesVersion;

    if (_lastLabels?.join('|') != labels.join('|') ||
        _lastSymbols?.join('|') != symbols.join('|') ||
        _lastAssetIcons?.join('|') != assetIcons.join('|') ||
        _lastSelectedAssetIcons?.join('|') != selectedAssetIcons.join('|') ||
        _lastFileIcons?.join('|') != fileIcons.join('|') ||
        _lastSelectedFileIcons?.join('|') != selectedFileIcons.join('|') ||
        _lastNetworkIcons?.join('|') != networkIcons.join('|') ||
        _lastSelectedNetworkIcons?.join('|') !=
            selectedNetworkIcons.join('|') ||
        imageDataChanged) {
      await ch.invokeMethod('setItems', {
        'labels': labels,
        'sfSymbols': symbols,
        'assetIcons': assetIcons,
        'selectedAssetIcons': selectedAssetIcons,
        'fileIcons': fileIcons,
        'selectedFileIcons': selectedFileIcons,
        'networkIcons': networkIcons,
        'selectedNetworkIcons': selectedNetworkIcons,
        'imageData': imageData,
        'selectedImageData': selectedImageData,
        'searchFlags': searchFlags,
        'badgeCounts': badgeCounts,
        'selectedIndex': widget.selectedIndex,
      });
      _lastLabels = labels;
      _lastSymbols = symbols;
      _lastAssetIcons = assetIcons;
      _lastSelectedAssetIcons = selectedAssetIcons;
      _lastFileIcons = fileIcons;
      _lastSelectedFileIcons = selectedFileIcons;
      _lastNetworkIcons = networkIcons;
      _lastSelectedNetworkIcons = selectedNetworkIcons;
      _lastSentBytesVersion = _iconBytesVersion;
      _requestIntrinsicSize();
    }

    // Badge counts update
    final currentBadgeCounts = widget.destinations
        .map((e) => e.badgeCount)
        .toList();
    if (_lastBadgeCounts?.join('|') != currentBadgeCounts.join('|')) {
      await ch.invokeMethod('setBadgeCounts', {
        'badgeCounts': currentBadgeCounts,
      });
      _lastBadgeCounts = currentBadgeCounts;
    }

    // Minimize behavior update
    if (_lastMinimizeBehavior != widget.minimizeBehavior) {
      await ch.invokeMethod('setMinimizeBehavior', {
        'behavior': widget.minimizeBehavior.index,
      });
      _lastMinimizeBehavior = widget.minimizeBehavior;
    }

    // Hidden state update
    await _syncHiddenIfNeeded();
  }

  Future<void> _syncBrightnessIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      await ch.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
    }
  }

  Future<void> _syncDirectionalityIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    final isRtl = _isRtl;
    if (_lastIsRtl != isRtl) {
      await ch.invokeMethod('setDirectionality', {'isRtl': isRtl});
      _lastIsRtl = isRtl;
    }
  }

  void _cacheItems() {
    _lastLabels = widget.destinations.map((e) => e.label).toList();
    _lastSymbols = _mapSymbols();
    _lastAssetIcons = _mapAssetIcons();
    _lastSelectedAssetIcons = _mapSelectedAssetIcons();
    _lastFileIcons = _mapFileIcons();
    _lastSelectedFileIcons = _mapSelectedFileIcons();
    _lastNetworkIcons = _mapNetworkIcons();
    _lastSelectedNetworkIcons = _mapSelectedNetworkIcons();
    _lastBadgeCounts = widget.destinations.map((e) => e.badgeCount).toList();
  }

  Future<void> _syncHiddenIfNeeded() async {
    final ch = _channel;
    if (ch == null) return;
    final hidden = widget.hidden;
    if (_lastHidden == hidden) return;
    await ch.invokeMethod('setHidden', {'hidden': hidden});
    _lastHidden = hidden;
  }

  Future<void> _requestIntrinsicSize() async {
    if (widget.height != null) return;
    final ch = _channel;
    if (ch == null) return;
    try {
      final size = await ch.invokeMethod<Map>('getIntrinsicSize');
      final h = (size?['height'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        if (h != null && h > 0) _intrinsicHeight = h;
      });
    } catch (_) {}
  }

  Future<void> _pushInitialStateToNative(MethodChannel ch) async {
    final labels = widget.destinations.map((e) => e.label).toList();
    final symbols = _mapSymbols();
    final assetIcons = _mapAssetIcons();
    final selectedAssetIcons = _mapSelectedAssetIcons();
    final fileIcons = _mapFileIcons();
    final selectedFileIcons = _mapSelectedFileIcons();
    final networkIcons = _mapNetworkIcons();
    final selectedNetworkIcons = _mapSelectedNetworkIcons();
    final imageData = _mapImageData();
    final selectedImageData = _mapSelectedImageData();
    final searchFlags = widget.destinations.map((e) => e.isSearch).toList();
    final badgeCounts = widget.destinations.map((e) => e.badgeCount).toList();

    try {
      await ch.invokeMethod('setItems', {
        'labels': labels,
        'sfSymbols': symbols,
        'assetIcons': assetIcons,
        'selectedAssetIcons': selectedAssetIcons,
        'fileIcons': fileIcons,
        'selectedFileIcons': selectedFileIcons,
        'networkIcons': networkIcons,
        'selectedNetworkIcons': selectedNetworkIcons,
        'imageData': imageData,
        'selectedImageData': selectedImageData,
        'searchFlags': searchFlags,
        'badgeCounts': badgeCounts,
        'selectedIndex': widget.selectedIndex,
      });

      final style = <String, dynamic>{};
      if (_effectiveTint != null) {
        style['tint'] = _colorToARGB(_effectiveTint!);
      }
      if (widget.unselectedItemTint != null) {
        style['unselectedItemTint'] = _colorToARGB(widget.unselectedItemTint!);
      }
      if (widget.backgroundColor != null) {
        style['backgroundColor'] = _colorToARGB(widget.backgroundColor!);
      }
      if (style.isNotEmpty) {
        await ch.invokeMethod('setStyle', style);
      }

      await ch.invokeMethod('setSelectedIndex', {
        'index': widget.selectedIndex,
      });
      _lastIndex = widget.selectedIndex;
      await _requestIntrinsicSize();
    } catch (_) {}
  }
}
