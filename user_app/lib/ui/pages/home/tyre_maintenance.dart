import 'package:flutter/material.dart';

/// Three-metric guide on keeping tyres safe and long-lasting. Uses
/// ExpansionTile so each metric can be expanded independently — gives
/// scannable headers without forcing the user to read everything at once.
class TyreMaintenancePage extends StatelessWidget {
  const TyreMaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.yellow),
        title: const Text(
          'Tyre Maintenance',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tyre Safety & Longevity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tyres are the only thing connecting your car to the road. '
              'Three quick checks every month can prevent blowouts, '
              'extend tyre life, and improve fuel economy.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),

            _MetricTile(
              icon: Icons.compress,
              title: 'Pressure',
              cadence: 'Check every 30 days',
              body:
                  'Refer to the sticker on your driver-side door frame for '
                  'the correct PSI for your specific car. Use a digital gauge '
                  'when the tyres are cold (parked > 3 hours). Under-inflated '
                  'tyres wear at the edges and increase fuel consumption; '
                  'over-inflated tyres wear in the middle and reduce grip.',
            ),
            const SizedBox(height: 12),
            _MetricTile(
              icon: Icons.straighten,
              title: 'Tread Depth',
              cadence: 'Check every 30 days',
              body:
                  'Use the "20 sen coin test": place a 20 sen coin into the '
                  'tread groove with the lettering facing you. If the "SEN" '
                  'lettering is visible, your tyres are dangerously worn and '
                  'should be replaced before your next long trip. Worn tread '
                  'massively increases stopping distance in the wet.',
            ),
            const SizedBox(height: 12),
            _MetricTile(
              icon: Icons.search,
              title: 'Visual Inspection',
              cadence: 'Check weekly',
              body:
                  'Walk around the car and look for cracks in the sidewall, '
                  'bulges (a sign of internal damage), or embedded nails / '
                  'screws. Sidewall cracks usually mean the tyre is expired '
                  '(check the DOT date — tyres should be replaced after 6 '
                  'years even if the tread looks fine).',
            ),

            const SizedBox(height: 24),
            // Pro tip card — extra context that doesn't fit a metric tile.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.yellow.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.yellow.withValues(alpha: 0.4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Colors.yellow, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rotate your tyres every 10,000 km to even out wear. '
                      'Front tyres on FWD cars wear ~2× faster than the rear.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String cadence;
  final String body;

  const _MetricTile({
    required this.icon,
    required this.title,
    required this.cadence,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.yellow,
          collapsedIconColor: Colors.yellow,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Icon(icon, color: Colors.yellow, size: 26),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              cadence,
              style: const TextStyle(
                color: Colors.yellow,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          children: [
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
