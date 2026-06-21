import 'package:flutter/material.dart';

/// Educational guide for dashboard warning lights. Two collapsible sections —
/// red (immediate-stop) and yellow (service-soon) — each opening to a list of
/// the most common indicators with context-aware descriptions.
class DashboardWarningsPage extends StatelessWidget {
  const DashboardWarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.yellow),
        title: const Text(
          'Dashboard Warnings',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Understand Your Car's Language",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dashboard lights tell you what your car needs. Knowing the '
              'difference between a warning and a critical alert can save '
              'your engine — and your life.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),

            _WarningSection(
              accent: Color(0xFFE53935),
              headerIcon: Icons.dangerous_outlined,
              title: 'RED — Danger',
              callout:
                  'STOP SAFELY IMMEDIATELY. Continuing to drive can cause '
                  'terminal engine damage.',
              entries: [
                _WarningEntry(
                  icon: Icons.error_outline,
                  label: 'Brake System',
                  desc: 'A failure in the braking system. Pull over to '
                      'reduce the risk of a crash.',
                ),
                _WarningEntry(
                  icon: Icons.thermostat,
                  label: 'Engine Overheating',
                  desc: 'Coolant is overheating. Driving further can warp '
                      'the cylinder head.',
                ),
                _WarningEntry(
                  icon: Icons.oil_barrel,
                  label: 'Low Oil Pressure',
                  desc: 'Engine has lost oil pressure. Continuing risks '
                      'complete engine seizure.',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _WarningSection(
              accent: Color(0xFFFFC107),
              headerIcon: Icons.warning_amber_rounded,
              title: 'YELLOW — Caution',
              callout:
                  'Service required soon. The car is operable but needs '
                  'inspection.',
              entries: [
                _WarningEntry(
                  icon: Icons.car_repair,
                  label: 'Check Engine',
                  desc: 'Emissions or performance issue detected. Get a '
                      'diagnostic scan.',
                ),
                _WarningEntry(
                  icon: Icons.tire_repair,
                  label: 'TPMS (Tyre Pressure)',
                  desc: 'One or more tyres are below recommended PSI. '
                      'Check and refill.',
                ),
                _WarningEntry(
                  icon: Icons.battery_alert,
                  label: 'Battery / Charging',
                  desc: 'Battery is not charging properly. Have the '
                      'alternator and battery checked.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningSection extends StatelessWidget {
  final Color accent;
  final IconData headerIcon;
  final String title;
  final String callout;
  final List<_WarningEntry> entries;

  const _WarningSection({
    required this.accent,
    required this.headerIcon,
    required this.title,
    required this.callout,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Theme(
        // Strip the default Material divider lines so the card border carries
        // the entire visual outline.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: accent,
          collapsedIconColor: accent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Icon(headerIcon, color: accent, size: 28),
          title: Text(
            title,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.4,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                callout,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final e in entries) e,
          ],
        ),
      ),
    );
  }
}

class _WarningEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;

  const _WarningEntry({
    required this.icon,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white70, size: 28),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          desc,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
