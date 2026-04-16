import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

class PrivacyPolicyDialog extends StatefulWidget {
  final bool isDismissible;
  final VoidCallback? onAccepted;
  final VoidCallback? onRejected;

  const PrivacyPolicyDialog({
    super.key,
    this.isDismissible = true,
    this.onAccepted,
    this.onRejected,
  });

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();

  /// Helper para mostrar el diálogo fácilmente
  static Future<void> show(BuildContext context,
      {bool isDismissible = true,
      VoidCallback? onAccepted,
      VoidCallback? onRejected}) {
    return showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) => PrivacyPolicyDialog(
        isDismissible: isDismissible,
        onAccepted: onAccepted,
        onRejected: onRejected,
      ),
      // Evita cerrar el diálogo con la tecla/gesto de "atrás" en Android si no es dismissible
      routeSettings: isDismissible ? null : const RouteSettings(),
    ).then((_) {
      // Necesitamos una manera de manejar la acción dismiss
    });
  }

  /// Verifica si la política ya fue aceptada
  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_accepted_privacy') ?? false;
  }
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog> {
  bool _isLoading = false;

  Future<void> _handleAccept() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_privacy', true);

    if (mounted) {
      Navigator.of(context).pop(true);
      widget.onAccepted?.call();
    }
  }

  void _handleReject() {
    if (widget.isDismissible) {
      Navigator.of(context).pop(false);
      widget.onRejected?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si no es dismissible (ej. en el onboarding estricto), usar PopScope
    return PopScope(
      canPop: widget.isDismissible,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppTheme.accentPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Aviso de Privacidad',
                      style: AppTheme.lightTheme.textTheme.headlineMedium
                          ?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0xFF9C27B0), width: 1),
                          ),
                        ),
                        child: Text(
                          'Al hacer uso de SEE, usted manifiesta haber leido y aceptado el presente Aviso de Privacidad, consintiendo el tratamiento de sus datos personales conforme a lo aqui descrito.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                            color: Color(0xFF4A148C),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                    '''En cumplimiento a lo establecido por la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP), SEE (Sistema de Equilibrio Emocional) pone a su disposición este Aviso de Privacidad.

1. Información que Recopilamos
Al utilizar esta aplicación, podríamos solicitar o almacenar información personal, incluyendo pero no limitándose a: su nombre (o seudónimo), dirección de correo electrónico, y datos sensibles relacionados con sus emociones y estado psicológico al registrar crisis o victorias.

2. Uso de la Información
Los datos recabados serán utilizados exclusiva y estrictamente para:
- Brindarle recomendaciones y contenido de apoyo durante situaciones de crisis emocionales.
- Permitirle registrar y consultar su progreso emocional a través de victorias y reflexiones.
- Generar reportes en formato PDF para su uso personal y facilitar el seguimiento por parte de profesionales de la salud, solo si usted así lo decide y lo comparte.
- Almacenar de forma segura sus grabaciones de voz (Cápsulas de Audio) en nuestra base de datos remota para que estén sincronizadas y respaldadas. Estas grabaciones son estrictamente personales; nadie más tiene acceso a ellas y SEE no analizará ni compartirá su contenido.

3. Privacidad y Seguridad
Garantizamos que su información está protegida en nuestra base de datos (PostgreSQL/AWS) con mecanismos de seguridad modernos, cifrado en tránsito y en reposo (contraseñas con hash). 

4. Derechos ARCO
Usted tiene derecho a conocer qué datos personales tenemos de usted, para qué los utilizamos y las condiciones de su uso (Acceso). Asimismo, es su derecho solicitar la corrección de su información (Rectificación); que la eliminemos de nuestros registros o bases de datos (Cancelación); así como oponerse al uso de sus datos personales para fines específicos (Oposición). Para ejercer estos derechos, dispone de la opción "Eliminar cuenta" en nuestra aplicación en cualquier momento.

Al presionar "Aceptar", usted consiente que sus datos personales formen parte de nuestra plataforma como se indica en este aviso.''',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                    ),
                  ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.isDismissible)
                    TextButton(
                      onPressed: _handleReject,
                      child: const Text(
                        'Cerrar',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentButton,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Aceptar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
