import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Full-screen block shown to every user while `config/app.maintenanceMode`
/// is `true`. It replaces the whole app UI, so no screen (login included) is
/// reachable until an administrator turns maintenance mode off again.
class MaintenanceScreen extends StatelessWidget {
  final String? title;
  final String? message;

  const MaintenanceScreen({super.key, this.title, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6C3CE1).withAlpha(35),
                  ),
                  child: const Icon(Icons.construction_rounded,
                      color: Color(0xFFB39DDB), size: 48),
                ),
                const SizedBox(height: 28),
                Text(
                  title ?? context.tr('maintenanceTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message ?? context.tr('maintenanceMessage'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  context.tr('maintenanceHint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
