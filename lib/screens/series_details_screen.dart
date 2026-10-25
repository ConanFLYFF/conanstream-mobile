import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'player_screen.dart';
import 'shared_prefs_helper.dart';
import 'utils/api_client.dart';
import 'utils/app_logger.dart';
import 'glass_card.dart';

class SeriesDetailsScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;
  final Map<String, dynamic> series;

  const SeriesDetailsScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.series,
  });

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  Map<String, dynamic>? seriesInfo;
  bool isLoading = true;
  bool isFavorite = false;
  
  List<Map<String, dynamic>> _allEpisodesFlattened = [];
  Map<String, double> _episodesProgress = {};
  int _resumeEpisodeIndex = 0;

  @override
  void initState() {
    super.initState();
    AppLogger.action('NAVIGATION', 'Ouverture Fiche Série : ${widget.series['name']}');
    _fetchSeriesDetails();
    _checkFavoriteStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isLoading) {
      _loadEpisodesProgress();
    }
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url == 'https://image.tmdb.org/t/p/w600_and_h900_bestv2' || url.endsWith('/p/w600_and_h900_bestv2')) {
      return false;
    }
    return true;
  }

  Future<void> _checkFavoriteStatus() async {
    final seriesId = widget.series['series_id'].toString();
    final fav = await SharedPrefsHelper.isFavorite('fav_series', seriesId);
    if (mounted) {
      setState(() {
        isFavorite = fav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final seriesId = widget.series['series_id'].toString();
    await SharedPrefsHelper.toggleFavorite('fav_series', widget.series);
    final updatedFav = await SharedPrefsHelper.isFavorite('fav_series', seriesId);
    if (mounted) {
      setState(() {
        isFavorite = updatedFav;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? 'Série ajoutée aux favoris' : 'Série retirée des favoris',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: isFavorite ? const Color(0xFFD500F9) : Colors.grey[800],
        ),
      );
    }
  }

  void _buildFlattenedEpisodesList(Map<String, dynamic> rawEpisodesData) {
    _allEpisodesFlattened.clear();
    rawEpisodesData.forEach((seasonKey, seasonValue) {
      final episodesList = _normalizeEpisodesList(seasonValue);
      for (var ep in episodesList) {
        final epMap = ep is Map ? Map<String, dynamic>.from(ep) : <String, dynamic>{};
        epMap['season_num'] = seasonKey;
        _allEpisodesFlattened.add(epMap);
      }
    });
  }

  String _getEpId(Map<String, dynamic> epMap) {
    final id = epMap['id'] ?? epMap['episode_id'] ?? epMap['stream_id'] ?? '';
    return id.toString();
  }

  Future<void> _loadEpisodesProgress() async {
    Map<String, double> progressMap = {};
    for (var epMap in _allEpisodesFlattened) {
      final epId = _getEpId(epMap);
      final progress = await SharedPrefsHelper.getVodProgress(epId);
      progressMap[epId] = progress;
    }

    int targetIndex = 0;
    bool foundTarget = false;

    for (int i = 0; i < _allEpisodesFlattened.length; i++) {
      final epId = _getEpId(_allEpisodesFlattened[i]);
      final progress = progressMap[epId] ?? 0.0;

      if (progress > 0.001 && progress < 0.95) {
        targetIndex = i;
        foundTarget = true;
        break;
      }
    }

    if (!foundTarget) {
      for (int i = 0; i < _allEpisodesFlattened.length; i++) {
        final epId = _getEpId(_allEpisodesFlattened[i]);
        final progress = progressMap[epId] ?? 0.0;

        if (progress < 0.95) {
          targetIndex = i;
          foundTarget = true;
          break;
        }
      }
    }

    if (!foundTarget && _allEpisodesFlattened.isNotEmpty) {
      targetIndex = _allEpisodesFlattened.length - 1;
    }

    if (mounted) {
      setState(() {
        _episodesProgress = progressMap;
        _resumeEpisodeIndex = targetIndex;
      });
    }
  }

  Future<void> _fetchSeriesDetails() async {
    try {
      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;

      final seriesId = widget.series['series_id'].toString();
      final url = Uri.parse(
        '$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_series_info&series_id=$seriesId',
      );

      final data = await ApiClient.getJson(url);
      if (mounted) {
        setState(() {
          seriesInfo = data;
          if (data != null && data['episodes'] != null) {
            _buildFlattenedEpisodesList(_parseEpisodes(data['episodes']));
          }
          isLoading = false;
        });
        await _loadEpisodesProgress();
      }
    } catch (e, stack) {
      AppLogger.error('FETCH_SERIES_DETAILS', e, stack);
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _playEpisodeByIndex(int index, {bool replace = false}) async {
    if (index < 0 || index >= _allEpisodesFlattened.length) return;

    await SharedPrefsHelper.trackInProgress('series', widget.series);

    final epMap = _allEpisodesFlattened[index];
    final epId = _getEpId(epMap);
    final epNum = (epMap['episode_num'] ?? '1').toString();
    final seasonNum = epMap['season_num'] ?? '1';
    final epTitle = epMap['title'] ?? 'Épisode $epNum';

    String containerExt = (epMap['container_extension'] ?? 'mp4').toString().trim();
    if (containerExt.isEmpty) containerExt = 'mp4';

    final title = widget.series['name'] ?? 'Série';

    final String baseUrl = widget.serverUrl.endsWith('/')
        ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
        : widget.serverUrl;

    final streamUrl = '$baseUrl/series/${widget.username}/${widget.password}/$epId.$containerExt';
    final fullTitle = '$title - S${seasonNum}E$epNum : $epTitle';

    AppLogger.action('PLAYER', 'Lancement Épisode : $fullTitle ($streamUrl)');

    final route = MaterialPageRoute(
      builder: (_) => PlayerScreen(
        streamUrl: streamUrl,
        title: fullTitle,
        vodId: epId,
        onPrevious: index > 0
            ? () {
                _playEpisodeByIndex(index - 1, replace: true);
              }
            : null,
        onNext: index < _allEpisodesFlattened.length - 1
            ? () async {
                await SharedPrefsHelper.saveVodProgress(epId, 1.0);
                _playEpisodeByIndex(index + 1, replace: true);
              }
            : null,
        onEnded: (nextFullScreen) async {
          if (mounted) {
            await SharedPrefsHelper.saveVodProgress(epId, 1.0);
            setState(() {
              _episodesProgress[epId] = 1.0;
            });
            _playEpisodeByIndex(index + 1, replace: true);
          }
        },
      ),
    );

    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route).then((_) {
        _loadEpisodesProgress();
      });
    }
  }

  Map<String, dynamic> _parseEpisodes(dynamic rawEpisodes) {
    if (rawEpisodes is Map<String, dynamic>) {
      return rawEpisodes;
    } else if (rawEpisodes is List) {
      return {'1': rawEpisodes};
    }
    return {};
  }

  List<dynamic> _normalizeEpisodesList(dynamic seasonVal) {
    if (seasonVal is List) {
      return seasonVal;
    } else if (seasonVal is Map) {
      return seasonVal.values.toList();
    }
    return [];
  }

  void _playResumeEpisode() async {
    if (_allEpisodesFlattened.isNotEmpty) {
      _playEpisodeByIndex(_resumeEpisodeIndex, replace: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.series['name'] ?? 'Série inconnue';
    final coverUrl = widget.series['cover'] ?? '';
    final plot = widget.series['plot']?.toString() ?? 'Aucun synopsis disponible.';
    final genre = widget.series['genre']?.toString() ?? 'Série';

    final episodesData = _parseEpisodes(seriesInfo?['episodes']);

    String resumeButtonText = "LANCER LA SÉRIE";
    if (_allEpisodesFlattened.isNotEmpty && _resumeEpisodeIndex < _allEpisodesFlattened.length) {
      final currentEp = _allEpisodesFlattened[_resumeEpisodeIndex];
      final sNum = currentEp['season_num'] ?? '1';
      final eNum = currentEp['episode_num'] ?? '1';
      final epId = _getEpId(currentEp);
      final progress = _episodesProgress[epId] ?? 0.0;

      if (progress > 0.001 && progress < 0.95) {
        resumeButtonText = "REPRENDRE S${sNum}E$eNum";
      } else {
        resumeButtonText = "CONTINUER (S${sNum}E$eNum)";
      }
    }

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
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD500F9)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    width: 220,
                                    height: 330,
                                    child: _isValidImageUrl(coverUrl)
                                        ? CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(color: Colors.white10),
                                            errorWidget: (context, url, error) => Container(
                                              color: Colors.white10,
                                              child: const Icon(Icons.tv, color: Colors.white38, size: 60),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.white10,
                                            child: const Icon(Icons.tv, color: Colors.white38, size: 60),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Genre : $genre',
                                        style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFD500F9),
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                            label: Text(
                                              resumeButtonText,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onPressed: _playResumeEpisode,
                                          ),
                                          const SizedBox(width: 16),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: isFavorite ? Colors.redAccent : Colors.white24,
                                                width: 1.5,
                                              ),
                                              backgroundColor: isFavorite ? Colors.redAccent.withOpacity(0.15) : Colors.transparent,
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                            const SizedBox(height: 40),
                            const Text(
                              'Épisodes',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ...episodesData.entries.map((seasonEntry) {
                              final seasonNumber = seasonEntry.key;
                              final episodesList = _normalizeEpisodesList(seasonEntry.value);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: GlassCard(
                                  borderColor: const Color(0xFFD500F9),
                                  borderRadius: 12,
                                  opacity: 0.08,
                                  child: ExpansionTile(
                                    iconColor: const Color(0xFFD500F9),
                                    collapsedIconColor: Colors.white54,
                                    title: Text(
                                      'Saison $seasonNumber (${episodesList.length} épisodes)',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    children: episodesList.map((ep) {
                                      final epMap = ep is Map ? Map<String, dynamic>.from(ep) : <String, dynamic>{};
                                      final epId = _getEpId(epMap);
                                      final epNum = (epMap['episode_num'] ?? '1').toString();
                                      final epTitle = epMap['title'] ?? 'Épisode $epNum';

                                      final globalIndex = _allEpisodesFlattened.indexWhere(
                                        (e) => _getEpId(e) == epId && e['season_num'].toString() == seasonNumber.toString(),
                                      );

                                      final progress = _episodesProgress[epId] ?? 0.0;
                                      bool isWatched = progress >= 0.95;
                                      bool isInProgress = progress > 0.001 && progress < 0.95;

                                      return Container(
                                        decoration: BoxDecoration(
                                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                                        ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Épisode $epNum : $epTitle',
                                                  style: TextStyle(
                                                    color: isWatched ? Colors.white54 : Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              if (isWatched)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.green, width: 0.5),
                                                  ),
                                                  child: const Text(
                                                    'Vu',
                                                    style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                )
                                              else if (isInProgress)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFD500F9).withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFD500F9), width: 0.5),
                                                  ),
                                                  child: Text(
                                                    'Commencé (${(progress * 100).toInt()}%)',
                                                    style: const TextStyle(color: Color(0xFFD500F9), fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          trailing: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFD500F9),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            ),
                                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                            label: const Text('LANCER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                            onPressed: () {
                                              if (globalIndex != -1) {
                                                _playEpisodeByIndex(globalIndex, replace: false);
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            }),
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