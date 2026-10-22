import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'series_details_screen.dart';
import 'live_channels_screen.dart';
import 'movies_screen.dart';
import 'favorites_screen.dart';
import 'in_progress_screen.dart';
import 'glass_card.dart';

class SeriesScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;

  const SeriesScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List categories = [];
  List allSeries = [];
  List filteredSeries = [];
  String selectedCategoryId = 'all';
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategoriesAndSeries();
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url == 'https://image.tmdb.org/t/p/w600_and_h900_bestv2' || url.endsWith('/p/w600_and_h900_bestv2')) {
      return false;
    }
    return true;
  }

  Future<void> _fetchCategoriesAndSeries() async {
    try {
      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;

      final catUrl = Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_series_categories');
      final seriesUrl = Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_series');

      final catRes = await http.get(catUrl);
      final seriesRes = await http.get(seriesUrl);

      List parsedCats = [
        {'category_id': 'all', 'category_name': 'Tous'}
      ];

      if (catRes.statusCode == 200) {
        final catData = json.decode(catRes.body);
        if (catData is List) parsedCats.addAll(catData);
      }

      if (seriesRes.statusCode == 200) {
        final seriesData = json.decode(seriesRes.body);
        if (seriesData is List) {
          setState(() {
            categories = parsedCats;
            allSeries = seriesData;
            filteredSeries = seriesData;
            isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredSeries = allSeries.where((item) {
        final matchesCat = selectedCategoryId == 'all' ||
            item['category_id'].toString() == selectedCategoryId;
        final matchesSearch = searchQuery.isEmpty ||
            (item['name'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase());
        return matchesCat && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.6),
                  radius: 1.4,
                  colors: [
                    Color(0xFF0D2847),
                    Color(0xFF070A14),
                    Color(0xFF030408),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Navigation supérieure
              Container(
                color: const Color(0xFF0C101C).withOpacity(0.8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    _NavPill(
                      label: 'Télévision en direct',
                      isSelected: false,
                      borderColor: const Color(0xFF00E5FF),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveChannelsScreen(
                              serverUrl: widget.serverUrl,
                              username: widget.username,
                              password: widget.password,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _NavPill(
                      label: 'Films',
                      isSelected: false,
                      borderColor: const Color(0xFFFF007F),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MoviesScreen(
                              serverUrl: widget.serverUrl,
                              username: widget.username,
                              password: widget.password,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const _NavPill(
                      label: 'Série',
                      isSelected: true,
                      borderColor: Color(0xFFD500F9),
                    ),
                    const SizedBox(width: 8),
                    _NavPill(
                      label: 'Favoris',
                      isSelected: false,
                      borderColor: const Color(0xFFFF3D00),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FavoritesScreen(
                              serverUrl: widget.serverUrl,
                              username: widget.username,
                              password: widget.password,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _NavPill(
                      label: 'En cours',
                      isSelected: false,
                      borderColor: const Color(0xFF00E676),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InProgressScreen(
                              serverUrl: widget.serverUrl,
                              username: widget.username,
                              password: widget.password,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Rechercher une série...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFFD500F9), size: 20),
                            filled: true,
                            fillColor: const Color(0xFF161C2E).withOpacity(0.6),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: const Color(0xFFD500F9).withOpacity(0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: const Color(0xFFD500F9).withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Color(0xFFD500F9)),
                            ),
                          ),
                          onChanged: (val) {
                            searchQuery = val;
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD500F9)))
                    : Row(
                        children: [
                          Container(
                            width: 250,
                            color: Colors.black.withOpacity(0.3),
                            child: ListView.builder(
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                final catId = cat['category_id'].toString();
                                final isSelected = selectedCategoryId == catId;

                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: const Color(0xFFD500F9).withOpacity(0.15),
                                  title: Text(
                                    cat['category_name'],
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFFD500F9) : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      selectedCategoryId = catId;
                                      _applyFilters();
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  childAspectRatio: 0.65,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: filteredSeries.length,
                                itemBuilder: (context, index) {
                                  final item = filteredSeries[index];
                                  final posterUrl = item['cover'] ?? '';
                                  final title = item['name'] ?? 'Série';

                                  return GlassCard(
                                    borderColor: const Color(0xFFD500F9),
                                    borderRadius: 12,
                                    opacity: 0.1,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SeriesDetailsScreen(
                                            serverUrl: widget.serverUrl,
                                            username: widget.username,
                                            password: widget.password,
                                            series: item,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: _isValidImageUrl(posterUrl)
                                                ? CachedNetworkImage(
                                                    imageUrl: posterUrl,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    placeholder: (context, url) => Container(color: Colors.white10),
                                                    errorWidget: (context, url, error) => Container(
                                                      color: Colors.white10,
                                                      child: const Icon(Icons.tv, color: Colors.white38, size: 40),
                                                    ),
                                                  )
                                                : Container(
                                                    color: Colors.white10,
                                                    child: const Icon(Icons.tv, color: Colors.white38, size: 40),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          title,
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavPill extends StatefulWidget {
  final String label;
  final bool isSelected;
  final Color borderColor;
  final VoidCallback? onTap;

  const _NavPill({
    required this.label,
    required this.isSelected,
    this.borderColor = Colors.indigoAccent,
    this.onTap,
  });

  @override
  State<_NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<_NavPill> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected || _isFocused;

    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      child: InkWell(
        onTap: widget.onTap ?? () {},
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? widget.borderColor.withOpacity(0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? widget.borderColor : Colors.white24,
              width: _isFocused ? 2.0 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: widget.borderColor.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}