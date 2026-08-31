import 'package:flutter/material.dart';

import '../../state/localization.dart';
import '../../theme/app_theme.dart';
import '../categories/category_list_screen.dart';
import '../glossary/glossary_screen.dart';
import '../mock_exam/mock_exam_intro_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    CategoryListScreen(),
    MockExamIntroScreen(),
    GlossaryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _index,
        onSelect: (i) => setState(() => _index = i),
        items: [
          _NavItem(
            icon: Icons.category_outlined,
            selectedIcon: Icons.category,
            label: context.ui(tr: 'Kategoriler', de: 'Kategorien'),
          ),
          _NavItem(
            icon: Icons.timer_outlined,
            selectedIcon: Icons.timer,
            label: context.ui(tr: 'Sınav', de: 'Prüfung'),
          ),
          _NavItem(
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book,
            label: context.ui(tr: 'Sözlük', de: 'Wörterbuch'),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: context.ui(tr: 'Ayarlar', de: 'Einstellungen'),
          ),
        ],
      ),
    );
  }
}

/// Data for one tab. A plain class (not a widget) because the label needs a
/// fixed-height, center-aligned, up-to-2-line slot regardless of whether the
/// text is a short single-language word or a long "tr · de" pair — Material's
/// stock [NavigationBar] ellipsizes/clips the long bilingual labels to one
/// line instead, which made tabs look inconsistent with each other.
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem({required this.icon, required this.selectedIcon, required this.label});
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onSelect;

  const _BottomNavBar({required this.selectedIndex, required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE3EFEE))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavTile(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final color = selected ? scheme.primary : onSurface.withValues(alpha: 0.55);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? item.selectedIcon : item.icon, size: 22, color: color),
            const SizedBox(height: 3),
            SizedBox(
              height: 26,
              child: Center(
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.nunitoSans(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 9.5,
                    height: 1.15,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
