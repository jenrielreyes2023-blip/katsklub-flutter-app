import 'package:flutter/material.dart';

class KatsTopBar extends StatelessWidget {
  const KatsTopBar({
    required this.unreadNotifications,
    super.key,
  });

  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Image.asset(
            'assets/images/kats-logo-final.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 14),
                  Icon(Icons.search, color: Color(0xFF6B7280), size: 21),
                  SizedBox(width: 8),
                  Text(
                    'Search',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F2F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none, size: 24),
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadNotifications > 99
                          ? '99+'
                          : unreadNotifications.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
