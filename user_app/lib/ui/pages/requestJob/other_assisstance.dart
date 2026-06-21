import 'package:flutter/material.dart';
import 'package:user_app/constants/colors.dart';
import 'package:user_app/ui/pages/messages/support_chat_page.dart';

class OtherAssistancePage extends StatelessWidget {
  const OtherAssistancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Assistance Details',
          style: TextStyle(color: Colors.white),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          children: [
            // ICON
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.yellow.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.build, color: Colors.yellow, size: 36),
            ),

            const SizedBox(height: 20),

            // TITLE
            const Text(
              'OTHER ASSISTANCE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 10),

            // DESCRIPTION
            const Text(
              'Facing an issue that doesn’t fall into the listed categories?\nLet us know and we’ll assist you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 28),

            // INFO CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What you can request',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Engine issues\n'
                    '• Warning lights\n'
                    '• Unknown mechanical problems\n'
                    '• Anything not listed earlier',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // LOGO
            Image.asset(
              'lib/images/Logo_2.png',
              height: 200,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 14),

            // CONTINUE BUTTONr
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportChatPage(),
                    ),
                  );
                },
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
