import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_ui/adaptive_ui.dart';

class DrawerDemoPage extends StatefulWidget {
  const DrawerDemoPage({super.key});

  @override
  State<DrawerDemoPage> createState() => _DrawerDemoPageState();
}

class _DrawerDemoPageState extends State<DrawerDemoPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _currentPage = 'Home';

  static const _pages = ['Home', 'Profile', 'Notifications', 'Settings', 'About'];

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: AdaptiveAppBar(title: 'Drawer Demo'),
      drawer: AdaptiveDrawer(
        child: Column(
          children: [
            AdaptiveDrawerHeader(
              title: 'Adaptive UI',
              subtitle: 'Platform-native drawer',
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PlatformInfo.isIOS
                      ? CupertinoIcons.sparkles
                      : Icons.auto_awesome,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildItem(
                    context,
                    icon: PlatformInfo.isIOS ? CupertinoIcons.house_fill : Icons.home,
                    label: 'Home',
                  ),
                  _buildItem(
                    context,
                    icon: PlatformInfo.isIOS ? CupertinoIcons.person_fill : Icons.person,
                    label: 'Profile',
                  ),
                  _buildItem(
                    context,
                    icon: PlatformInfo.isIOS ? CupertinoIcons.bell_fill : Icons.notifications,
                    label: 'Notifications',
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildItem(
                    context,
                    icon: PlatformInfo.isIOS ? CupertinoIcons.settings : Icons.settings,
                    label: 'Settings',
                  ),
                  _buildItem(
                    context,
                    icon: PlatformInfo.isIOS ? CupertinoIcons.info_circle : Icons.info_outline,
                    label: 'About',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PlatformInfo.isIOS ? CupertinoIcons.sidebar_left : Icons.menu,
                  size: 64,
                  color: PlatformInfo.isIOS
                      ? CupertinoColors.systemBlue
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Adaptive Drawer',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current page: $_currentPage',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'iOS 26+: Liquid Glass glassy panel\n'
                  'iOS <26: Cupertino-styled drawer\n'
                  'Android: Material 3 drawer',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                AdaptiveButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  label: 'Open Drawer',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isSelected = _currentPage == label;
    final isIOS = PlatformInfo.isIOS;

    final activeColor = isIOS
        ? CupertinoColors.systemBlue
        : Theme.of(context).colorScheme.primary;
    final inactiveColor = isDark ? Colors.white70 : Colors.black54;

    return ListTile(
      leading: Icon(icon, color: isSelected ? activeColor : inactiveColor),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? activeColor : (isDark ? Colors.white : Colors.black87),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: PlatformInfo.isIOS26OrHigher()
          ? Colors.white.withValues(alpha: 0.13)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isIOS ? 10 : 0),
      ),
      horizontalTitleGap: 8,
      onTap: () {
        setState(() => _currentPage = label);
        Navigator.pop(context);
      },
    );
  }
}
