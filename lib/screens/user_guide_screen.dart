import 'package:flutter/material.dart';
import '../utils/key_event_handler.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return KeyEventHandler(
      onBackKey: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'About & Disclaimer',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    context,
                    icon: Icons.school_rounded,
                    title: 'Educational Purpose',
                    content: 'This application is developed strictly for educational purposes to demonstrate the capabilities of Flutter and modern application development. It is intended for learning and experimentation with web scraping and media playback technologies.',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 32),
                  _buildSection(
                    context,
                    icon: Icons.cloud_off_rounded,
                    title: 'No Content Hosted',
                    content: 'ScreenScape does not host, upload, or store any video files, media content, or copyrighted material on its servers. The application acts solely as a client-side interface that scrapes publicly available information from third-party websites.',
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 32),
                  _buildSection(
                    context,
                    icon: Icons.link_rounded,
                    title: 'Third-Party Links',
                    content: 'All content accessible through this application is provided by external third-party services. We do not have control over, and assume no responsibility for, the content, privacy policies, or practices of any third-party websites or services.',
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(height: 32),
                  _buildSection(
                    context,
                    icon: Icons.security_rounded,
                    title: 'Usage Responsibility',
                    content: 'Users are responsible for complying with local laws and regulations regarding content access and copyright. The developers regarding of this application accept no liability for any misuse of the application or violations of applicable laws.',
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(height: 48),
                   Center(
                    child: Text(
                      'ScreenScape TV v1.0.0 Beta',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
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
