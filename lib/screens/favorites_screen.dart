import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:window_manager/window_manager.dart';
import 'shared_prefs_helper.dart';
import 'player_screen.dart';
import 'movie_details_screen.dart';
import 'series_details_screen.dart';
import 'live_channels_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'in_progress_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;

  const FavoritesScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _favoriteLive = [];
  List<dynamic> _favoriteMovies = [];
  List<dynamic> _favoriteSeries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFavorites();
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url == 'https://image.tmdb.org/t/p/w600_and_h900_bestv2' || url.endsWith('/p/w600_and_h900_bestv2')) {
      return false;
    }
    return true;
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final live = await SharedPrefsHelper.getFavorites('favorite_channels');
    final movies = await SharedPrefsHelper.getFavorites('favorite_movies');
    final series = await SharedPrefsHelper.getFavorites('favorite_series');

    if (mounted) {
      setState(() {
        _favoriteLive = live;
        _favoriteMovies = movies;
        _favoriteSeries = series;
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
                    windowManager.unmaximize();
                    windowManager.setTitleBarStyle(TitleBarStyle.normal);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 8),
                _NavPill(
                  label: 'Télévision en direct',
                  isSelected: false,
                  onTap: () {
                    windowManager.unmaximize();
                    windowManager.setTitleBarStyle(TitleBarStyle.normal);
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
                    windowManager.unmaximize();
                    windowManager.setTitleBarStyle(TitleBarStyle.normal);
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
                    windowManager.unmaximize();
                    windowManager.setTitleBarStyle(TitleBarStyle.normal);
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
                const _NavPill(label: 'Favoris', isSelected: true),
                const SizedBox(width: 8),
                _NavPill(
                  label: 'En cours',
                  isSelected: false,
                  onTap: () {
                    windowManager.unmaximize();
                    windowManager.setTitleBarStyle(TitleBarStyle.normal);
                    Navigator.pushReplacement(
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
                Tab(icon: Icon(Icons.live_tv), text: 'Direct'),
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
                      _buildChannelsList(_favoriteLive, 'favorite_channels'),
                      _buildGrid(_favoriteMovies, 'favorite_movies', isMovie: true),
                      _buildGrid(_favoriteSeries, 'favorite_series', isMovie: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsList(List<dynamic> items, String prefKey) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Aucun favori dans cette catégorie.', style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final title = item is Map ? (item['name'] ?? item['title'] ?? 'Chaîne') : item.toString();
        final streamId = item is Map ? (item['stream_id'] ?? item['id'] ?? '').toString() : '';
        final logoUrl = item is Map ? (item['stream_icon'] ?? '') : '';

        return Card(
          color: const Color(0xFF13192B),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 40,
                child: _isValidImageUrl(logoUrl)
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.indigoAccent),
                      )
                    : const Icon(Icons.live_tv, color: Colors.indigoAccent),
              ),
            ),
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              onPressed: () async {
                await SharedPrefsHelper.toggleFavorite(prefKey, item);
                _loadFavorites();
              },
            ),
            onTap: () {
              if (streamId.isNotEmpty) {
                final url = '${widget.serverUrl}/live/${widget.username}/${widget.password}/$streamId.ts';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      streamUrl: url,
                      title: title,
                      vodId: streamId,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<dynamic> items, String prefKey, {required bool isMovie}) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Aucun favori dans cette catégorie.', style: TextStyle(color: Colors.white54, fontSize: 16)),
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
          if (item is! Map) return const SizedBox.shrink();

          final itemMap = Map<String, dynamic>.from(item);
          final posterUrl = itemMap['stream_icon'] ?? itemMap['cover'] ?? '';
          final title = itemMap['name'] ?? itemMap['title'] ?? 'Sans nom';

          return Stack(
            children: [
              InkWell(
                onTap: () {
                  if (isMovie) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MovieDetailsScreen(
                          serverUrl: widget.serverUrl,
                          username: widget.username,
                          password: widget.password,
                          movie: itemMap,
                        ),
                      ),
                    ).then((_) => _loadFavorites());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SeriesDetailsScreen(
                          serverUrl: widget.serverUrl,
                          username: widget.username,
                          password: widget.password,
                          series: itemMap,
                        ),
                      ),
                    ).then((_) => _loadFavorites());
                  }
                },
                borderRadius: BorderRadius.circular(8),
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
                                  child: Icon(isMovie ? Icons.movie : Icons.tv, color: Colors.white38, size: 40),
                                ),
                              )
                            : Container(
                                color: Colors.white10,
                                child: Icon(isMovie ? Icons.movie : Icons.tv, color: Colors.white38, size: 40),
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
              ),
              Positioned(
                top: 4,
                right: 4,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                    onPressed: () async {
                      await SharedPrefsHelper.toggleFavorite(prefKey, item);
                      _loadFavorites();
                    },
                    tooltip: 'Retirer des favoris',
                  ),
                ),
              ),
            ],
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