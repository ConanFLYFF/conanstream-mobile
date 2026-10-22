import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'shared_prefs_helper.dart';
import 'player_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'favorites_screen.dart';

class LiveChannelsScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;

  const LiveChannelsScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen> {
  List<dynamic> categories = [];
  List<dynamic> channels = [];
  List<dynamic> filteredChannels = [];

  String? selectedCategoryId;
  Map<String, dynamic>? selectedChannel;

  bool isLoadingCategories = true;
  bool isLoadingChannels = false;

  final TextEditingController _searchController = TextEditingController();

  Set<String> favoriteStreamIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _fetchCategories();
  }

  Future<void> _loadFavorites() async {
    final favs = await SharedPrefsHelper.getFavorites('fav_channels');
    if (mounted) {
      setState(() {
        favoriteStreamIds = favs.map((e) => e['stream_id'].toString()).toSet();
      });
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> channel) async {
    final streamId = channel['stream_id'].toString();
    await SharedPrefsHelper.toggleFavorite('fav_channels', channel);
    await _loadFavorites();
  }

  Future<void> _fetchCategories() async {
    try {
      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;

      final url = Uri.parse(
        '$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_live_categories',
      );

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        if (mounted) {
          setState(() {
            categories = data;
            isLoadingCategories = false;
            if (categories.isNotEmpty) {
              selectedCategoryId = categories.first['category_id'].toString();
              _fetchChannels(selectedCategoryId!);
            }
          });
        }
      } else {
        if (mounted) setState(() => isLoadingCategories = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingCategories = false);
    }
  }

  Future<void> _fetchChannels(String categoryId) async {
    setState(() {
      isLoadingChannels = true;
      channels = [];
      filteredChannels = [];
    });

    try {
      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;

      final url = Uri.parse(
        '$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_live_streams&category_id=$categoryId',
      );

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        if (mounted) {
          setState(() {
            channels = data;
            filteredChannels = data;
            isLoadingChannels = false;
            if (channels.isNotEmpty) {
              selectedChannel = channels.first;
            }
          });
        }
      } else {
        if (mounted) setState(() => isLoadingChannels = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingChannels = false);
    }
  }

  void _filterChannels(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredChannels = channels;
      } else {
        filteredChannels = channels.where((ch) {
          final name = (ch['name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _playChannel(Map<String, dynamic> channel) {
    final String baseUrl = widget.serverUrl.endsWith('/')
        ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
        : widget.serverUrl;

    final streamId = channel['stream_id'].toString();
    final streamUrl = '$baseUrl/live/${widget.username}/${widget.password}/$streamId.ts';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: streamUrl,
          title: channel['name'] ?? 'Chaîne TV',
          vodId: streamId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      body: SafeArea(
        child: Column(
          children: [
            // BARRE DE NAVIGATION SUPÉRIEURE (AVEC LES ONGLETS TV, FILMS, SÉRIES ET FAVORIS)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1222),
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  
                  // Onglet Télévision en direct (Actif)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF23325B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {},
                    child: const Text('Télévision en direct', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),

                  // Onglet Films
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
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
                    child: const Text('Films', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 10),

                  // Onglet Série
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
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
                    child: const Text('Série', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 10),

                  // AJOUT DE L'ONGLET FAVORIS
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
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
                    child: const Text('Favoris', style: TextStyle(color: Colors.white70)),
                  ),

                  const Spacer(),

                  // Champ de recherche
                  SizedBox(
                    width: 300,
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterChannels,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une chaîne...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF141C33),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // CONTENU PRINCIPAL
            Expanded(
              child: Row(
                children: [
                  // Colonne Gauche : Catégories
                  Container(
                    width: 280,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0C101D),
                      border: Border(right: BorderSide(color: Colors.white10)),
                    ),
                    child: isLoadingCategories
                        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                        : ListView.builder(
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final catId = cat['category_id'].toString();
                              final isSelected = selectedCategoryId == catId;

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: const Color(0xFF18223D),
                                title: Text(
                                  cat['category_name'] ?? 'Catégorie',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () {
                                  setState(() => selectedCategoryId = catId);
                                  _fetchChannels(catId);
                                },
                              );
                            },
                          ),
                  ),

                  // Colonne Milieu : Liste des chaînes
                  Expanded(
                    flex: 5,
                    child: isLoadingChannels
                        ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                        : ListView.builder(
                            itemCount: filteredChannels.length,
                            itemBuilder: (context, index) {
                              final ch = filteredChannels[index];
                              final streamId = ch['stream_id'].toString();
                              final isFav = favoriteStreamIds.contains(streamId);
                              final isSelected = selectedChannel?['stream_id'].toString() == streamId;

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF1D294A) : const Color(0xFF111728),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? Colors.indigoAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () => setState(() => selectedChannel = ch),
                                  title: Text(
                                    ch['name'] ?? 'Chaîne',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: isFav ? Colors.redAccent : Colors.white38,
                                    ),
                                    onPressed: () => _toggleFavorite(ch),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Colonne Droite : Aperçu et détails de la chaîne sélectionnée
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: const Color(0xFF090D1A),
                      child: selectedChannel == null
                          ? const Center(child: Text('Aucune chaîne sélectionnée', style: TextStyle(color: Colors.white38)))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedChannel!['name'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Center(
                                      child: IconButton(
                                        iconSize: 64,
                                        icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.indigoAccent),
                                        onPressed: () => _playChannel(selectedChannel!),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}