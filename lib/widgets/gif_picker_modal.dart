import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/gif_item.dart';
import '../services/gif_service.dart';

Future<GifItem?> showGifPickerModal(BuildContext context) {
  return showModalBottomSheet<GifItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => const _GifPickerModalSheet(),
  );
}

class _GifPickerModalSheet extends StatefulWidget {
  const _GifPickerModalSheet();

  @override
  State<_GifPickerModalSheet> createState() => _GifPickerModalSheetState();
}

class _GifPickerModalSheetState extends State<_GifPickerModalSheet> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  static const List<String> _categories = [
    'Trending',
    'Cats',
    'Anime',
    'Funny',
    'Love',
    'Sad',
    'Party',
    'Clap',
    'Dance',
    'Wow',
  ];

  String _selectedCategory = 'Trending';
  String _currentQuery = '';
  List<GifItem> _gifs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 24;

  @override
  void initState() {
    super.initState();
    _loadGifs(initial: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 300 && !_isLoading && !_isLoadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadGifs({bool initial = false}) async {
    if (initial) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
        _gifs = [];
      });
    }

    try {
      final query = _currentQuery.trim();
      final List<GifItem> results;
      if (query.isEmpty) {
        results = await GifService.getTrending(offset: 0, limit: _limit);
      } else {
        results = await GifService.search(query, offset: 0, limit: _limit);
      }

      if (!mounted) return;
      setState(() {
        _gifs = results;
        _offset = results.length;
        _hasMore = results.length >= _limit;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final query = _currentQuery.trim();
      final List<GifItem> results;
      if (query.isEmpty) {
        results = await GifService.getTrending(offset: _offset, limit: _limit);
      } else {
        results = await GifService.search(query, offset: _offset, limit: _limit);
      }

      if (!mounted) return;
      setState(() {
        _gifs.addAll(results);
        _offset += results.length;
        _hasMore = results.length >= _limit;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      final clean = text.trim();
      if (clean != _currentQuery) {
        setState(() {
          _currentQuery = clean;
          _selectedCategory = clean.isEmpty ? 'Trending' : '';
        });
        _loadGifs(initial: true);
      }
    });
  }

  void _selectCategory(String cat) {
    if (_selectedCategory == cat && _currentQuery.isEmpty) return;
    setState(() {
      _selectedCategory = cat;
      _searchController.clear();
      _currentQuery = cat == 'Trending' ? '' : cat;
    });
    _loadGifs(initial: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1F22) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF2B2D31) : const Color(0xFFF2F3F5);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final hintColor = isDark ? const Color(0xFF949BA4) : const Color(0xFF6B7280);

    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = (screenHeight * 0.75).clamp(420.0, 720.0);

    return Container(
      height: modalHeight,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    'Choose a GIF',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: hintColor,
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 13.5.sp,
                  color: textColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Search GIFs...',
                  hintStyle: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: hintColor,
                    fontSize: 13.5.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: hintColor,
                    size: 19,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          color: hintColor,
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: surfaceColor,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Category Chips Bar
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => _selectCategory(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF7A45)
                            : surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          fontSize: 12.sp,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : hintColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // GIF Grid
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: const Color(0xFFFF7A45),
                      ),
                    )
                  : _gifs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: 40,
                                color: hintColor.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentQuery.isEmpty
                                    ? 'No GIFs available'
                                    : 'No GIFs found for "$_currentQuery"',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  fontSize: 13.sp,
                                  color: hintColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : MasonryGridView.count(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          itemCount: _gifs.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _gifs.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: const Color(0xFFFF7A45),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final gif = _gifs[index];
                            final h = gif.height != null && gif.width != null && gif.width! > 0
                                ? ((gif.height! / gif.width!) * 160.w).clamp(90.h, 200.h)
                                : 120.h;

                            return GestureDetector(
                              onTap: () => Navigator.of(context).pop(gif),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: h,
                                  color: surfaceColor,
                                  child: RepaintBoundary(
                                    child: CachedNetworkImage(
                                      imageUrl: gif.previewUrl,
                                      fit: BoxFit.cover,
                                      memCacheHeight: (h * 2).round().clamp(140, 400),
                                      fadeInDuration: const Duration(milliseconds: 120),
                                      placeholder: (_, __) => Container(
                                        color: isDark ? Colors.white10 : Colors.black12,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: isDark ? Colors.white10 : Colors.black12,
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          size: 24,
                                          color: hintColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
