import 'package:flutter/material.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _faqs = [
    {
      'category': 'Account & Security',
      'icon': Icons.security_rounded,
      'color': Colors.blue,
      'items': [
        {
          'question': 'How do I activate Two-Factor Authentication (2FA)?',
          'answer': 'Go to Settings > Profile Privacy > 2FA/Passkey (Coming Soon) to link an authenticator app like Google Authenticator or Microsoft Authenticator.'
        },
        {
          'question': 'How do I delete my KatsKlub account?',
          'answer': 'Navigate to Settings, scroll down to the "Danger Zone" section, and tap "Delete account". Note that there is a 14-day grace period where you can cancel the deletion by logging back in.'
        },
        {
          'question': 'How can I change my password?',
          'answer': 'Go to Settings > Change Password, enter your current password, type your new password twice, and tap "Save password".'
        }
      ]
    },
    {
      'category': 'Direct Messages & Socials',
      'icon': Icons.chat_bubble_outline_rounded,
      'color': Colors.green,
      'items': [
        {
          'question': 'How do I block or mute someone?',
          'answer': 'Visit the profile of the user you want to block or mute, tap the three dots icon in the top right, and select "Block User" or "Mute User". Blocked users cannot see your posts or DM you.'
        },
        {
          'question': 'How do I create a group DM chat?',
          'answer': 'Go to DMs tab, click the write/compose icon in the top right, tap "Create Group", select the members you want to add, and click "Next".'
        },
        {
          'question': 'Can I hide my followers/following lists?',
          'answer': 'Yes. Go to Settings > Profile Privacy, and toggle off "Show followers count" and "Show following count" to hide them from other users.'
        }
      ]
    },
    {
      'category': 'Wallet & Shop',
      'icon': Icons.wallet_rounded,
      'color': Colors.amber,
      'items': [
        {
          'question': 'What are Charm Points?',
          'answer': 'Charm Points are rewards earned by interacting, receiving likes, and playing games on KatsKlub. You can use Charm Points to unlock new postcard themes in the Shop.'
        },
        {
          'question': 'How do I buy a postcard theme?',
          'answer': 'Open the Shop tab, select a postcard theme you like (such as Sunrise, Ocean, or Cozy Christmas), and click buy. Once purchased, you can apply it from your Edit Profile screen.'
        }
      ]
    },
    {
      'category': 'Safety & Moderation',
      'icon': Icons.shield_outlined,
      'color': Colors.red,
      'items': [
        {
          'question': 'How do I report sensitive or harmful content?',
          'answer': 'If you see an offensive post or comment, tap the three dots menu next to it and click "Report". Select the reason (spam, harassment, sensitive material) and submit. Reported content will be reviewed by admin moderators.'
        },
        {
          'question': 'Can I set my account to private?',
          'answer': 'Yes. Go to Settings > Account Privacy, and toggle on the "Private Account" switch. Only users you approve as followers will be able to view your posts and media.'
        }
      ]
    }
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredFaqs() {
    if (_searchQuery.isEmpty) return _faqs;

    final query = _searchQuery.toLowerCase();
    List<Map<String, dynamic>> filtered = [];

    for (final cat in _faqs) {
      List<Map<String, String>> matchingItems = [];
      for (final item in cat['items']) {
        final q = item['question']!.toLowerCase();
        final a = item['answer']!.toLowerCase();
        if (q.contains(query) || a.contains(query)) {
          matchingItems.add(item);
        }
      }
      if (matchingItems.isNotEmpty) {
        filtered.add({
          'category': cat['category'],
          'icon': cat['icon'],
          'color': cat['color'],
          'items': matchingItems,
        });
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFF7A59);
    final textTitleColor = isDark ? Colors.white : const Color(0xFF0F1419);
    final textBodyColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF4B5563);
    final inputBg = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF3F4F7);
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0x1F787878);

    final filteredFaqs = _getFilteredFaqs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textTitleColor,
      ),
      body: Column(
        children: [
          // Search Header Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: textTitleColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                hintText: 'Search for articles, guides, keywords...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
            ),
          ),

          Expanded(
            child: filteredFaqs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          size: 64,
                          color: textBodyColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No articles found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textTitleColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try searching for different keywords',
                          style: TextStyle(fontSize: 14, color: textBodyColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: filteredFaqs.length,
                    itemBuilder: (context, index) {
                      final category = filteredFaqs[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 18, bottom: 8, left: 4),
                            child: Row(
                              children: [
                                Icon(
                                  category['icon'] as IconData,
                                  size: 18,
                                  color: category['color'] as Color,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category['category'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textTitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...category['items'].map<Widget>((faq) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: ExpansionTile(
                                  title: Text(
                                    faq['question'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textTitleColor,
                                    ),
                                  ),
                                  iconColor: primaryColor,
                                  collapsedIconColor: textBodyColor,
                                  childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
                                  expandedAlignment: Alignment.topLeft,
                                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                  shape: const Border(),
                                  children: [
                                    Text(
                                      faq['answer'] as String,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: textBodyColor,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
          ),

          // Contact Support Bottom Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF9FAFB),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Still need help?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textTitleColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Get in touch with support team',
                        style: TextStyle(
                          fontSize: 13,
                          color: textBodyColor,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Support request sent! We will contact you soon.'),
                        backgroundColor: primaryColor,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text(
                    'Contact Us',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
