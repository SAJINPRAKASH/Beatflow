import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/neumorphic_theme.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Back Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: NeumorphicBox(
                        shape: BoxShape.circle,
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.arrow_back, size: 22, color: AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Credits & Contributors',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Developer Section
              _buildSectionTitle('Lead Developer'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NeumorphicBox(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      NeumorphicBox(
                        shape: BoxShape.circle,
                        padding: const EdgeInsets.all(14),
                        child: Icon(Icons.person, color: AppTheme.textPrimary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sajin',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Architecture, Core UI, & Platform Integrations',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final Uri url = Uri.parse('https://www.instagram.com/___saji__n_?igsh=MXNld2RqYmVsamp0cg%3D%3D&utm_source=qr');
                          try {
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              await launchUrl(url, mode: LaunchMode.platformDefault);
                            }
                          } catch (e) {
                            debugPrint('Could not launch $url: $e');
                          }
                        },
                        child: NeumorphicBox(
                          shape: BoxShape.circle,
                          padding: const EdgeInsets.all(10),
                          child: FaIcon(
                            FontAwesomeIcons.instagram,
                            color: AppTheme.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Contributors Section
              _buildSectionTitle('Main Contributors'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NeumorphicBox(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildContributorRow(
                        name: 'Google DeepMind Team',
                        role: 'Advanced Agentic Coding Pair Programmers',
                        icon: Icons.psychology_outlined,
                      ),
                      Divider(color: AppTheme.shadowDark, height: 24),
                      _buildContributorRow(
                        name: 'Flutter & Dart Community',
                        role: 'Outstanding Framework & Libraries',
                        icon: Icons.code,
                      ),
                      Divider(color: AppTheme.shadowDark, height: 24),
                      _buildContributorRow(
                        name: 'Ryan Heise & just_audio team',
                        role: 'Robust Audio Service & Sessions',
                        icon: Icons.music_note_outlined,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Open Source Licenses info
              _buildSectionTitle('Open Source Libraries'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NeumorphicBox(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'This application relies on beautiful open source projects including riverpod, go_router, just_audio, audio_service, hive, dio, and youtube_explode_dart. We thank all maintainers for their hard work in making this possible.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildContributorRow({
    required String name,
    required String role,
    required IconData icon,
  }) {
    return Row(
      children: [
        NeumorphicBox(
          shape: BoxShape.circle,
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppTheme.textPrimary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                role,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
