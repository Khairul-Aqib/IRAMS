import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/models/unread_menu_button.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      drawer: const AppDrawer(),

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const UnreadMenuButton(iconColor: Colors.yellow),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            Image.asset(
                'lib/images/Logo.png',
                height: 150,
            ),

            const SizedBox(height: 20),

            const Text(
              'IRAMS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Car breakdowns can happen anytime.\nWe’re here to help — fast, reliable, and simple.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 30),

            _infoRow(Icons.flash_on, 'Quick roadside assistance'),
            _infoRow(Icons.verified, 'Trusted service providers'),
            _infoRow(Icons.support_agent, '24/7 support availability'),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final uri = Uri.parse('https://carput.com.my');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text(
                  'VISIT OUR WEBSITE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.yellow, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
