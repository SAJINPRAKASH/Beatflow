import 'package:flutter/material.dart';
import '../../core/theme/neumorphic_theme.dart';

class FrameWrapper extends StatelessWidget {
  final Widget child;

  const FrameWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width > 600;

    if (!isDesktop) {
      return child;
    }

    // Wrap the app in a gorgeous mobile phone frame for desktop/web viewing
    return Scaffold(
      backgroundColor: const Color(0xFF1E222B), // Dark background for the desk canvas
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 24),
          width: 412, // Standard mobile aspect width
          height: 892, // Standard mobile aspect height
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(48),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF333A47),
              width: 12, // Phone border/bezel
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Column(
              children: [
                // Simulated Status Bar (Matching reference mockup style)
                Container(
                  height: 36,
                  color: AppTheme.background,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '8:00',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      // Status Bar Icons: Network, Wifi, Battery
                      Row(
                        children: [
                          Icon(Icons.signal_cellular_4_bar, size: 14, color: AppTheme.textPrimary),
                          const SizedBox(width: 4),
                          Icon(Icons.wifi, size: 14, color: AppTheme.textPrimary),
                          const SizedBox(width: 4),
                          Transform.rotate(
                            angle: 1.5708 * 3, // 270 degrees
                            child: Icon(Icons.battery_5_bar, size: 16, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actual Screen Content
                Expanded(
                  child: child,
                ),
                // Simulated Home Indicator Bar (iOS style)
                Container(
                  height: 16,
                  color: AppTheme.background,
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
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
