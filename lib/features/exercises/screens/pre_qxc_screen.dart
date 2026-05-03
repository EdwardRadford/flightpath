import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';

class PreQxcScreen extends StatelessWidget {
  const PreQxcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pre-QXC')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader('What the QXC actually checks'),
          const SizedBox(height: 12),
          Text(
            'CAA requirements: 150 nm minimum, two intermediate landings at different aerodromes (not your base). You plan and execute the full route independently.',
            style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 28),
          _SectionHeader('Route planning checklist'),
          const SizedBox(height: 12),
          _checkItem(cs, 'NOTAMs for all aerodromes and en-route airspace'),
          _checkItem(cs, 'Weather: TAF and METAR for departure, destinations, and alternates'),
          _checkItem(cs, 'Fuel: plan for reserve plus 15 minutes — fuel log updated every leg'),
          _checkItem(cs, 'Alternates: identify at least one per destination'),
          _checkItem(cs, 'Mass and balance: calculated before departure, within limits for all fuel states'),
          _checkItem(cs, 'Radio frequencies: filed in order, standby frequency ready'),
          _checkItem(cs, 'Charts: WAC and 1:500,000 folded and oriented for the first leg'),
          _checkItem(cs, 'PLOG: headings, distances, times, fuel planned'),
          const SizedBox(height: 28),
          _SectionHeader('Common mistakes'),
          const SizedBox(height: 12),
          _bulletItem(cs, 'Flying over instead of tracking — use a heading log, not just the map.'),
          _bulletItem(cs, 'Late ATZ calls — radio the destination 5–10 nm out, not overhead.'),
          _bulletItem(cs, 'Running behind — if one fix is late, update the plan; don\'t chase the time.'),
          _bulletItem(cs, 'Fuel log neglected — update it at every leg waypoint.'),
          _bulletItem(cs, 'Rushed landing brief — brief each circuit on the ground before joining.'),
          const SizedBox(height: 28),
          _SectionHeader('The day before'),
          const SizedBox(height: 12),
          Text(
            'File PLOG. Confirm weather. Charge devices. Confirm landing fees and PPR if required at destination aerodromes.',
            style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _SectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  Widget _checkItem(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_box_outline_blank_rounded, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _bulletItem(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
