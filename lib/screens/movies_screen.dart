import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

// Fonction de parsing M3U en arrière-plan pour extraire strictement les VOD (Films)
Map<String, dynamic> _parseM3uMoviesInBackground(String content) {
  final lines = content.split('\n');
  List<Map<String, dynamic>> movies = [];
  Map<String, String> categoryMap = {};
  int id = 1;

  String currentName = '';
  String currentLogo = '';
  String currentGroup = 'Films';

  for (var line in lines) {
    line = line.trim();
    if (line.startsWith('#EXTINF:')) {
      currentName = '';
      currentLogo = '';
      currentGroup = 'Films';

      final commaIndex = line.lastIndexOf(',');
      if (commaIndex != -1 && commaIndex < line.length - 1) {
        currentName = line.substring(commaIndex + 1).trim();
      }

      final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
      if (logoMatch != null) currentLogo = logoMatch.group(1) ?? '';

      final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
      if (groupMatch != null) currentGroup = groupMatch.group(1) ?? 'Films';
    } else if (line.isNotEmpty && !line.startsWith('#')) {
      final lowerUrl = line.toLowerCase();
      
      // Filtre strict : Vrai fichier vidéo et exclusion formelle du Live TV
      final isVideoFile = lowerUrl.endsWith('.mp4') || 
                          lowerUrl.endsWith('.mkv') || 
                          lowerUrl.endsWith('.avi') || 
                          lowerUrl.endsWith('.mov') ||
                          lowerUrl.endsWith('.m4v');

      final isLiveStream = lowerUrl.contains('/live/') || lowerUrl.endsWith('.m3u8') || lowerUrl.endsWith('.ts');

      if (isVideoFile && !isLiveStream) {
        categoryMap[currentGroup] = currentGroup;
        movies.add({
          'stream_id': id++,
          'name': currentName.isEmpty ? 'Film sans titre' : currentName,
          'stream_icon': currentLogo,
          'category_id': currentGroup,
          'category_name': currentGroup,
          'stream_url': line,
        });
      }
    }
  }

  List<Map<String, dynamic>> parsedCats = [
    {'category_id': 'all', 'category_name': 'Tout'}
  ];
  categoryMap.keys.forEach((cat) {
    parsedCats.add({'category_id': cat, 'category_name': cat});
  });

  return {
    'categories': parsedCats,
    'movies': movies,
  };
}

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
      final isLocalFile = !widget.serverUrl.startsWith('http://') && !widget.serverUrl.startsWith('https://');
      final isM3uLink = widget.serverUrl.contains('.m3u') || widget.serverUrl.contains('.m3u8');

      // --- TRAITEMENT SOURCE M3U / FICHIER LOCAL ---
      if (isLocalFile || isM3uLink) {
        String content = '';
        if (isLocalFile) {
          final file = File(widget.serverUrl);
          if (await file.exists()) content = await file.readAsString();
        } else {
          final res = await http.get(Uri.parse(widget.serverUrl)).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) content = res.body;
        }

        if (content.isNotEmpty) {
          final parsedData = await compute(_parseM3uMoviesInBackground, content);
          if (mounted) {
            setState(() {
              categories = parsedData['categories'];
              allMovies = parsedData['movies'];
              filteredMovies = parsedData['movies'];
              isLoading = false;
            });
          }
          return;
        }
      }

      // --- TRAITEMENT SOURCE XTREAM API ---
      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;

      final catUrl = Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_vod_categories');
      final moviesUrl = Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_vod_streams');

      final catRes = await http.get(catUrl).timeout(const Duration(seconds: 10));
      final moviesRes = await http.get(moviesUrl).timeout(const Duration(seconds: 10));

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
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        categories = [{'category_id': 'all', 'category_name': 'Tout'}];
        allMovies = [];
        filteredMovies = [];
        isLoading = false;
      });
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
                    : filteredMovies.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun film disponible sur cette source.',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                            ),
                          )
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