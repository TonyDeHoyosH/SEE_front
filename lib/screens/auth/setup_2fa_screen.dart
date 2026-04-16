import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class Setup2FAScreen extends StatefulWidget {
  const Setup2FAScreen({super.key});

  @override
  State<Setup2FAScreen> createState() => _Setup2FAScreenState();
}

class _Setup2FAScreenState extends State<Setup2FAScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoadingSetup = true;
  String? _qrCodeStr;
  String? _secretStr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSetup();
    });
  }

  Future<void> _loadSetup() async {
    final provider = context.read<AuthProvider>();
    final data = await provider.setup2FAWorkflow();
    
    if (mounted) {
      if (data != null) {
        setState(() {
          _qrCodeStr = data['qrCodeUrl'];
          _secretStr = data['secret'];
          _isLoadingSetup = false;
        });
      } else {
        setState(() {
          _isLoadingSetup = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Construye la URL otpauth:// manualmente a partir del secret si es necesario
  String _buildOtpauthUrl(String secret, String email) {
    final encoded = Uri.encodeComponent('SEE:$email');
    return 'otpauth://totp/$encoded?secret=$secret&issuer=SEE';
  }

  /// Devuelve el Widget correcto para mostrar el QR según el tipo de dato
  Widget _buildQrWidget(String userEmail) {
    final qr = _qrCodeStr ?? '';
    final secret = _secretStr ?? '';

    // Caso 1: El backend mandó una imagen PNG en Base64
    if (qr.startsWith('data:image/')) {
      final base64Str = qr.contains(',') ? qr.split(',').last : qr;
      try {
        final bytes = base64Decode(base64Str);
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Image.memory(bytes, width: 200, height: 200),
        );
      } catch (_) {
        // Si falla el decode, seguimos a los otros casos
      }
    }

    // Caso 2: El backend mandó directamente la URL otpauth://
    String qrData = '';
    if (qr.startsWith('otpauth://')) {
      qrData = qr;
    } else if (secret.isNotEmpty) {
      // Caso 3: Solo tenemos el secret — construimos la URL nosotros
      qrData = _buildOtpauthUrl(secret, userEmail);
    }

    if (qrData.isEmpty) {
      return const Text(
        'No se pudo generar el QR. Usa la clave secreta manual.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: 200.0,
      ),
    );
  }

  Future<void> _handleEnable() async {
    if (!_formKey.currentState!.validate()) return;
    
    final code = _codeController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final provider = context.read<AuthProvider>();
    
    final success = await provider.confirmEnable2FA(code);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Autenticación de Dos Pasos activada exitosamente.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      Navigator.pop(context);
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _copySecret() {
    if (_secretStr != null) {
      Clipboard.setData(ClipboardData(text: _secretStr!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clave secreta copiada al portapapeles.'),
          backgroundColor: AppTheme.accentPrimary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSetup) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final provider = context.watch<AuthProvider>();
    if (_qrCodeStr == null && _secretStr == null && provider.errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 60),
                const SizedBox(height: 16),
                Text(
                  provider.errorMessage ?? 'Error desconocido.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _isLoadingSetup = true);
                    _loadSetup();
                  },
                  child: const Text('Reintentar'),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Configurar 2FA'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Paso 1: Vincula tu App',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Escanea el código QR desde Google Authenticator o Authy. También puedes copiar la clave secreta manualmente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      _buildQrWidget(
                        context.read<AuthProvider>().user?.email ?? '',
                      ),
                      const SizedBox(height: 24),
                      if (_secretStr != null) ...[
                        const Text('Clave Secreta:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _secretStr!,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 16,
                                    letterSpacing: 1.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: AppTheme.accentPrimary),
                                onPressed: _copySecret,
                                tooltip: 'Copiar',
                              )
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Paso 2: Verificar Activación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa el código de 6 dígitos que empieza a emitir tu aplicación autenticadora para finalizar la configuración.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.4),
                      letterSpacing: 8,
                    ),
                    prefixIcon: const Icon(Icons.security_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduce el código';
                    }
                    if (value.trim().length != 6) {
                      return 'El código debe tener 6 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.security_rounded),
                    label: const Text(
                      'Habilitar 2FA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    onPressed: provider.isLoading ? null : _handleEnable,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
