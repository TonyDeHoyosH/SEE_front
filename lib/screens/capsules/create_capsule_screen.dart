import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/base_api_service.dart';
import '../../services/local_database_service.dart';
import '../../models/capsule.dart';
import '../../widgets/crisis_step_indicator.dart';
import '../../utils/sanitizer_utils.dart';

class CreateCapsuleScreen extends StatefulWidget {
  final Capsule? capsule;

  const CreateCapsuleScreen({super.key, this.capsule});

  @override
  State<CreateCapsuleScreen> createState() => _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends State<CreateCapsuleScreen> {
  final _contentFormKey = GlobalKey<FormState>();
  final _audioFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  int _currentStep = 0;
  String _capsuleType = 'texto';
  List<int> _selectedEmotionIds = [];
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
    if (widget.capsule != null) {
      _titleController.text = widget.capsule!.title;
      _contentController.text = widget.capsule!.content;
      _capsuleType =
          widget.capsule!.type.toLowerCase() == 'audio' ? 'audio' : 'texto';
      _audioPath = widget.capsule!.audioPath;
      _selectedEmotionIds = List.from(widget.capsule!.emotionIds);
      _charCount = _contentController.text.length;
      // Skip step 0 (type selector) when editing — type is fixed
      _currentStep = 1;
    }

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
    if (_selectedEmotionIds.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final title = SanitizerUtils.sanitizeHtml(_titleController.text.trim());
      final api = context.read<CoreApiService>();

      if (widget.capsule == null) {
        if (_capsuleType == 'texto') {
          await api.createCapsule(
                title: title,
                type: 'TEXT',
                contentText: SanitizerUtils.sanitizeHtml(_contentController.text.trim()),
                emotionIds: _selectedEmotionIds,
              );
        } else if (_capsuleType == 'audio' && _audioPath != null) {
          await api.createCapsule(
                title: title,
                type: 'AUDIO',
                audioFile: File(_audioPath!),
                emotionIds: _selectedEmotionIds,
              );
        }
      }

      final capsuleId =
          widget.capsule?.id ?? 'cap-${DateTime.now().millisecondsSinceEpoch}';

      if (widget.capsule != null) {
        await api.updateCapsule(
              capsuleId,
              title: title,
              contentText: _capsuleType == 'texto'
                  ? SanitizerUtils.sanitizeHtml(_contentController.text.trim())
                  : null,
              emotionIds: _selectedEmotionIds,
            );
        // Actualizar localmente solo en edición (el backend devuelve datos frescos
        // que getCapsules() upsertirá la próxima vez que se carguen)
        final localUpdateData = {
          'id': capsuleId,
          'title': title,
          'content': _capsuleType == 'texto' ? SanitizerUtils.sanitizeHtml(_contentController.text.trim()) : '',
          'emotion_ids': _selectedEmotionIds.join(','),
          'is_active': widget.capsule?.isActive ?? true ? 1 : 0,
          'type': _capsuleType,
          'audio_path': _audioPath,
          'is_synced': 1,
          'created_at': widget.capsule?.createdAt?.toIso8601String() ??
              DateTime.now().toIso8601String(),
        };
        await LocalDatabaseService.updateCapsule(localUpdateData);
      }
      // En creación nueva NO insertamos en local — la API ya la guarda en el backend
      // y getCapsules() la upsertirá con el ID real la próxima vez que se cargue.

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
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String errorMessage) {
    // Detectar error de token S3 expirado: mostrar diálogo informativo
    if (errorMessage.contains('S3_EXPIRED_TOKEN')) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_off, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Servicio no disponible'),
            ],
          ),
          content: const Text(
            'El servidor no puede recibir archivos de audio en este momento '
            'porque sus credenciales de almacenamiento han expirado.\n\n'
            'Por favor avisa al administrador del sistema y vuelve a intentarlo más tarde.\n\n'
            'Mientras tanto, puedes crear cápsulas de texto sin problema.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // Error de subida S3 (red u otro)
    if (errorMessage.contains('S3_UPLOAD_ERROR')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No se pudo subir el audio. Verifica tu conexión e intenta de nuevo.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    // Error genérico
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error al crear cápsula: $errorMessage'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleAudioSelected() async {

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
        backgroundColor: Colors.transparent, // Global background
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          title: Text(widget.capsule != null ? 'Editar Cápsula' : 'Nueva Cápsula'),
          bottom: CrisisStepIndicator(
            currentStep: _currentStep + 1,
            totalSteps: 3,
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
                labelText: 'Título',
                hintText: 'Ej: Mi afirmación diaria',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es obligatorio';
                }
                return null;
              },
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _audioFormKey,
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
                labelText: 'Título',
                hintText: 'Ej: Palabras de aliento',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_audioPath != null && !_isRecording)
                    ? () {
                        if (_audioFormKey.currentState!.validate()) {
                          setState(() => _currentStep = 2);
                        }
                      }
                    : null,
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
                    return CheckboxListTile(
                      value: _selectedEmotionIds.contains(emotion.id),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            if (!_selectedEmotionIds.contains(emotion.id)) {
                              _selectedEmotionIds.add(emotion.id);
                            }
                          } else {
                            _selectedEmotionIds.remove(emotion.id);
                          }
                        });
                      },
                      title: Text(emotion.name),
                      activeColor: const Color(0xFF5EEAD4),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }).toList(),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedEmotionIds.isNotEmpty ? _handleSave : null,
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

  const _TypeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                    color: const Color(0xFF1E293B),
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
    );
  }
}
