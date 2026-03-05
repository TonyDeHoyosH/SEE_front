import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/capsule.dart';
import '../../providers/data_provider.dart';
import '../../services/base_api_service.dart';
import '../../services/local_database_service.dart';

class EditCapsuleScreen extends StatefulWidget {
  final Capsule capsule;

  const EditCapsuleScreen({super.key, required this.capsule});

  @override
  State<EditCapsuleScreen> createState() => _EditCapsuleScreenState();
}

class _EditCapsuleScreenState extends State<EditCapsuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  late List<int> _selectedEmotionIds;
  bool _isLoading = false;

  // Text
  int _charCount = 0;
  static const int _maxChars = 500;

  // Audio
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlayingPreview = false;
  String? _audioPath;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  bool get _isAudio => widget.capsule.type.toUpperCase() == 'AUDIO';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.capsule.title;
    _contentController.text = widget.capsule.content;
    _selectedEmotionIds = List.from(widget.capsule.emotionIds);
    _charCount = _contentController.text.length;
    _audioPath = widget.capsule.audioPath;

    _contentController.addListener(() {
      setState(() => _charCount = _contentController.text.length);
    });

    // Audio playback listeners
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted)
        setState(() => _isPlayingPreview = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _playbackDuration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _playbackPosition = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted)
        setState(() {
          _isPlayingPreview = false;
          _playbackPosition = Duration.zero;
        });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Recording ─────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Se requiere permiso de micrófono'),
          backgroundColor: Color(0xFFEF4444),
        ));
      }
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/capsule_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
          encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: path,
    );
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });
    _tickRecording();
  }

  void _tickRecording() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
        _tickRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      if (path != null) _audioPath = path;
    });
  }

  Future<void> _togglePreview() async {
    if (_audioPath == null) return;
    if (_isPlayingPreview) {
      await _audioPlayer.pause();
    } else {
      if (_audioPath!.startsWith('http')) {
        await _audioPlayer.play(UrlSource(_audioPath!));
      } else {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmotionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona al menos una emoción'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final title = _titleController.text.trim();

      // Detectar si el usuario re-grabó (nuevo archivo diferente al original)
      final originalAudioPath = widget.capsule.audioPath;
      final isNewRecording = _isAudio &&
          _audioPath != null &&
          _audioPath != originalAudioPath &&
          !(_audioPath!.startsWith('http'));

      await context.read<CoreApiService>().updateCapsule(
            widget.capsule.id,
            title: title,
            contentText: _isAudio ? null : _contentController.text.trim(),
            emotionIds: _selectedEmotionIds,
            audioFile: isNewRecording ? File(_audioPath!) : null,
          );

      await LocalDatabaseService.updateCapsule({
        'id': widget.capsule.id,
        'title': title,
        'content': _isAudio ? '' : _contentController.text.trim(),
        'type': widget.capsule.type,
        'audio_path': _audioPath,
        'emotion_ids': _selectedEmotionIds.join(','),
        'is_active': widget.capsule.isActive ? 1 : 0,
        'is_synced': 0,
        'created_at': widget.capsule.createdAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cápsula actualizada'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 2),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final emotions = context.watch<DataProvider>().emotions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Cápsula'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Guardar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────────────────────────
              TextFormField(
                controller: _titleController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El título es obligatorio'
                    : null,
              ),
              const SizedBox(height: 24),

              // ── Content area ───────────────────────────────────────────────
              if (_isAudio) ...[
                _buildAudioEditor(),
              ] else ...[
                _buildTextEditor(),
              ],

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // ── Emotions ───────────────────────────────────────────────────
              Text(
                '¿Para qué emoción es?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Esta cápsula se mostrará cuando sientas esto',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
              ),
              const SizedBox(height: 16),
              if (emotions.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: emotions.map((emotion) {
                    final selected = _selectedEmotionIds.contains(emotion.id);
                    return FilterChip(
                      label: Text(emotion.name),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedEmotionIds.add(emotion.id);
                          } else {
                            _selectedEmotionIds.remove(emotion.id);
                          }
                        });
                      },
                      selectedColor:
                          const Color(0xFF5EEAD4).withValues(alpha: 0.25),
                      checkmarkColor: const Color(0xFF0F9B8E),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF0F9B8E)
                            : const Color(0xFF475569),
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 32),

              // ── Save button ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child:
                        Text(_isLoading ? 'Guardando...' : 'Guardar cambios'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Text editor ────────────────────────────────────────────────────────────

  Widget _buildTextEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contenido',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _contentController,
          minLines: 5,
          maxLines: 12,
          maxLength: _maxChars,
          decoration: const InputDecoration(
            hintText: 'Escribe tu mensaje personal...',
            alignLabelWithHint: true,
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'El contenido es obligatorio'
              : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$_charCount / $_maxChars',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _charCount > _maxChars * 0.9
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF94A3B8),
                ),
          ),
        ),
      ],
    );
  }

  // ─── Audio editor ────────────────────────────────────────────────────────────

  Widget _buildAudioEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grabación de voz',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),

        // Player / preview (if audio exists)
        if (_audioPath != null && !_isRecording) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF5EEAD4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlayingPreview
                            ? Icons.pause_circle
                            : Icons.play_circle,
                        size: 40,
                        color: const Color(0xFF5EEAD4),
                      ),
                      onPressed: _togglePreview,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _playbackPosition.inSeconds
                                  .toDouble()
                                  .clamp(0,
                                      _playbackDuration.inSeconds.toDouble()),
                              max: _playbackDuration.inSeconds
                                  .toDouble()
                                  .clamp(1, double.infinity),
                              onChanged: (v) => _audioPlayer
                                  .seek(Duration(seconds: v.toInt())),
                              activeColor: const Color(0xFF5EEAD4),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_fmt(_playbackPosition),
                                    style: const TextStyle(fontSize: 12)),
                                Text(_fmt(_playbackDuration),
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Record button
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF5EEAD4),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF5EEAD4))
                            .withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRecording
                    ? 'Grabando… ${_fmt(_recordingDuration)} — Toca para detener'
                    : (_audioPath != null
                        ? 'Toca para grabar de nuevo'
                        : 'Toca para grabar'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
