import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'shared_prefs_helper.dart';
import 'movie_details_screen.dart';
import 'series_details_screen.dart';
import 'live_channels_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'favorites_screen.dart';

class InProgressScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;

  const InProgressScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  State<InProgressScreen> createState() => _InProgressScreenState();
}

class _InProgressScreenState extends State<InProgressScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _inProgressMovies = [];
  List<Map<String, dynamic>> _inProgressSeries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInProgressItems();
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url == 'https://image.tmdb.org/t/p/w600_and_h900_bestv2' || url.endsWith('/p/w600_and_h900_bestv2')) {
      return false;
    }
    return true;
  }

  Future<void> _loadInProgressItems() async {
    setState(() => _isLoading = true);

    final movies = await SharedPrefsHelper.getFavorites('in_progress_movies');
    final series = await SharedPrefsHelper.getFavorites('in_progress_series');

    List<Map<String, dynamic>> validMovies = [];
    List<Map<String, dynamic>> validSeries = [];

    for (var m in movies.whereType<Map>()) {
      final map = Map<String, dynamic>.from(m);
      final id = (map['stream_id'] ?? map['id'] ?? '').toString();
      final progress = await SharedPrefsHelper.getVodProgress(id);
      if (progress > 0.001 && progress < 0.95) {
        validMovies.add(map);
      }
    }

    for (var s in series.whereType<Map>()) {
      final map = Map<String, dynamic>.from(s);
      validSeries.add(map);
    }

    if (mounted) {
      setState(() {
        _inProgressMovies = validMovies;
        _inProgressSeries = validSeries;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF0C101C),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 8),
                _NavPill(
                  label: 'Télévision en direct',
                  isSelected: false,
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
                _NavPill(
                  label: 'Série',
                  isSelected: false,
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
                  onTap: () {
                    Navigator.pushReplacement(
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
                const _NavPill(label: 'En cours', isSelected: true),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF0C101C),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.indigoAccent,
              labelColor: Colors.indigoAccent,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(icon: Icon(Icons.movie), text: 'Films'),
                Tab(icon: Icon(Icons.tv), text: 'Séries'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGrid(_inProgressMovies, isMovie: true),
                      _buildGrid(_inProgressSeries, isMovie: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> items, {required bool isMovie}) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isMovie ? 'Aucun film en cours.' : 'Aucune série en cours.',
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 0.61,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final posterUrl = item['stream_icon'] ?? item['cover'] ?? '';
          final title = item['name'] ?? item['title'] ?? 'Titre';
          final itemId = (item['stream_id'] ?? item['series_id'] ?? item['id'] ?? '').toString();

          return FutureBuilder<double>(
            future: SharedPrefsHelper.getVodProgress(itemId),
            builder: (context, snapshot) {
              final progress = snapshot.data ?? 0.0;

              return InkWell(
                onTap: () {
                  if (isMovie) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MovieDetailsScreen(
                          serverUrl: widget.serverUrl,
                          username: widget.username,
                          password: widget.password,
                          movie: item,
                        ),
                      ),
                    ).then((_) => _loadInProgressItems());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SeriesDetailsScreen(
                          serverUrl: widget.serverUrl,
                          username: widget.username,
                          password: widget.password,
                          series: item,
                        ),
                      ),
                    ).then((_) => _loadInProgressItems());
                  }
                },
                borderRadius: BorderRadius.circular(8),
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
                                      child: Icon(isMovie ? Icons.movie : Icons.tv, color: Colors.white38, size: 40),
                                    ),
                                  )
                                : Container(
                                    color: Colors.white10,
                                    child: Icon(isMovie ? Icons.movie : Icons.tv, color: Colors.white38, size: 40),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: progress > 0 ? progress : 0.05,
                              backgroundColor: Colors.black54,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
                              minHeight: 4,
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
          );
        },
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _NavPill({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C3258) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.indigoAccent : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}