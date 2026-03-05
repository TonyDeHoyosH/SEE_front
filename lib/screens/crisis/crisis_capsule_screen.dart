import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/crisis_provider.dart';
import '../../widgets/glass_card.dart';
import '../../config/theme.dart';
import 'breathing_screen.dart';

class CrisisCapsuleScreen extends StatefulWidget {
  const CrisisCapsuleScreen({super.key});

  @override
  State<CrisisCapsuleScreen> createState() => _CrisisCapsuleScreenState();
}

class _CrisisCapsuleScreenState extends State<CrisisCapsuleScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
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
    _audioPlayer.eventStream.listen(
      null,
      onError: (_, __) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo reproducir el audio'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String path) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }
    if (!path.startsWith('http://') && !path.startsWith('https://')) {
      if (File(path).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(path));
      }
    } else {
      await _audioPlayer.play(UrlSource(path));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final crisisProvider = context.watch<CrisisProvider>();
    final capsule = crisisProvider.recommendedCapsule;
    final isAudio = capsule?.type.toUpperCase() == 'AUDIO';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cápsula para ti'),
            Text(
              'Paso 2 de 4',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: capsule == null
          ? const Center(child: Text('No hay cápsula disponible'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isAudio ? Icons.mic : Icons.lightbulb,
                    size: 64,
                    color: isAudio
                        ? const Color(0xFFFB923C)
                        : const Color(0xFF5EEAD4),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    capsule.title,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),

                  // ── Contenido según tipo ───────────────────────────────
                  if (isAudio && capsule.audioPath != null)
                    _buildAudioPlayer(capsule.audioPath!)
                  else if (isAudio && capsule.audioPath == null)
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: const Row(
                        children: [
                          Icon(Icons.volume_off, color: Color(0xFF94A3B8)),
                          SizedBox(width: 8),
                          Text(
                            'Audio no disponible',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    )
                  else
                    GlassCard(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        capsule.content,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                      ),
                    ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _audioPlayer.stop();
                        final crisisId =
                            context.read<CrisisProvider>().currentCrisis?.id;
                        if (crisisId != null) {
                          await context
                              .read<CrisisProvider>()
                              .markCapsuleUsed(crisisId, capsule.id);
                        }
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BreathingScreen(),
                            ),
                          );
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Text('Continuar'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAudioPlayer(String path) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _togglePlay(path),
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
          const SizedBox(height: 12),
          Slider(
            value: _position.inMilliseconds.toDouble(),
            max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
            activeColor: const Color(0xFF5EEAD4),
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (v) =>
                _audioPlayer.seek(Duration(milliseconds: v.toInt())),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(_position),
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              Text(
                _fmt(_duration),
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
