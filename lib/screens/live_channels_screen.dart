import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'favorites_screen.dart';
import 'in_progress_screen.dart';
import 'shared_prefs_helper.dart';
import 'glass_card.dart';

// Fonction de parsing M3U exécutée en arrière-plan (Isolate) pour les listes massives
Map<String, dynamic> _parseM3uInBackground(String content) {
  final lines = content.split('\n');
  List<Map<String, dynamic>> channels = [];
  Map<String, String> categoryMap = {};

  String currentName = 'Chaîne IPTV';
  String currentLogo = '';
  String currentGroup = 'Général';
  int streamId = 1;

  for (var line in lines) {
    line = line.trim();
    if (line.startsWith('#EXTINF:')) {
      currentName = 'Chaîne';
      currentLogo = '';
      currentGroup = 'Général';

      final commaIndex = line.lastIndexOf(',');
      if (commaIndex != -1 && commaIndex < line.length - 1) {
        currentName = line.substring(commaIndex + 1).trim();
      }

      final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
      if (logoMatch != null) {
        currentLogo = logoMatch.group(1) ?? '';
      }

      final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
      if (groupMatch != null) {
        currentGroup = groupMatch.group(1) ?? 'Général';
      }
    } else if (line.isNotEmpty && !line.startsWith('#')) {
      categoryMap[currentGroup] = currentGroup;
      channels.add({
        'stream_id': streamId++,
        'name': currentName,
        'stream_icon': currentLogo,
        'category_id': currentGroup,
        'category_name': currentGroup,
        'stream_url': line,
      });
    }
  }

  List<Map<String, dynamic>> parsedCats = [
    {'category_id': 'all', 'category_name': 'Toutes les chaînes'}
  ];
  
  categoryMap.keys.forEach((cat) {
    parsedCats.add({'category_id': cat, 'category_name': cat});
  });

  return {
    'categories': parsedCats,
    'channels': channels,
  };
}

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
  List categories = [];
  List allChannels = [];
  List filteredChannels = [];
  List epgList = [];
  String selectedCategoryId = 'all';
  String searchQuery = '';
  bool isLoading = true;
  bool isLoadingEpg = false;
  bool _isPlayerMaximized = false;

  double _currentVolume = 50.0;
  bool _isMuted = false;
  double _previousVolume = 50.0;
  
  bool _showOverlayControls = true;
  Timer? _hideTimer;
  Timer? _streamTimeoutTimer; // Minuteur de sécurité anti-blocage muet

  Map? selectedChannel;
  late final Player _player;
  late final VideoController _controller;

  int _retryCount = 0;
  static const int _maxRetries = 3;
  StreamSubscription? _errorSubscription;

  // Message d'erreur pro à afficher sur le lecteur en cas d'échec de flux
  String? streamErrorMessage;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.setVolume(_currentVolume);

    _errorSubscription = _player.stream.error.listen((error) {
      debugPrint("Erreur détectée sur le flux live : $error");
      if (selectedChannel != null) {
        _handleStreamFailure(selectedChannel!);
      }
    });

    _loadContent();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _streamTimeoutTimer?.cancel();
    _errorSubscription?.cancel();
    _player.stop();
    _player.dispose();
    windowManager.unmaximize();
    windowManager.setTitleBarStyle(TitleBarStyle.normal);
    super.dispose();
  }

  Future<void> _toggleMaximize(bool maximize) async {
    setState(() {
      _isPlayerMaximized = maximize;
      _showOverlayControls = true;
    });
    try {
      if (maximize) {
        await windowManager.maximize();
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        _startHideTimer();
      } else {
        await windowManager.unmaximize();
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
        _hideTimer?.cancel();
      }
    } catch (_) {}
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlayerMaximized) {
        setState(() {
          _showOverlayControls = false;
        });
      }
    });
  }

  void _onMouseMoved() {
    if (_isPlayerMaximized) {
      setState(() {
        _showOverlayControls = true;
      });
      _startHideTimer();
    }
  }

  void _setVolume(double volume) {
    setState(() {
      _currentVolume = volume;
      _isMuted = volume == 0;
    });
    _player.setVolume(volume);
  }

  void _toggleMute() {
    setState(() {
      if (_isMuted) {
        _isMuted = false;
        _currentVolume = _previousVolume > 0 ? _previousVolume : 50.0;
      } else {
        _previousVolume = _currentVolume;
        _isMuted = true;
        _currentVolume = 0.0;
      }
    });
    _player.setVolume(_currentVolume);
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url == 'https://image.tmdb.org/t/p/w600_and_h900_bestv2' || url.endsWith('/p/w600_and_h900_bestv2')) {
      return false;
    }
    return true;
  }

  Future<void> _loadContent() async {
    try {
      final isLocalFile = !widget.serverUrl.startsWith('http://') && !widget.serverUrl.startsWith('https://');
      final isM3uLink = widget.serverUrl.contains('.m3u') || widget.serverUrl.contains('.m3u8');

      if (isLocalFile || isM3uLink) {
        String content = '';
        if (isLocalFile) {
          final file = File(widget.serverUrl);
          if (await file.exists()) {
            content = await file.readAsString();
          }
        } else {
          final res = await http.get(Uri.parse(widget.serverUrl));
          if (res.statusCode == 200) {
            content = res.body;
          }
        }

        if (content.isNotEmpty) {
          final parsedData = await compute(_parseM3uInBackground, content);
          
          if (mounted) {
            setState(() {
              categories = parsedData['categories'];
              allChannels = parsedData['channels'];
              filteredChannels = parsedData['channels'];
              isLoading = false;
              if (allChannels.isNotEmpty) {
                _selectChannel(allChannels.first);
              }
            });
          }
          return;
        }
      }

      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;

      final catUrl = Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_live_categories');
      final channelsUrl = Uri.parse('$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_live_streams');

      final catRes = await http.get(catUrl);
      final channelsRes = await http.get(channelsUrl);

      List parsedCats = [
        {'category_id': 'all', 'category_name': 'Toutes les chaînes'}
      ];

      if (catRes.statusCode == 200) {
        final catData = json.decode(catRes.body);
        if (catData is List) parsedCats.addAll(catData);
      }

      if (channelsRes.statusCode == 200) {
        final channelsData = json.decode(channelsRes.body);
        if (channelsData is List) {
          setState(() {
            categories = parsedCats;
            allChannels = channelsData;
            filteredChannels = channelsData;
            isLoading = false;
            if (channelsData.isNotEmpty) {
              _selectChannel(channelsData.first);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur de chargement des chaînes : $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchEPG(String streamId) async {
    if (widget.serverUrl.contains('.m3u') || !widget.serverUrl.contains('player_api')) {
      setState(() => isLoadingEpg = false);
      return;
    }

    final cachedEpg = await SharedPrefsHelper.getCachedEpg(streamId);
    if (cachedEpg != null && cachedEpg.isNotEmpty) {
      if (mounted) {
        setState(() {
          epgList = cachedEpg;
          isLoadingEpg = false;
        });
      }
    } else {
      setState(() {
        isLoadingEpg = true;
        epgList = [];
      });
    }

    try {
      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;

      final url = Uri.parse(
        '$baseUrl/player_api.php?username=${widget.username}&password=${widget.password}&action=get_short_epg&stream_id=$streamId',
      );

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['epg_listings'] != null && data['epg_listings'] is List) {
          final listings = data['epg_listings'] as List;
          await SharedPrefsHelper.saveCachedEpg(streamId, listings);

          if (mounted) {
            setState(() {
              epgList = listings;
              isLoadingEpg = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        isLoadingEpg = false;
      });
    }
  }

  void _selectChannel(Map item) {
    setState(() {
      selectedChannel = item;
      _retryCount = 0;
    });
    
    _openStreamWithAutoRecovery(item);
    _fetchEPG(item['stream_id'].toString());
  }

  void _openStreamWithAutoRecovery(Map item) {
    setState(() {
      streamErrorMessage = null; // Réinitialise l'erreur lors du changement de chaîne
    });

    // Annule le timer précédent pour éviter les conflits
    _streamTimeoutTimer?.cancel();

    String streamUrl = '';

    if (item.containsKey('stream_url')) {
      streamUrl = item['stream_url'];
    } else {
      final String baseUrl = widget.serverUrl.endsWith('/')
          ? widget.serverUrl.substring(0, widget.serverUrl.length - 1)
          : widget.serverUrl;
      final streamId = item['stream_id'].toString();
      streamUrl = '$baseUrl/live/${widget.username}/${widget.password}/$streamId.ts';
    }

    debugPrint("Ouverture du flux : $streamUrl");

    _player.open(
      Media(
        streamUrl,
        httpHeaders: {
          'User-Agent': 'VLC/3.0.18 LibVLC/3.0.18',
        },
      ),
    );
    _player.setVolume(_currentVolume);

    // Sécurité anti-blocage muet : Si le flux ne répond pas au bout de 8 secondes, on déclenche l'échec
    _streamTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && selectedChannel?['stream_id'] == item['stream_id'] && streamErrorMessage == null) {
        debugPrint("Délai d'attente dépassé (aucun signal ni erreur renvoyée).");
        _handleStreamFailure(item);
      }
    });
  }

  void _handleStreamFailure(Map item) {
    _streamTimeoutTimer?.cancel();
    if (_retryCount < _maxRetries) {
      _retryCount++;
      debugPrint("Tentative de reconnexion automatique (${_retryCount}/$_maxRetries)...");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && selectedChannel?['stream_id'] == item['stream_id']) {
          _openStreamWithAutoRecovery(item);
        }
      });
    } else {
      if (mounted) {
        setState(() {
          streamErrorMessage = "Flux momentanément indisponible ou source externe inactive.";
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      filteredChannels = allChannels.where((item) {
        final matchesCat = selectedCategoryId == 'all' ||
            item['category_id'].toString() == selectedCategoryId;
        final matchesSearch = searchQuery.isEmpty ||
            (item['name'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase());
        return matchesCat && matchesSearch;
      }).toList();
    });
  }

  String _formatEpgTitle(String encodedTitle) {
    try {
      return utf8.decode(base64.decode(encodedTitle));
    } catch (_) {
      return encodedTitle;
    }
  }

  Widget _buildVolumeControlBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isMuted || _currentVolume == 0
                ? Icons.volume_off_rounded
                : _currentVolume < 50
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            color: const Color(0xFF00E5FF),
            size: 20,
          ),
          onPressed: _toggleMute,
          tooltip: 'Couper/Activer le son',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        SizedBox(
          width: 100,
          height: 30,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white24,
              thumbColor: const Color(0xFF00E5FF),
              overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
            ),
            child: Slider(
              value: _currentVolume,
              min: 0.0,
              max: 100.0,
              onChanged: _setVolume,
            ),
          ),
        ),
        Text(
          '${_currentVolume.toInt()}%',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildChannelsList() {
    return ListView.builder(
      itemCount: filteredChannels.length,
      itemBuilder: (context, index) {
        final item = filteredChannels[index];
        final logoUrl = item['stream_icon'] ?? '';
        final title = item['name'] ?? 'Chaîne';
        final streamId = item['stream_id'].toString();
        final isCurrent = selectedChannel?['stream_id']?.toString() == streamId;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            borderColor: isCurrent ? const Color(0xFF00E5FF) : Colors.white10,
            borderRadius: 10,
            opacity: isCurrent ? 0.25 : 0.08,
            onTap: () {
              if (isCurrent) {
                _toggleMaximize(!_isPlayerMaximized);
              } else {
                _selectChannel(item);
              }
            },
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: Platform.isAndroid ? 6 : 8),
              dense: true,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: Platform.isAndroid ? 32 : 40,
                  height: Platform.isAndroid ? 32 : 40,
                  child: _isValidImageUrl(logoUrl)
                      ? CachedNetworkImage(
                          imageUrl: logoUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(color: Colors.white10),
                          errorWidget: (context, url, error) => const Icon(Icons.tv, color: Colors.white38),
                        )
                      : const Icon(Icons.tv, color: Colors.white38),
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: Platform.isAndroid ? 12 : 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<bool>(
                    future: SharedPrefsHelper.isFavorite('fav_live', streamId),
                    builder: (context, snapshot) {
                      final isFav = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : Colors.white54,
                          size: Platform.isAndroid ? 18 : 22,
                        ),
                        onPressed: () async {
                          await SharedPrefsHelper.toggleFavorite('fav_live', item);
                          setState(() {});
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRightPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      color: _isPlayerMaximized ? Colors.black : Colors.transparent,
      padding: EdgeInsets.all(_isPlayerMaximized ? 0 : (Platform.isAndroid ? 8 : 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isPlayerMaximized)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedChannel?['name'] ?? 'Sélectionnez une chaîne',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Platform.isAndroid ? 12 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!Platform.isAndroid) _buildVolumeControlBar(),
              ],
            ),
          if (!_isPlayerMaximized) SizedBox(height: Platform.isAndroid ? 4 : 8),
          Expanded(
            child: MouseRegion(
              onHover: (_) => _onMouseMoved(),
              child: Stack(
                children: [
                  InkWell(
                    onDoubleTap: () => _toggleMaximize(!_isPlayerMaximized),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(_isPlayerMaximized ? 0 : 12),
                        boxShadow: _isPlayerMaximized
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                )
                              ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_isPlayerMaximized ? 0 : 12),
                        child: Video(
                          controller: _controller,
                          controls: NoVideoControls,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),

                  // Affichage du message d'erreur pro si le flux échoue définitivement ou freeze
                  if (streamErrorMessage != null)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.85),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3D00), size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              "Oups, impossible de lire ce flux",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              streamErrorMessage!,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Essayez de sélectionner une autre chaîne dans la liste.",
                              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_isPlayerMaximized)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: AnimatedOpacity(
                        opacity: _showOverlayControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedChannel?['name'] ?? '',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              _buildVolumeControlBar(),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!_isPlayerMaximized)
            SizedBox(
              height: Platform.isAndroid ? 100 : 226,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: Platform.isAndroid ? 6 : 16),
                  Row(
                    children: [
                      Icon(Icons.schedule, color: const Color(0xFF00E5FF), size: Platform.isAndroid ? 14 : 20),
                      const SizedBox(width: 8),
                      Text(
                        'Guide des programmes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Platform.isAndroid ? 11 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Platform.isAndroid ? 4 : 10),
                  Expanded(
                    child: isLoadingEpg && epgList.isEmpty
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                        : epgList.isEmpty
                            ? Center(
                                child: Text(
                                  'Aucun programme disponible pour cette chaîne.',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: Platform.isAndroid ? 10 : 13),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                itemCount: epgList.length,
                                itemBuilder: (context, index) {
                                  final epg = epgList[index];
                                  final title = _formatEpgTitle(epg['title'] ?? 'Programme');
                                  final start = epg['start'] ?? '';
                                  final end = epg['end'] ?? '';

                                  String timeLabel = '';
                                  if (start.length >= 16 && end.length >= 16) {
                                    final startTime = start.substring(11, 16);
                                    final endTime = end.substring(11, 16);
                                    timeLabel = '$startTime - $endTime';
                                  }

                                  final isNow = epg['has_archive'] == 1 || index == 0;

                                  return GlassCard(
                                    borderColor: isNow ? const Color(0xFF00E5FF) : Colors.white10,
                                    borderRadius: Platform.isAndroid ? 6 : 8,
                                    opacity: isNow ? 0.2 : 0.05,
                                    child: Padding(
                                      padding: EdgeInsets.all(Platform.isAndroid ? 4 : 0),
                                      child: Row(
                                        children: [
                                          if (timeLabel.isNotEmpty)
                                            Text(
                                              timeLabel,
                                              style: TextStyle(
                                                color: isNow ? const Color(0xFF00E5FF) : Colors.white60,
                                                fontWeight: FontWeight.bold,
                                                fontSize: Platform.isAndroid ? 10 : 12,
                                              ),
                                            ),
                                          if (timeLabel.isNotEmpty) SizedBox(width: Platform.isAndroid ? 8 : 12),
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                color: isNow ? Colors.white : Colors.white70,
                                                fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                                                fontSize: Platform.isAndroid ? 10 : 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isPlayerMaximized) {
            _toggleMaximize(false);
          } else {
            windowManager.unmaximize();
            windowManager.setTitleBarStyle(TitleBarStyle.normal);
            Navigator.pop(context);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                  if (!_isPlayerMaximized)
                    Container(
                      color: const Color(0xFF0C101C).withOpacity(0.8),
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
                          const _NavPill(
                            label: 'Télévision en direct',
                            isSelected: true,
                            borderColor: Color(0xFF00E5FF),
                          ),
                          const SizedBox(width: 8),
                          _NavPill(
                            label: 'Films',
                            isSelected: false,
                            borderColor: const Color(0xFFFF007F),
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
                            borderColor: const Color(0xFFD500F9),
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
                          _NavPill(
                            label: 'Favoris',
                            isSelected: false,
                            borderColor: const Color(0xFFFF3D00),
                            onTap: () {
                              windowManager.unmaximize();
                              windowManager.setTitleBarStyle(TitleBarStyle.normal);
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
                          _NavPill(
                            label: 'En cours',
                            isSelected: false,
                            borderColor: const Color(0xFF00E676),
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
                          const SizedBox(width: 20),
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Rechercher une chaîne...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF), size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFF161C2E).withOpacity(0.6),
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
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
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                        : Row(
                            children: [
                              if (!_isPlayerMaximized)
                                SizedBox(
                                  width: Platform.isAndroid ? 140 : 240,
                                  child: Container(
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
                                          selectedTileColor: const Color(0xFF00E5FF).withOpacity(0.15),
                                          title: Text(
                                            cat['category_name'],
                                            style: TextStyle(
                                              color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              fontSize: Platform.isAndroid ? 11 : 13,
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
                                ),
                              
                              if (!_isPlayerMaximized)
                                Expanded(
                                  flex: Platform.isAndroid ? 3 : 2,
                                  child: Padding(
                                    padding: EdgeInsets.all(Platform.isAndroid ? 6.0 : 12.0),
                                    child: _buildChannelsList(),
                                  ),
                                ),

                              if (!_isPlayerMaximized)
                                SizedBox(
                                  width: Platform.isAndroid ? 280 : 360,
                                  child: _buildRightPanel(),
                                )
                              else
                                Expanded(
                                  child: _buildRightPanel(),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          if (widget.onTap != null) {
            widget.onTap!();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
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