// Emergency Drills screen (/tools/emergency-drills) — flash-card drills across Engine Failures, Fires, Emergencies, and Checks tabs.
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/tools/data/emergency_drills_data.dart';

class EmergencyDrillsScreen extends StatefulWidget {
  const EmergencyDrillsScreen({super.key});

  @override
  State<EmergencyDrillsScreen> createState() => _EmergencyDrillsScreenState();
}

class _EmergencyDrillsScreenState extends State<EmergencyDrillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: kEmergencyDrillCategories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Drills'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: TabBar(
              controller: _tabController,
              dividerColor: cs.outline,
              labelColor: AppColors.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.55),
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: kEmergencyDrillCategories
                  .map((c) => Tab(text: c.title))
                  .toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: kEmergencyDrillCategories
            .map((cat) => _DrillTab(category: cat))
            .toList(),
      ),
    );
  }
}

// ── Per-category tab ─────────────────────────────────────────────────────────

class _DrillTab extends StatefulWidget {
  final EmergencyDrillCategory category;

  const _DrillTab({required this.category});

  @override
  State<_DrillTab> createState() => _DrillTabState();
}

class _DrillTabState extends State<_DrillTab> {
  late final List<bool> _revealed;

  @override
  void initState() {
    super.initState();
    _revealed = List.filled(widget.category.cards.length, false);
  }

  void _toggle(int index) {
    setState(() => _revealed[index] = !_revealed[index]);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: widget.category.cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        return _DrillCard(
          card: widget.category.cards[i],
          revealed: _revealed[i],
          onTap: () => _toggle(i),
        );
      },
    );
  }
}

// ── Individual flash card ────────────────────────────────────────────────────

class _DrillCard extends StatelessWidget {
  final EmergencyDrillCard card;
  final bool revealed;
  final VoidCallback onTap;

  const _DrillCard({
    required this.card,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: revealed
              ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.07)
              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: revealed
                ? AppColors.primary.withValues(alpha: 0.35)
                : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
            width: revealed ? 1.2 : 0.75,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.situation,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            if (!revealed) ...[
              const SizedBox(height: 8),
              Text(
                'Tap to reveal',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.35),
                  fontSize: 12,
                ),
              ),
            ] else ...[
              Divider(
                height: 20,
                thickness: 0.5,
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
              Text(
                card.action,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
