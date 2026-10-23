import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'shared_prefs_helper.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final String vodId;
  final bool initialFullScreen;
  final void Function(bool isFullScreen)? onEnded;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    required this.vodId,
    this.initialFullScreen = false,
    this.onEnded,
    this.onPrevious,
    this.onNext,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WindowListener {
  late final Player _player;
  late final VideoController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isFullScreen = false;
  bool _isPiP = false;
  Timer? _hideControlsTimer;
  bool _endedTriggered = false;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    
    _isFullScreen = widget.initialFullScreen;
    if (_isFullScreen) {
      _enterFullScreen();
    } else {
      _exitFullScreen();
    }

    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 256 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);

    _player.setVolume(50.0);

    _initPlayer();
    _startHideTimer();

    _player.stream.completed.listen((isCompleted) async {
      if (isCompleted && widget.onEnded != null && !_endedTriggered) {
        _endedTriggered = true;
        await SharedPrefsHelper.saveVodProgress(widget.vodId, 1.0);
        
        bool realFullScreen = false;
        try {
          realFullScreen = await windowManager.isFullScreen();
        } catch (_) {
          realFullScreen = _isFullScreen;
        }
        widget.onEnded!(realFullScreen);
      }
    });
  }

  @override
  void onWindowBlur() async {
    super.onWindowBlur();
    final bool autoPauseEnabled = await SharedPrefsHelper.getAutoPauseOnFocusLoss();
    if (autoPauseEnabled && _player.state.playing) {
      _player.pause();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      _onUserActivity();
      
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isPiP) _togglePiP();
        Navigator.pop(context);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        _player.playOrPause();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        _toggleFullScreen();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        final newPos = _player.state.position + const Duration(seconds: 10);
        _player.seek(newPos);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        final newPos = _player.state.position - const Duration(seconds: 10);
        _player.seek(newPos);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final currentVol = _player.state.volume;
        _player.setVolume((currentVol + 5.0).clamp(0.0, 100.0));
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final currentVol = _player.state.volume;
        _player.setVolume((currentVol - 5.0).clamp(0.0, 100.0));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _enterFullScreen() async {
    try {
      if (_isPiP) await _togglePiP();
      await windowManager.setFullScreen(true);
      if (mounted) setState(() => _isFullScreen = true);
    } catch (_) {}
  }

  Future<void> _exitFullScreen() async {
    try {
      await windowManager.setFullScreen(false);
      if (mounted) setState(() => _isFullScreen = false);
    } catch (_) {}
  }

  Future<void> _togglePiP() async {
    try {
      setState(() {
        _isPiP = !_isPiP;
      });

      if (_isPiP) {
        if (await windowManager.isFullScreen()) {
          await windowManager.setFullScreen(false);
          setState(() => _isFullScreen = false);
        }
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setResizable(true);
        await windowManager.setSize(const Size(480, 270));
      } else {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setSize(const Size(1280, 720));
        await windowManager.center();
      }
    } catch (_) {}
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _player.state.playing) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onUserActivity() {
    setState(() {
      _showControls = true;
    });
    _startHideTimer();
  }

  Future<void> _toggleFullScreen() async {
    try {
      final isFull = await windowManager.isFullScreen();
      if (isFull) {
        await _exitFullScreen();
      } else {
        await _enterFullScreen();
      }
    } catch (_) {
      setState(() => _isFullScreen = !_isFullScreen);
    }
  }

  Future<void> _initPlayer() async {
    final bool isLive = widget.streamUrl.contains('.ts') || widget.streamUrl.contains('.m3u8') || widget.streamUrl.contains('/live/');
    final savedProgress = isLive ? 0.0 : await SharedPrefsHelper.getVodProgress(widget.vodId);

    // Ajout systématique du User-Agent VLC pour éviter les rejets IPTV VOD/Séries
    final media = Media(
      widget.streamUrl,
      httpHeaders: {
        'User-Agent': 'VLC/3.0.18 LibVLC/3.0.18',
      },
    );

    await _player.open(media);

    if (isLive) {
      await _player.setRate(1.0);
    } else {
      if (savedProgress > 0.0 && savedProgress < 0.99) {
        _player.stream.duration.listen((duration) {
          if (duration.inMilliseconds > 0 && !_isInitialized) {
            _isInitialized = true;
            final targetPosition = Duration(
              milliseconds: (duration.inMilliseconds * savedProgress).toInt(),
            );
            _player.seek(targetPosition);
          }
        });
      }

      _player.stream.position.listen((position) {
        final duration = _player.state.duration;
        if (duration.inMilliseconds > 0) {
          final progress = position.inMilliseconds / duration.inMilliseconds;
          if (progress > 0.01 && progress < 0.99) {
            SharedPrefsHelper.saveVodProgress(widget.vodId, progress);
          } else if (progress >= 0.99) {
            SharedPrefsHelper.saveVodProgress(widget.vodId, 1.0);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _hideControlsTimer?.cancel();
    windowManager.removeListener(this);
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _getAudioLabel(AudioTrack track, int index) {
    final title = (track.title ?? '').trim().toUpperCase();
    final lang = (track.language ?? '').trim().toLowerCase();
    String label = '';

    final bool isAudioDescription = title.contains('AD') || 
        title.contains('AUDIO DESCRIPTION') || 
        title.contains('AUDIODESCRIPTION') || 
        title.contains('VISUALLY IMPAIRED');

    final bool isQuebec = title.contains('VQ') || title.contains('VFQ');

    if (isAudioDescription) {
      label = 'Français (Audio Description)';
    } else if (isQuebec) {
      label = 'Français (VQ)';
    } else if (title.contains('VFF') || title.contains('VF') || title.contains('VFI')) {
      label = 'Français (VFF)';
    } else if (title.contains('ENGLISH') || lang.contains('en') || lang.contains('eng')) {
      label = 'Anglais (VO)';
    } else if (lang.contains('fr') || lang.contains('fre')) {
      label = 'Français';
    } else if (title.isNotEmpty) {
      label = title;
    } else {
      label = 'Piste audio ${index + 1}';
    }

    if (title.contains('5.1')) {
      label += ' (5.1)';
    } else if (title.contains('2.0') || title.contains('STEREO')) {
      label += ' (2.0)';
    }

    return label;
  }

  String _getSubtitleLabel(SubtitleTrack track, int index) {
    if (track.id == 'no') return 'Désactivés';
    if (track.id == 'auto') return 'Automatique';

    final title = (track.title ?? '').trim().toUpperCase();
    final lang = (track.language ?? '').trim().toLowerCase();
    String label = '';

    if (title.contains('FORCED') || title.contains('FORCE')) {
      label = 'Français (Forcé)';
    } else if (title.contains('FRENCH') || lang.contains('fr') || lang.contains('fre')) {
      label = 'Français';
    } else if (title.contains('ENGLISH') || lang.contains('en') || lang.contains('eng')) {
      label = 'Anglais';
    } else if (title.isNotEmpty) {
      label = title;
    } else {
      label = 'Sous-titre ${index + 1}';
    }

    if (title.contains('SDH') || title.contains('HI') || title.contains('MALENTENDANTS')) {
      label += ' (Malentendants)';
    }

    return label;
  }

  void _showAudioTracksDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0C101C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: const Text('Sélectionner l\'audio', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 320,
          child: StreamBuilder<Tracks>(
            stream: _player.stream.tracks,
            builder: (context, snapshot) {
              final currentTrack = _player.state.track.audio;
              final rawTracks = _player.state.tracks.audio
                  .where((t) => t.id != 'auto' && t.id != 'no')
                  .toList();

              if (rawTracks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Aucune piste audio disponible', style: TextStyle(color: Colors.white70)),
                );
              }

              final Map<String, int> labelCounts = {};
              final List<MapEntry<AudioTrack, String>> items = [];

              for (int i = 0; i < rawTracks.length; i++) {
                final track = rawTracks[i];
                String baseLabel = _getAudioLabel(track, i);
                
                labelCounts[baseLabel] = (labelCounts[baseLabel] ?? 0) + 1;
                int count = labelCounts[baseLabel]!;
                
                String finalLabel = count > 1 ? '$baseLabel #$count' : baseLabel;
                items.add(MapEntry(track, finalLabel));
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final track = items[index].key;
                  final label = items[index].value;
                  final isSelected = track == currentTrack;

                  return ListTile(
                    title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF00E5FF) : Colors.white)),
                    trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF00E5FF)) : null,
                    onTap: () {
                      _player.setAudioTrack(track);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSubtitleTracksDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0C101C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: const Text('Sélectionner les sous-titres', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 320,
          child: StreamBuilder<Tracks>(
            stream: _player.stream.tracks,
            builder: (context, snapshot) {
              final currentTrack = _player.state.track.subtitle;
              final rawTracks = _player.state.tracks.subtitle
                  .where((t) => t.id != 'auto' && t.id != 'no')
                  .toList();

              final Map<String, int> labelCounts = {};
              final List<MapEntry<SubtitleTrack, String>> items = [];

              for (int i = 0; i < rawTracks.length; i++) {
                final track = rawTracks[i];
                String baseLabel = _getSubtitleLabel(track, i);

                labelCounts[baseLabel] = (labelCounts[baseLabel] ?? 0) + 1;
                int count = labelCounts[baseLabel]!;

                String finalLabel = count > 1 ? '$baseLabel #$count' : baseLabel;
                items.add(MapEntry(track, finalLabel));
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final bool isNoSub = currentTrack == SubtitleTrack.no() || currentTrack.id == 'no';
                    return ListTile(
                      title: Text('Désactivés', style: TextStyle(color: isNoSub ? const Color(0xFF00E5FF) : Colors.white)),
                      trailing: isNoSub ? const Icon(Icons.check, color: Color(0xFF00E5FF)) : null,
                      onTap: () {
                        _player.setSubtitleTrack(SubtitleTrack.no());
                        Navigator.pop(context);
                      },
                    );
                  }

                  final track = items[index - 1].key;
                  final label = items[index - 1].value;
                  final isSelected = track == currentTrack;

                  return ListTile(
                    title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF00E5FF) : Colors.white)),
                    trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF00E5FF)) : null,
                    onTap: () {
                      _player.setSubtitleTrack(track);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLive = widget.streamUrl.contains('.ts') || widget.streamUrl.contains('.m3u8') || widget.streamUrl.contains('/live/');
    final bool isSeries = widget.onNext != null || widget.onPrevious != null;

    FocusScope.of(context).requestFocus(_focusNode);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        onKey: _handleKeyEvent,
        child: MouseRegion(
          onHover: (_) => _onUserActivity(),
          child: GestureDetector(
            onTap: () {
              setState(() => _showControls = !_showControls);
              if (_showControls) _startHideTimer();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                if (_showControls)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Barre supérieure
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                                    onPressed: () async {
                                      if (_isPiP) await _togglePiP();
                                      if (context.mounted) Navigator.pop(context);
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        shadows: [Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 2))],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!isLive) ...[
                                    IconButton(
                                      icon: const Icon(Icons.audiotrack, color: Colors.white),
                                      tooltip: 'Changer de piste audio',
                                      onPressed: _showAudioTracksDialog,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.subtitles, color: Colors.white),
                                      tooltip: 'Sous-titres',
                                      onPressed: _showSubtitleTracksDialog,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Boutons centraux de lecture
                            if (!isLive)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSeries) ...[
                                    IconButton(
                                      iconSize: 36,
                                      color: widget.onPrevious != null ? Colors.white : Colors.white24,
                                      icon: const Icon(Icons.skip_previous_rounded),
                                      tooltip: 'Épisode précédent',
                                      onPressed: widget.onPrevious,
                                    ),
                                    const SizedBox(width: 16),
                                  ],
                                  IconButton(
                                    iconSize: 40,
                                    color: Colors.white,
                                    icon: const Icon(Icons.replay_10),
                                    tooltip: 'Reculer de 10s',
                                    onPressed: () {
                                      final newPos = _player.state.position - const Duration(seconds: 10);
                                      _player.seek(newPos);
                                    },
                                  ),
                                  const SizedBox(width: 30),
                                  StreamBuilder<bool>(
                                    stream: _player.stream.playing,
                                    builder: (context, snapshot) {
                                      final isPlaying = snapshot.data ?? true;
                                      return IconButton(
                                        iconSize: 64,
                                        color: const Color(0xFF00E5FF),
                                        icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                                        onPressed: () => _player.playOrPause(),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 30),
                                  IconButton(
                                    iconSize: 40,
                                    color: Colors.white,
                                    icon: const Icon(Icons.forward_10),
                                    tooltip: 'Avancer de 10s',
                                    onPressed: () {
                                      final newPos = _player.state.position + const Duration(seconds: 10);
                                      _player.seek(newPos);
                                    },
                                  ),
                                  if (isSeries) ...[
                                    const SizedBox(width: 16),
                                    IconButton(
                                      iconSize: 36,
                                      color: widget.onNext != null ? Colors.white : Colors.white24,
                                      icon: const Icon(Icons.skip_next_rounded),
                                      tooltip: 'Épisode suivant',
                                      onPressed: widget.onNext,
                                    ),
                                  ],
                                ],
                              )
                            else
                              const SizedBox.shrink(),

                            // Barre inférieure de progression & volume
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF090E18).withOpacity(0.85),
                                border: const Border(top: BorderSide(color: Color(0xFF00E5FF), width: 0.5)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isLive)
                                    StreamBuilder<Duration>(
                                      stream: _player.stream.position,
                                      builder: (context, snapshot) {
                                        final position = snapshot.data ?? Duration.zero;
                                        final duration = _player.state.duration;
                                        final double val = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;

                                        return Row(
                                          children: [
                                            Text(_formatDuration(position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: SliderTheme(
                                                data: SliderTheme.of(context).copyWith(
                                                  activeTrackColor: const Color(0xFF00E5FF),
                                                  inactiveTrackColor: Colors.white24,
                                                  thumbColor: Colors.white,
                                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                                ),
                                                child: Slider(
                                                  value: val.clamp(0.0, 1.0),
                                                  onChanged: (value) {
                                                    final target = Duration(milliseconds: (value * duration.inMilliseconds).toInt());
                                                    _player.seek(target);
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(_formatDuration(duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                          ],
                                        );
                                      },
                                    ),
                                  if (!isLive) const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              _isPiP ? Icons.picture_in_picture_alt : Icons.picture_in_picture,
                                              color: _isPiP ? const Color(0xFF00E5FF) : Colors.white,
                                            ),
                                            tooltip: _isPiP ? 'Quitter le mode PiP' : 'Mode PiP (Fenêtre flottante)',
                                            onPressed: _togglePiP,
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.volume_up, color: Colors.white, size: 22),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 100,
                                            child: StreamBuilder<double>(
                                              stream: _player.stream.volume,
                                              builder: (context, snapshot) {
                                                final volume = snapshot.data ?? 50.0;
                                                return Slider(
                                                  value: volume,
                                                  min: 0.0,
                                                  max: 100.0,
                                                  activeColor: const Color(0xFF00E5FF),
                                                  inactiveColor: Colors.white24,
                                                  onChanged: (val) => _player.setVolume(val),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isLive)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 16),
                                              child: Text(
                                                'DIRECT',
                                                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: _toggleFullScreen,
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Icon(
                                                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}