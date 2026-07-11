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
  AdaptiveDrawerStyle _drawerStyle = AdaptiveDrawerStyle.glass;

  static const _styleLabels = {
    AdaptiveDrawerStyle.glass: 'Glass',
    AdaptiveDrawerStyle.frosted: 'Frosted',
    AdaptiveDrawerStyle.tinted: 'Tinted',
    AdaptiveDrawerStyle.filled: 'Filled',
  };

  Color? get _tintForStyle {
    if (_drawerStyle == AdaptiveDrawerStyle.tinted) {
      return PlatformInfo.isIOS
          ? CupertinoColors.systemBlue
          : Colors.deepPurple;
    }
    if (_drawerStyle == AdaptiveDrawerStyle.filled) {
      final isDark =
          MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      return isDark ? const Color(0xFF1C1C1E) : Colors.white;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: AdaptiveAppBar(title: 'Drawer Demo'),
      drawer: AdaptiveDrawer(
        style: _drawerStyle,
        backgroundColor: _tintForStyle,
        child: Column(
          children: [
            AdaptiveDrawerHeader(
              title: 'Adaptive UI',
              subtitle: '${_styleLabels[_drawerStyle]!} style',
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
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
                  AdaptiveDrawerItem(
                    icon: Icons.home,
                    cupertinoIcon: CupertinoIcons.house_fill,
                    label: 'Home',
                    isSelected: _currentPage == 'Home',
                    onTap: () => _navigate('Home'),
                  ),
                  AdaptiveDrawerItem(
                    icon: Icons.person,
                    cupertinoIcon: CupertinoIcons.person_fill,
                    label: 'Profile',
                    isSelected: _currentPage == 'Profile',
                    onTap: () => _navigate('Profile'),
                  ),
                  AdaptiveDrawerItem(
                    icon: Icons.notifications,
                    cupertinoIcon: CupertinoIcons.bell_fill,
                    label: 'Notifications',
                    isSelected: _currentPage == 'Notifications',
                    trailing: _Badge(count: 3),
                    onTap: () => _navigate('Notifications'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  AdaptiveDrawerItem(
                    icon: Icons.settings,
                    cupertinoIcon: CupertinoIcons.settings,
                    label: 'Settings',
                    isSelected: _currentPage == 'Settings',
                    onTap: () => _navigate('Settings'),
                  ),
                  AdaptiveDrawerItem(
                    icon: Icons.info_outline,
                    cupertinoIcon: CupertinoIcons.info_circle,
                    label: 'About',
                    isSelected: _currentPage == 'About',
                    onTap: () => _navigate('About'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Style picker
              const Text(
                'Drawer Style',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AdaptiveDrawerStyle.values.map((s) {
                  final selected = s == _drawerStyle;
                  return GestureDetector(
                    onTap: () => setState(() => _drawerStyle = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? (PlatformInfo.isIOS
                                  ? CupertinoColors.systemBlue
                                  : Theme.of(context).colorScheme.primary)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? Colors.transparent
                              : Colors.grey.shade400,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _styleLabels[s]!,
                        style: TextStyle(
                          color: selected ? Colors.white : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Open button
              Center(
                child: AdaptiveButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  label: 'Open Drawer',
                ),
              ),

              const SizedBox(height: 32),

              // Info cards
              _InfoCard(
                title: 'Current page',
                value: _currentPage,
                icon: Icons.navigation,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'iOS 26+ appearance',
                value:
                    'Native UIVisualEffectView\n'
                    '+ entrance animation\n'
                    '+ Liquid Glass glint sweep',
                icon: Icons.blur_on,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(String page) {
    setState(() => _currentPage = page);
    Navigator.pop(context);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
