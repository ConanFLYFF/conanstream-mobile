import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'movie_details_screen.dart';
import 'series_details_screen.dart';

class SearchScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;

  const SearchScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List allMovies = [];
  List allSeries = [];
  List searchResultsMovies = [];
  List searchResultsSeries = [];
  bool isLoading = true;
  String query = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url == 'https://image.tmdb.org/t/p/w600_and_h900_bestv2' || url.endsWith('/p/w600_and_h900_bestv2')) {
      return false;
    }
    return true;
  }

  Future<void> _fetchData() async {
    try {
      final String baseUrl = widget.serverUrl.endsWith('/') ? widget.serverUrl.substring(0, widget.serverUrl.length - 1) : widget.serverUrl;

      final movieRes = await http.get(Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_vod_streams'));
      final seriesRes = await http.get(Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_series'));

      if (movieRes.statusCode == 200) {
        final data = json.decode(movieRes.body);
        if (data is List) allMovies = data;
      }
      if (seriesRes.statusCode == 200) {
        final data = json.decode(seriesRes.body);
        if (data is List) allSeries = data;
      }
    } catch (_) {}

    if (mounted) setState(() => isLoading = false);
  }

  void _filter(String val) {
    setState(() {
      query = val.toLowerCase();
      if (query.isEmpty) {
        searchResultsMovies = [];
        searchResultsSeries = [];
      } else {
        searchResultsMovies = allMovies.where((m) => (m['name'] ?? '').toString().toLowerCase().contains(query)).toList();
        searchResultsSeries = allSeries.where((s) => (s['name'] ?? '').toString().toLowerCase().contains(query)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C101C),
        title: TextField(
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Rechercher un film ou une série...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
          onChanged: _filter,
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : query.isEmpty
              ? const Center(child: Text('Tapez un nom pour lancer la recherche', style: TextStyle(color: Colors.white54)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (searchResultsMovies.isNotEmpty) ...[
                      const Text('Films', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: searchResultsMovies.length,
                          itemBuilder: (context, index) {
                            final m = searchResultsMovies[index];
                            final posterUrl = m['stream_icon'] ?? '';
                            return Container(
                              width: 140,
                              margin: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(serverUrl: widget.serverUrl, username: widget.username, password: widget.password, movie: m))),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _isValidImageUrl(posterUrl)
                                      ? CachedNetworkImage(
                                          imageUrl: posterUrl,
                                          fit: BoxFit.cover,
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
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (searchResultsSeries.isNotEmpty) ...[
                      const Text('Séries', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: searchResultsSeries.length,
                          itemBuilder: (context, index) {
                            final s = searchResultsSeries[index];
                            final coverUrl = s['cover'] ?? '';
                            return Container(
                              width: 140,
                              margin: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailsScreen(serverUrl: widget.serverUrl, username: widget.username, password: widget.password, series: s))),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _isValidImageUrl(coverUrl)
                                      ? CachedNetworkImage(
                                          imageUrl: coverUrl,
                                          fit: BoxFit.cover,
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
                            );
                          },
                        ),
                      ),
                    ],
                    if (searchResultsMovies.isEmpty && searchResultsSeries.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucun résultat trouvé.', style: TextStyle(color: Colors.white54)))),
                  ],
                ),
    );
  }
}