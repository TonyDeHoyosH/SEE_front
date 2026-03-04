import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/capsule.dart';
import '../../config/theme.dart';

class CapsuleDetailScreen extends StatefulWidget {
  final Capsule capsule;
  final String emotionName;

  const CapsuleDetailScreen({
    super.key,
    required this.capsule,
    required this.emotionName,
  });

  @override
  State<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

class _CapsuleDetailScreenState extends State<CapsuleDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Compare case-insensitively: backend sends 'AUDIO'/'TEXT', local DB may have 'audio'/'texto'
  bool get _isAudio => widget.capsule.type.toUpperCase() == 'AUDIO';

  @override
  void initState() {
    super.initState();

    if (_isAudio && widget.capsule.audioPath != null) {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
        }
      });

      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });

      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      final path = widget.capsule.audioPath!;
      // If it's a URL (S3), stream it directly; otherwise play local file
      if (path.startsWith('http://') || path.startsWith('https://')) {
        await _audioPlayer.play(UrlSource(path));
      } else if (File(path).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(path));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Archivo de audio no encontrado'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Format date without requiring locale initialization
  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Fecha no disponible';
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} de ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final capsule = widget.capsule;
    final dateFormatted = _formatDate(capsule.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(capsule.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: capsule.type == 'audio'
                        ? const Color(0xFFFB923C).withValues(alpha: 0.15)
                        : const Color(0xFF5EEAD4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        capsule.type == 'audio' ? Icons.mic : Icons.text_fields,
                        size: 16,
                        color: capsule.type == 'audio'
                            ? const Color(0xFFFB923C)
                            : const Color(0xFF5EEAD4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        capsule.type == 'audio' ? 'AUDIO' : 'TEXTO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: capsule.type == 'audio'
                              ? const Color(0xFFFB923C)
                              : const Color(0xFF5EEAD4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text(widget.emotionName),
                  backgroundColor:
                      const Color(0xFF5EEAD4).withValues(alpha: 0.2),
                  labelStyle: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              dateFormatted,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            if (!_isAudio && capsule.content.isNotEmpty) ...[
              Text(
                capsule.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      fontSize: 16,
                    ),
              ),
            ] else if (_isAudio) ...[
              _buildAudioPlayer(),
            ],
            if (!capsule.isSynced) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFB923C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 18,
                      color: Color(0xFFFB923C),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Guardada localmente. Se sincronizará cuando haya conexión.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFB923C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    if (widget.capsule.audioPath == null) {
      return const Center(
        child: Text(
          'Audio no disponible',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF5EEAD4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5EEAD4).withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: _position.inMilliseconds.toDouble(),
            max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
            activeColor: const Color(0xFF5EEAD4),
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (value) {
              _audioPlayer.seek(Duration(milliseconds: value.toInt()));
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
