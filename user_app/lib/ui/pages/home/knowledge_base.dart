import 'package:flutter/material.dart';
import 'package:user_app/models/app_drawer.dart';
import 'package:user_app/models/unread_menu_button.dart';
import 'package:user_app/ui/pages/home/accident_guide.dart';
import 'package:user_app/ui/pages/home/dashboard_warnings.dart';
import 'package:user_app/ui/pages/home/jumpstart_guide.dart';
import 'package:user_app/ui/pages/home/tyre_maintenance.dart';

class KnowledgeBasePage extends StatelessWidget {
  const KnowledgeBasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      drawer: const AppDrawer(),

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const UnreadMenuButton(),
        title: const Text(
          'Knowledge Base',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LOGO
            Center(
              child: Image.asset(
                'lib/images/Logo.png',
                height: 150,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Resources to help you on the road',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1,
                children: [
                  _KBCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'Dashboard\nWarnings',
                    onTap: () => _push(context, const DashboardWarningsPage()),
                  ),
                  _KBCard(
                    icon: Icons.car_crash,
                    title: 'Car Accident\nGuide',
                    onTap: () => _push(context, const AccidentGuidePage()),
                  ),
                  _KBCard(
                    icon: Icons.tire_repair,
                    title: 'Tyre\nMaintenance',
                    onTap: () => _push(context, const TyreMaintenancePage()),
                  ),
                  _KBCard(
                    icon: Icons.battery_charging_full,
                    title: 'How to\nJumpstart',
                    onTap: () => _push(context, const JumpstartGuidePage()),
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

void _push(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _KBCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _KBCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.yellow.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.yellow, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

