import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFF7A59);
    final textTitleColor = isDark ? Colors.white : const Color(0xFF0F1419);
    final textBodyColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF4B5563);
    final cardBg = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF9FAFB);
    final cardBorder = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About KatsKlub', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textTitleColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // App Brand Container
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                  ),
                  child: SvgPicture.asset(
                    'assets/images/kb.svg',
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'KatsKlub',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: textTitleColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v1.0.12+21',
                  style: TextStyle(
                    fontSize: 13,
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Description Card
              _buildCard(
                cardBg: cardBg,
                cardBorder: cardBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connecting Hearts & Klubs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textTitleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'KatsKlub is a mini-social community hub built for people to discover feeds, post moments, build groups, chat in real-time, play social games, and share custom postcard themes.\n\nOur mission is to provide an aesthetic, lightweight, and engaging social space where everyone can find their own "klub" of friends.',
                      style: TextStyle(
                        fontSize: 14,
                        color: textBodyColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Core Features Card
              _buildCard(
                cardBg: cardBg,
                cardBorder: cardBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Core Features',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textTitleColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureRow(
                      icon: Icons.rss_feed_rounded,
                      title: 'Rich Interactive Feed',
                      subtitle: 'Share posts, hashtags, reels, and customize postcard themes.',
                      iconColor: primaryColor,
                      textColor: textTitleColor,
                      subTextColor: textBodyColor,
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildFeatureRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Real-time Chats',
                      subtitle: 'Direct messaging, groups, and emoji message reactions.',
                      iconColor: Colors.blue,
                      textColor: textTitleColor,
                      subTextColor: textBodyColor,
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildFeatureRow(
                      icon: Icons.gamepad_outlined,
                      title: 'Social Games',
                      subtitle: 'Play Uno, Flappy Kat, Guess the Song, or Connect Four with friends.',
                      iconColor: Colors.purple,
                      textColor: textTitleColor,
                      subTextColor: textBodyColor,
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildFeatureRow(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Wallet & Shop',
                      subtitle: 'Earn points and buy featured postcard templates.',
                      iconColor: Colors.amber,
                      textColor: textTitleColor,
                      subTextColor: textBodyColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dev Info Card
              _buildCard(
                cardBg: cardBg,
                cardBorder: cardBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '© 2026 KatsKlub. All rights reserved.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textBodyColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Built with Flutter & Node.js',
                      style: TextStyle(
                        fontSize: 12,
                        color: textBodyColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required Color cardBg,
    required Color cardBorder,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: child,
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
