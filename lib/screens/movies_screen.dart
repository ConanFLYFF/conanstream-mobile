import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'movie_details_screen.dart';
import 'live_channels_screen.dart';
import 'series_screen.dart';
import 'favorites_screen.dart';
import 'in_progress_screen.dart';
import 'shared_prefs_helper.dart';
import 'glass_card.dart';

class MoviesScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;

  const MoviesScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List categories = [];
  List allMovies = [];
  List filteredMovies = [];
  String selectedCategoryId = 'all';
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategoriesAndMovies();
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url == 'https://image.tmdb.org/t/p/w600_and_h900_bestv2' || url.endsWith('/p/w600_and_h900_bestv2')) {
      return false;
    }
    return true;
  }

  Future<void> _fetchCategoriesAndMovies() async {
    try {
      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;

      final catUrl = Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_vod_categories');
      final moviesUrl = Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_vod_streams');

      final catRes = await http.get(catUrl);
      final moviesRes = await http.get(moviesUrl);

      List parsedCats = [
        {'category_id': 'all', 'category_name': 'Tout'}
      ];

      if (catRes.statusCode == 200) {
        final catData = json.decode(catRes.body);
        if (catData is List) parsedCats.addAll(catData);
      }

      if (moviesRes.statusCode == 200) {
        final moviesData = json.decode(moviesRes.body);
        if (moviesData is List) {
          setState(() {
            categories = parsedCats;
            allMovies = moviesData;
            filteredMovies = moviesData;
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
      filteredMovies = allMovies.where((item) {
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
                    const _NavPill(
                      label: 'Films',
                      isSelected: true,
                      borderColor: Color(0xFFFF007F),
                    ),
                    const SizedBox(width: 8),
                    _NavPill(
                      label: 'Série',
                      isSelected: false,
                      borderColor: const Color(0xFFD500F9),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SeriesScreen(
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
                            hintText: 'Rechercher un film...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFFFF007F), size: 20),
                            filled: true,
                            fillColor: const Color(0xFF161C2E).withOpacity(0.6),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: const Color(0xFFFF007F).withOpacity(0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: const Color(0xFFFF007F).withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Color(0xFFFF007F)),
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
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF007F)))
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
                                  selectedTileColor: const Color(0xFFFF007F).withOpacity(0.15),
                                  title: Text(
                                    cat['category_name'],
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFFFF007F) : Colors.white70,
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
                                  childAspectRatio: 0.61,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: filteredMovies.length,
                                itemBuilder: (context, index) {
                                  final item = filteredMovies[index];
                                  final posterUrl = item['stream_icon'] ?? '';
                                  final title = item['name'] ?? 'Film';
                                  final movieId = item['stream_id'].toString();

                                  return GlassCard(
                                    borderColor: const Color(0xFFFF007F),
                                    borderRadius: 12,
                                    opacity: 0.1,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MovieDetailsScreen(
                                            serverUrl: widget.serverUrl,
                                            username: widget.username,
                                            password: widget.password,
                                            movie: item,
                                          ),
                                        ),
                                      ).then((_) => setState(() {}));
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: _isValidImageUrl(posterUrl)
                                                    ? CachedNetworkImage(
                                                        imageUrl: posterUrl,
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        placeholder: (context, url) => Container(color: Colors.white10),
                                                        errorWidget: (context, url, error) => Container(
                                                          color: Colors.white10,
                                                          child: const Icon(Icons.movie, color: Colors.white38, size: 40),
                                                        ),
                                                      )
                                                    : Container(
                                                        color: Colors.white10,
                                                        child: const Icon(Icons.movie, color: Colors.white38, size: 40),
                                                      ),
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: FutureBuilder<double>(
                                                  future: SharedPrefsHelper.getVodProgress(movieId),
                                                  builder: (context, snapshot) {
                                                    final progress = snapshot.data ?? 0.0;
                                                    if (progress <= 0.0) return const SizedBox.shrink();
                                                    return LinearProgressIndicator(
                                                      value: progress,
                                                      backgroundColor: Colors.white24,
                                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF007F)),
                                                      minHeight: 4,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
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