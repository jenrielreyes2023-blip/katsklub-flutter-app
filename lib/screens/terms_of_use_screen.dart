import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textTitleColor = isDark ? Colors.white : const Color(0xFF0F1419);
    final textBodyColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF4B5563);
    final primaryColor = const Color(0xFFFF7A59);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Use', style: TextStyle(fontWeight: FontWeight.bold)),
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
                'Terms of Service',
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
                'Please read these Terms of Use carefully before using the KatsKlub app. By accessing or using KatsKlub, you agree to be bound by these terms.',
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
                title: 'Acceptance of Terms',
                body: 'By downloading, installing, or using KatsKlub, you agree that you have read, understood, and accept these Terms of Service. If you do not agree to these terms, please delete the application and discontinue any use of our platform.',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              _buildSection(
                number: '2',
                title: 'User Conduct & Safety Rules',
                body: 'KatsKlub is a community for friendly, positive interactions. You agree NOT to post, transmit, or share content that is:\n\n• Offensive, harassing, abusive, or promoting hate speech.\n• Infringing on intellectual property or third-party copyrights.\n• Spam, advertisement, or unauthorized promotions.\n• Containing viruses, malicious scripts, or attempt to hack user accounts.',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              _buildSection(
                number: '3',
                title: 'User Accounts & Verification',
                body: 'You are responsible for maintaining the confidentiality of your account credentials and password. KatsKlub allows phone login via SMS verification codes (OTP). You must keep your registered phone number up to date to access your account.',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              _buildSection(
                number: '4',
                title: 'Wallet, Charm Points & Shop',
                body: 'Charm Points and Wallet balances are virtual tokens within KatsKlub. They are used for purchase of featured postcard themes, custom borders, and other digital items. Charm Points cannot be redeemed for real money, legal tender, or physical goods.',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              _buildSection(
                number: '5',
                title: 'Moderation, Mutes & Blocks',
                body: 'To protect the community, KatsKlub supports blocking and muting features. The platform administrators reserve the right to review reported posts, comments, or profiles, and suspend accounts that violate the code of conduct.',
                titleColor: textTitleColor,
                bodyColor: textBodyColor,
              ),
              _buildSection(
                number: '6',
                title: 'Limitation of Liability',
                body: 'KatsKlub is provided on an "as-is" and "as-available" basis. We do not guarantee uninterrupted, secure, or error-free operations of our database or servers.',
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
