import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'player_screen.dart';
import 'shared_prefs_helper.dart';
import 'utils/api_client.dart';
import 'utils/app_logger.dart';

class MovieDetailsScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;
  final Map<String, dynamic> movie;

  const MovieDetailsScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.movie,
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  Map<String, dynamic>? movieInfo;
  bool isLoading = true;
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    AppLogger.action('NAVIGATION', 'Ouverture Fiche Film : ${widget.movie['name'] ?? widget.movie['title']}');
    _fetchMovieDetails();
    _checkFavoriteStatus();
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url == 'https://image.tmdb.org/t/p/w600_and_h900_bestv2' || url.endsWith('/p/w600_and_h900_bestv2')) {
      return false;
    }
    return true;
  }

  Future<void> _checkFavoriteStatus() async {
    final streamId = widget.movie['stream_id']?.toString() ?? widget.movie['id']?.toString() ?? '';
    final fav = await SharedPrefsHelper.isFavorite('fav_movies', streamId);
    if (mounted) {
      setState(() {
        isFavorite = fav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    await SharedPrefsHelper.toggleFavorite('fav_movies', widget.movie);
    final streamId = widget.movie['stream_id']?.toString() ?? widget.movie['id']?.toString() ?? '';
    final updatedFav = await SharedPrefsHelper.isFavorite('fav_movies', streamId);
    if (mounted) {
      setState(() {
        isFavorite = updatedFav;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: isFavorite ? const Color(0xFFFF007F) : Colors.grey[800],
        ),
      );
    }
  }

  Future<void> _fetchMovieDetails() async {
    try {
      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;

      final streamId = widget.movie['stream_id']?.toString() ?? widget.movie['id']?.toString() ?? '';
      final url = Uri.parse(
        '$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_vod_info&vod_id=$streamId',
      );

      final data = await ApiClient.getJson(url);
      if (mounted) {
        setState(() {
          movieInfo = data;
          isLoading = false;
        });
      }
    } catch (e, stack) {
      AppLogger.error('FETCH_MOVIE_DETAILS', e, stack);
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _playMovie() async {
    final String baseUrl = widget.serverUrl.endsWith('/')
        ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
        : widget.serverUrl;

    final streamId = widget.movie['stream_id']?.toString() ?? widget.movie['id']?.toString() ?? '';
    
    await SharedPrefsHelper.trackInProgress('movie', widget.movie);

    final movieData = movieInfo?['movie_data'] as Map<String, dynamic>?;
    final info = movieInfo?['info'] as Map<String, dynamic>?;

    final ext = widget.movie['container_extension'] ??
        movieData?['container_extension'] ??
        info?['container_extension'] ??
        'mp4';

    final streamUrl = '$baseUrl/movie/${widget.username}/${widget.password}/$streamId.$ext';
    final title = widget.movie['name'] ?? widget.movie['title'] ?? 'Film';

    AppLogger.action('PLAYER', 'Lancement Film : $title ($streamUrl)');

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: streamUrl,
          title: title,
          vodId: streamId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.movie['name'] ?? widget.movie['title'] ?? 'Film inconnu';
    final posterUrl = widget.movie['stream_icon'] ?? widget.movie['cover'] ?? '';

    final infoData = movieInfo?['info'];
    final plot = infoData?['plot']?.toString() ?? 'Aucun synopsis disponible pour ce film.';
    final genre = infoData?['genre']?.toString() ?? 'Film';
    
    // Correction sécurisée des types (String forcée pour éviter l'erreur d'index/type)
    final releaseDate = infoData?['releasedate']?.toString() ?? infoData?['year']?.toString() ?? '';
    final duration = infoData?['duration']?.toString() ?? '';

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
              AppBar(
                backgroundColor: const Color(0xFF0C101C).withOpacity(0.8),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF007F)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(32.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 280,
                                height: 420,
                                child: _isValidImageUrl(posterUrl)
                                    ? CachedNetworkImage(
                                        imageUrl: posterUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: Colors.white10),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.white10,
                                          child: const Icon(Icons.movie, color: Colors.white38, size: 80),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.white10,
                                        child: const Icon(Icons.movie, color: Colors.white38, size: 80),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 40),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      if (genre.isNotEmpty)
                                        Text('Genre : $genre', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                      if (releaseDate.isNotEmpty)
                                        Text('Date de sortie : $releaseDate', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                      if (duration.isNotEmpty)
                                        Text('Durée : $duration', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    plot,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF007F),
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                        label: const Text(
                                          'LANCER LE FILM',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: _playMovie,
                                      ),
                                      const SizedBox(width: 16),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: isFavorite ? Colors.redAccent : Colors.white24,
                                            width: 1.5,
                                          ),
                                          backgroundColor: isFavorite ? Colors.redAccent.withOpacity(0.15) : Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: Icon(
                                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                          color: isFavorite ? Colors.redAccent : Colors.white,
                                          size: 22,
                                        ),
                                        label: Text(
                                          isFavorite ? 'RETIRER DES FAVORIS' : 'AJOUTER AUX FAVORIS',
                                          style: TextStyle(
                                            color: isFavorite ? Colors.redAccent : Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: _toggleFavorite,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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