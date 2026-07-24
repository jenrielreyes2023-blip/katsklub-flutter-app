import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textTitleColor = isDark ? Colors.white : const Color(0xFF0F1419);
    final textBodyColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF4B5563);
    final primaryColor = const Color(0xFFFF7A59);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textTitleColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textTitleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Last updated: July 22, 2026',
                style: TextStyle(
                  fontSize: 13,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your privacy is important to us. This Privacy Policy describes how KatsKlub collects, uses, shares, and protects your personal information when you use our services.',
                style: TextStyle(
                  fontSize: 14,
                  color: textTitleColor,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                number: '1',
                title: 'Information We Collect',
                body: 'We collect information you provide directly to us when creating an account, setting up your profile, or posting content:\n\n• Account details (e.g. Email address, username, full name, phone number, and password).\n• Profile details (e.g. Avatar picture, location/city, birthday, gender, and bio description).\n• Social content (e.g. Posts, comments, DMs, group DMs, and image uploads).\n• System logs (e.g. IP address, active sessions, and device type).',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              _buildSection(
                number: '2',
                title: 'How We Use Your Information',
                body: 'We use the collected information for various purposes to maintain and improve KatsKlub:\n\n• To authenticate your sessions and process logins.\n• To personalize your feeds, recommend suggested users, and handle postcard themes.\n• To deliver push notifications and real-time socket-based messages (DMs, notifications).\n• To monitor community safety and enforce our Terms of Service.',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              _buildSection(
                number: '3',
                title: 'Information Sharing & Visibility',
                body: 'Your profile settings give you control over who sees your data. Depending on your choice:\n\n• Public Account: Anyone on KatsKlub can see your posts, followers, and profile details.\n• Private Account: Only followers you explicitly approve can view your posts and media feed.\n• Mutes & Blocks: Muting or blocking a user limits their visibility and restricts them from contacting you.',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              _buildSection(
                number: '4',
                title: 'Data Security & Storage',
                body: 'We use secure servers (HTTPS/SSL), salted password hashing, and encrypted cookies to protect your credentials. However, no internet transmission is 100% secure. You are encouraged to activate granular privacy settings and log out of inactive devices.',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              _buildSection(
                number: '5',
                title: 'Your Rights & Data Portability',
                body: 'You have complete control over your data. Under Settings, you can:\n\n• Choose to download your exportable user data.\n• Toggle the visibility of your email, phone, location, and gender on your profile page.\n• Delete your account permanently at any time.',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required String body,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF7A59),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              body,
              style: TextStyle(
                fontSize: 14,
                color: bodyColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
