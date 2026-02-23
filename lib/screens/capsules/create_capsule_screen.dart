import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/core_api_service.dart';
import '../../services/local_database_service.dart';

class CreateCapsuleScreen extends StatefulWidget {
  const CreateCapsuleScreen({super.key});

  @override
  State<CreateCapsuleScreen> createState() => _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends State<CreateCapsuleScreen> {
  final _contentFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  int _currentStep = 0;
  String _capsuleType = 'texto';
  int? _selectedEmotionId;
  bool _isLoading = false;
  int _charCount = 0;

  // Audio
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  Duration _recordingDuration = Duration.zero;

  static const int _maxChars = 500;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(() {
      setState(() {
        _charCount = _contentController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_selectedEmotionId == null) return;

    setState(() => _isLoading = true);

    try {
      final title = _titleController.text.trim().isEmpty
          ? 'Sin título'
          : _titleController.text.trim();

      if (_capsuleType == 'texto') {
        await HttpCoreApiService().createCapsule(
          title: title,
          content: _contentController.text.trim(),
          emotionId: _selectedEmotionId!,
        );
      }

      final capsuleId = 'cap-${DateTime.now().millisecondsSinceEpoch}';
      await LocalDatabaseService.insertCapsule({
        'id': capsuleId,
        'title': title,
        'content':
            _capsuleType == 'texto' ? _contentController.text.trim() : '',
        'emotion_id': _selectedEmotionId!,
        'is_active': 1,
        'type': _capsuleType,
        'audio_path': _audioPath,
        'is_synced': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cápsula creada exitosamente'),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear cápsula: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<bool> _showTermsDialog() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Términos y Condiciones'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Grabación de Audio en AWOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Al utilizar la función de grabación de audio, aceptas lo siguiente:',
              ),
              SizedBox(height: 8),
              Text(
                '1. El audio se almacena localmente en tu dispositivo.\n'
                '2. Solo tú tienes acceso a estas grabaciones.\n'
                '3. Las grabaciones son para tu uso personal y, si lo deseas, para compartir con tu terapeuta.\n'
                '4. Puedes eliminar tus grabaciones en cualquier momento.\n'
                '5. AWOS no comparte ni analiza el contenido de tus grabaciones.',
              ),
              SizedBox(height: 12),
              Text(
                'Tu privacidad es nuestra prioridad.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Acepto'),
          ),
        ],
      ),
    );
    return accepted ?? false;
  }

  Future<void> _handleAudioSelected() async {
    final accepted = await _showTermsDialog();
    if (!accepted) return;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se requiere permiso de micrófono para grabar audio'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    setState(() {
      _capsuleType = 'audio';
      _currentStep = 1;
    });
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'capsule_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${dir.path}/$fileName';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _updateRecordingDuration();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar grabación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateRecordingDuration() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
        _updateRecordingDuration();
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final emotions = dataProvider.emotions;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nueva Cápsula'),
              if (_currentStep > 0)
                Text(
                  _capsuleType == 'texto'
                      ? 'Paso ${_currentStep + 1} de 3'
                      : 'Paso ${_currentStep + 1} de 3',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
        body: _currentStep == 0
            ? _buildStep1()
            : _currentStep == 1
                ? (_capsuleType == 'texto'
                    ? _buildTextStep2()
                    : _buildAudioStep2())
                : _buildStep3(emotions),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, size: 64, color: Color(0xFF5EEAD4)),
          const SizedBox(height: 24),
          Text(
            '¿Qué tipo de cápsula quieres crear?',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Elige el formato de tu mensaje personal',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  icon: Icons.text_fields,
                  label: 'TEXTO',
                  subtitle: 'Escribe un mensaje',
                  color: const Color(0xFF5EEAD4),
                  onTap: () {
                    setState(() {
                      _capsuleType = 'texto';
                      _currentStep = 1;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TypeButton(
                  icon: Icons.mic,
                  label: 'AUDIO',
                  subtitle: 'Graba un mensaje',
                  color: const Color(0xFFFB923C),
                  onTap: _handleAudioSelected,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _contentFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escribe tu cápsula',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu mensaje personal para momentos difíciles',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _titleController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Título (opcional)',
                hintText: 'Ej: Mi afirmación diaria',
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              minLines: 5,
              maxLines: 10,
              maxLength: _maxChars,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Escribe aquí tu mensaje...',
                alignLabelWithHint: true,
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El contenido es requerido';
                }
                if (value.trim().length < 10) {
                  return 'El contenido debe tener al menos 10 caracteres';
                }
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$_charCount/$_maxChars',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _charCount > _maxChars * 0.9
                          ? Colors.orange
                          : const Color(0xFF94A3B8),
                    ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_contentFormKey.currentState!.validate()) {
                    setState(() => _currentStep = 2);
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

  Widget _buildAudioStep2() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Graba tu cápsula',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Graba un mensaje de voz para ti',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Título (opcional)',
              hintText: 'Ej: Palabras de aliento',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Text(
                  _formatDuration(_recordingDuration),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w300,
                        color: _isRecording
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF475569),
                      ),
                ),
                const SizedBox(height: 24),
                if (_audioPath != null && !_isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF22C55E),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Audio grabado',
                          style: TextStyle(color: Color(0xFF22C55E)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 80,
                    height: 80,
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
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isRecording
                      ? 'Toca para detener'
                      : (_audioPath != null
                          ? 'Toca para grabar de nuevo'
                          : 'Toca para grabar'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_audioPath != null && !_isRecording)
                  ? () => setState(() => _currentStep = 2)
                  : null,
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Text('Continuar'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(List emotions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Para qué emoción es?',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Esta cápsula se mostrará cuando sientas esto',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: emotions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: emotions.map<Widget>((emotion) {
                    return RadioListTile<int>(
                      value: emotion.id,
                      groupValue: _selectedEmotionId,
                      onChanged: (value) {
                        setState(() => _selectedEmotionId = value);
                      },
                      title: Text(emotion.name),
                      activeColor: const Color(0xFF5EEAD4),
                    );
                  }).toList(),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedEmotionId == null || _isLoading)
                  ? null
                  : _handleSave,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear Cápsula'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool disabled;

  const _TypeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: disabled
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF1E293B),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
