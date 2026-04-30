// Memory Drills screen (/tools/memory-drills) — flash-card drills across Speeds, Mnemonics, and Circuit tabs; Speeds deck is aircraft-specific from the user's profile.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/tools/data/memory_drills_data.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

class MemoryDrillsScreen extends ConsumerStatefulWidget {
  const MemoryDrillsScreen({super.key});

  @override
  ConsumerState<MemoryDrillsScreen> createState() => _MemoryDrillsScreenState();
}

class _MemoryDrillsScreenState extends ConsumerState<MemoryDrillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Session-only aircraft override for the Speeds tab.
  /// Null means "follow profile aircraftType". Not persisted to Firestore.
  String? _aircraftOverride;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    final user = ref.watch(appUserProvider).valueOrNull;
    final selectedType = _aircraftOverride ?? user?.aircraftType;

    final speedData = kAircraftSpeedData.firstWhere(
      (a) => a.aircraftType == selectedType,
      orElse: () => kAircraftSpeedData.first,
    );

    final mnemonicsCategory = kMemoryDrillCategories[0];
    final circuitCategory = kMemoryDrillCategories[1];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Drills'),
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
              tabs: const [
                Tab(text: 'Speeds'),
                Tab(text: 'Mnemonics'),
                Tab(text: 'Circuit'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SpeedsTab(
            speedData: speedData,
            onAircraftChanged: (type) =>
                setState(() => _aircraftOverride = type),
          ),
          _DrillTab(category: mnemonicsCategory),
          _DrillTab(category: circuitCategory),
        ],
      ),
    );
  }
}

// ── Speeds tab — aircraft-specific with aircraft name subtitle ────────────────

class _SpeedsTab extends StatefulWidget {
  final AircraftSpeedData speedData;
  final ValueChanged<String> onAircraftChanged;

  const _SpeedsTab({
    required this.speedData,
    required this.onAircraftChanged,
  });

  @override
  State<_SpeedsTab> createState() => _SpeedsTabState();
}

class _SpeedsTabState extends State<_SpeedsTab> {
  late List<bool> _revealed;

  @override
  void initState() {
    super.initState();
    _revealed = List.filled(widget.speedData.speeds.length, false);
  }

  @override
  void didUpdateWidget(_SpeedsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speedData.aircraftType != widget.speedData.aircraftType) {
      _revealed = List.filled(widget.speedData.speeds.length, false);
    }
  }

  void _toggle(int index) {
    setState(() => _revealed[index] = !_revealed[index]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: widget.speedData.speeds.length + 1,
      separatorBuilder: (_, i) => i == 0
          ? const SizedBox(height: 12)
          : const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: widget.speedData.aircraftType,
                isExpanded: true,
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  size: 20,
                ),
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                dropdownColor:
                    isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                items: kAircraftSpeedData
                    .map(
                      (a) => DropdownMenuItem<String>(
                        value: a.aircraftType,
                        child: Text(a.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (type) {
                  if (type != null) widget.onAircraftChanged(type);
                },
              ),
            ),
          );
        }
        final cardIndex = i - 1;
        return _DrillCard(
          card: widget.speedData.speeds[cardIndex],
          revealed: _revealed[cardIndex],
          onTap: () => _toggle(cardIndex),
        );
      },
    );
  }
}

// ── Per-category tab (Mnemonics / Circuit) ────────────────────────────────────

class _DrillTab extends StatefulWidget {
  final MemoryDrillCategory category;

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
  final MemoryDrillCard card;
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
              card.front,
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
                card.back,
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
