import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

/// A dedicated screen to test and preview virtual gift animations.
class GiftTesterScreen extends StatefulWidget {
  const GiftTesterScreen({super.key});

  @override
  State<GiftTesterScreen> createState() => _GiftTesterScreenState();
}

class _GiftTesterScreenState extends State<GiftTesterScreen>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _svgaController;
  bool _isPlayingGift = false;
  String? _activeGiftName;

  final List<Map<String, String>> _availableGifts = [
    {
      'name': 'Rocket Gift',
      'icon': 'assets/gifts/rocket_icon.png',
      'svga': 'assets/svga/rocket_gift.svga',
      'desc': 'Interactive flying rocket animation',
    },
    {
      'name': 'Fireworks Oath',
      'icon': 'assets/gifts/fireworks_icon.png',
      'svga': 'assets/svga/fireworks_gift.svga',
      'desc': 'Grand fireworks animation effect',
    },
  ];

  @override
  void initState() {
    super.initState();
    _svgaController = SVGAAnimationController(vsync: this);
  }

  Future<void> _playGiftAnimation(String svgaPath, String giftName) async {
    try {
      setState(() {
        _isPlayingGift = true;
        _activeGiftName = giftName;
      });

      final videoItem = await SVGAParser.shared.decodeFromAssets(svgaPath);
      if (mounted) {
        setState(() {
          _svgaController?.videoItem = videoItem;
          _svgaController?.reset();
          _svgaController?.forward().then((_) {
            if (mounted) {
              setState(() {
                _isPlayingGift = false;
                _activeGiftName = null;
              });
            }
          });
        });
      }
    } catch (e) {
      debugPrint('Error playing gift animation $svgaPath: $e');
      if (mounted) {
        setState(() {
          _isPlayingGift = false;
          _activeGiftName = null;
        });
      }
    }
  }

  void _stopGiftAnimation() {
    _svgaController?.stop();
    setState(() {
      _isPlayingGift = false;
      _activeGiftName = null;
    });
  }

  @override
  void dispose() {
    _svgaController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark live-room aesthetic
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          '🎁 Virtual Gift Animation Tester',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // 1. Main Controls UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a Gift to Trigger Animation:',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gift Cards List
                  Expanded(
                    child: ListView.separated(
                      itemCount: _availableGifts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final gift = _availableGifts[index];
                        return Card(
                          color: const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFF334155)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Gift Icon
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF475569)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      gift['icon']!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Gift Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        gift['name']!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        gift['desc']!,
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Play Button
                                ElevatedButton.icon(
                                  onPressed: () => _playGiftAnimation(gift['svga']!, gift['name']!),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF7A45),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.play_arrow, size: 20),
                                  label: const Text('Send Gift'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (_isPlayingGift) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF7A45)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Playing: $_activeGiftName',
                            style: const TextStyle(
                              color: Color(0xFFFF7A45),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: _stopGiftAnimation,
                            child: const Text('Stop Animation', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 2. Full-Screen SVGA Gift Overlay Layer
          if (_isPlayingGift && _svgaController?.videoItem != null)
            Positioned.fill(
              child: IgnorePointer(
                child: SVGAImage(
                  _svgaController!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
