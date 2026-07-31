import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

/// A remote-loading Virtual Gift Tester Screen.
/// Loads SVGA animations dynamically via URLs without bloating the APK bundle size!
class GiftTesterScreen extends StatefulWidget {
  const GiftTesterScreen({super.key});

  @override
  State<GiftTesterScreen> createState() => _GiftTesterScreenState();
}

class _GiftTesterScreenState extends State<GiftTesterScreen>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _svgaController;
  bool _isLoading = false;
  bool _isPlayingGift = false;
  String? _activeGiftName;
  final TextEditingController _customUrlController = TextEditingController();

  final List<Map<String, String>> _remoteGifts = [
    {
      'name': '🚀 Rocket Gift (With Sound)',
      'icon': 'assets/gifts/rocket_icon.png',
      'url': 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/rocket_audio.svga',
      'desc': 'Remote SVGA flying rocket with launch sound effect',
    },
    {
      'name': '🚀 Rocket Gift (Silent)',
      'icon': 'assets/gifts/rocket_icon.png',
      'url': 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/rocket.svga',
      'desc': 'Remote SVGA flying rocket (No audio)',
    },
    {
      'name': '🎆 Fireworks Oath (With Sound)',
      'icon': 'assets/gifts/fireworks_icon.png',
      'url': 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/fireworks_audio.svga',
      'desc': 'Grand fireworks display with audio effect',
    },
    {
      'name': '🎆 Fireworks Oath (Silent)',
      'icon': 'assets/gifts/fireworks_icon.png',
      'url': 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/fireworks.svga',
      'desc': 'Grand fireworks display (No audio)',
    },
  ];

  @override
  void initState() {
    super.initState();
    _svgaController = SVGAAnimationController(vsync: this);
  }

  Future<void> _playGiftFromUrl(String url, String giftName) async {
    if (url.trim().isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _isPlayingGift = true;
        _activeGiftName = giftName;
      });

      // Load SVGA animation dynamically from Remote URL (keeps APK small!)
      final videoItem = await SVGAParser.shared.decodeFromURL(url.trim());
      
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      debugPrint('Error downloading/playing SVGA from $url: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlayingGift = false;
          _activeGiftName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load SVGA: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _stopGiftAnimation() {
    _svgaController?.stop();
    setState(() {
      _isPlayingGift = false;
      _activeGiftName = null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    _svgaController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          '🎁 Dynamic SVGA Gift Tester',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // 1. Controls & URL Input UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Remote SVGA Loading (Keeps APK Slim!):',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Custom URL Input Box
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, color: Color(0xFFFF7A45)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _customUrlController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Paste custom SVGA URL here...',
                              hintStyle: TextStyle(color: Color(0xFF64748B)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Color(0xFFFF7A45), size: 28),
                          onPressed: () {
                            if (_customUrlController.text.isNotEmpty) {
                              _playGiftFromUrl(_customUrlController.text, 'Custom URL Gift');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Preset Remote Gifts List
                  Expanded(
                    child: ListView.separated(
                      itemCount: _remoteGifts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final gift = _remoteGifts[index];
                        return Card(
                          color: const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFF334155)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
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
                                const SizedBox(width: 14),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        gift['name']!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
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

                                ElevatedButton.icon(
                                  onPressed: () => _playGiftFromUrl(gift['url']!, gift['name']!),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF7A45),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.cloud_download_rounded, size: 18),
                                  label: const Text('Stream Gift'),
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
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF7A45)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (_isLoading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7A45)),
                                )
                              else
                                const Icon(Icons.play_circle, color: Color(0xFFFF7A45), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                _isLoading ? 'Downloading SVGA...' : 'Playing: $_activeGiftName',
                                style: const TextStyle(color: Color(0xFFFF7A45), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _stopGiftAnimation,
                            child: const Text('Stop', style: TextStyle(color: Colors.redAccent)),
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
          if (_isPlayingGift && !_isLoading && _svgaController?.videoItem != null)
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
