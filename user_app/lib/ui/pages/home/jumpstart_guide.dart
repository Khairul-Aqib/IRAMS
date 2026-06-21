import 'package:flutter/material.dart';

/// Five-step jumpstart sequence. Order is critical — wrong sequence can spark,
/// damage electronics, or trigger a battery fire — so each step is rendered
/// as a numbered tile with a colour-coded cable indicator (red / black).
class JumpstartGuidePage extends StatelessWidget {
  const JumpstartGuidePage({super.key});

  static const _steps = <_JumpStep>[
    _JumpStep(
      cableColor: Color(0xFFE53935),
      title: 'Connect RED (+) to the dead battery',
      body: 'Clamp one end of the red jumper cable onto the positive '
          'terminal (marked +) of the dead battery.',
    ),
    _JumpStep(
      cableColor: Color(0xFFE53935),
      title: 'Connect RED (+) to the donor battery',
      body: 'Clamp the other end of the red cable onto the positive '
          'terminal (+) of the working donor car battery.',
    ),
    _JumpStep(
      cableColor: Colors.black,
      title: 'Connect BLACK (–) to the donor battery',
      body: 'Clamp one end of the black jumper cable onto the negative '
          'terminal (–) of the donor battery.',
    ),
    _JumpStep(
      cableColor: Colors.black,
      title: 'Connect BLACK (–) to ground on the dead car',
      body: 'Clamp the other end onto an unpainted metal surface on the '
          'dead car\'s engine block — NOT the negative battery terminal. '
          'This prevents sparks near the battery.',
    ),
    _JumpStep(
      cableColor: Color(0xFFFFC107),
      title: 'Start, then disconnect in REVERSE order',
      body: 'Start the donor car first, let it idle for 1–2 minutes, then '
          'try the dead car. Once running, disconnect the cables in the '
          'reverse order: black-ground → black-donor → red-donor → red-dead.',
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
          'Jumpstart Guide',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to Jumpstart Safely',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jumpstarting is safe when done in the right order. Follow '
              'these five steps EXACTLY — reversing the sequence can cause '
              'sparks, damage car electronics, or start a battery fire.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),

            // Critical-warning banner — sets the tone before the steps.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.45)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'NEVER let the red and black clamps touch each other '
                      'while either end is connected — it short-circuits the '
                      'donor battery and can throw sparks or molten metal.',
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
            const SizedBox(height: 18),

            const Text(
              'The Sequence',
              style: TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),

            for (var i = 0; i < _steps.length; i++) ...[
              _StepCard(number: i + 1, step: _steps[i]),
              if (i < _steps.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _JumpStep {
  /// Colour of the cable used in this step — red for positive, black for
  /// negative, yellow for the final start/disconnect step (no cable).
  final Color cableColor;
  final String title;
  final String body;
  const _JumpStep({
    required this.cableColor,
    required this.title,
    required this.body,
  });
}

class _StepCard extends StatelessWidget {
  final int number;
  final _JumpStep step;
  const _StepCard({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: step.cableColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered badge tinted with the cable colour so the user can
          // glance at the column of badges and follow the colour pattern.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: step.cableColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: TextStyle(
                color: step.cableColor == Colors.black
                    ? Colors.white
                    : Colors.black,
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
                    fontSize: 14,
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
