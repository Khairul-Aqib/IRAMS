import 'package:flutter/material.dart';

/// Five-step protocol the user should follow if they're involved in a road
/// accident. Each step is a numbered ListTile with a brand-yellow badge.
class AccidentGuidePage extends StatelessWidget {
  const AccidentGuidePage({super.key});

  static const _steps = <_Step>[
    _Step(
      title: 'Safety First',
      body: 'Move to a safe area, turn on your hazard lights, and put on '
          'your reflective vest before stepping out of the vehicle.',
    ),
    _Step(
      title: 'Check for Injuries',
      body: 'Call 999 if anyone is hurt. Do not move injured persons '
          'unless absolutely necessary (e.g. fire risk).',
    ),
    _Step(
      title: 'Document Evidence',
      body: 'Take clear photos of all vehicle damage, license plates, '
          'and the road environment. Include skid marks and traffic '
          'signs in your shots.',
    ),
    _Step(
      title: 'Exchange Information',
      body: 'Get Name, IC / Passport, Phone Number, and Insurance '
          'details from every other party involved.',
    ),
    _Step(
      title: 'Report to IRAMS',
      body: "Use the 'Support Chat' or 'Emergency Call' feature in the "
          'app. We can dispatch a tow and guide you through the next steps.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.yellow),
        title: const Text(
          'Accident Guide',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Response Protocol',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'After an accident, adrenaline can make it hard to think '
              'clearly. Follow these steps in order — each is designed '
              'to keep you safe and protect your insurance claim.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            for (var i = 0; i < _steps.length; i++) ...[
              _StepTile(number: i + 1, step: _steps[i]),
              if (i < _steps.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 24),
            // Final reminder banner — emphasizes calling for help.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_hospital, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "When in doubt, call 999 first. Property can be replaced — people can't.",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
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

class _Step {
  final String title;
  final String body;
  const _Step({required this.title, required this.body});
}

class _StepTile extends StatelessWidget {
  final int number;
  final _Step step;
  const _StepTile({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered yellow badge — stands in for ListTile.leading but stays
          // top-aligned regardless of how long the body text wraps.
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.yellow,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.body,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
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
