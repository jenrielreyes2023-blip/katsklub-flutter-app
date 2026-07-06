import 'package:flutter/material.dart';

class SensitiveContentWrapper extends StatefulWidget {
  final Widget child;
  final bool isSensitive;

  const SensitiveContentWrapper({
    super.key,
    required this.child,
    required this.isSensitive,
  });

  @override
  State<SensitiveContentWrapper> createState() => _SensitiveContentWrapperState();
}

class _SensitiveContentWrapperState extends State<SensitiveContentWrapper> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isSensitive || _isRevealed) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainState: true,
          maintainAnimation: true,
          child: IgnorePointer(child: widget.child),
        ),
        Positioned.fill(
          child: _buildPlaceholder(),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sensitive Content',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This media may contain sensitive or explicit content.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  setState(() {
                    _isRevealed = true;
                  });
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.visibility_rounded,
                        color: Colors.black,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Show Content',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
