import 'package:flutter/material.dart';
import '../config/theme.dart';

class TermsAndConditionsDialog extends StatelessWidget {
  final bool isDismissible;
  
  const TermsAndConditionsDialog({
    super.key,
    this.isDismissible = true,
  });

  /// Helper para mostrar el diálogo fácilmente
  static Future<void> show(BuildContext context, {bool isDismissible = true}) {
    return showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) => TermsAndConditionsDialog(
        isDismissible: isDismissible,
      ),
      routeSettings: isDismissible ? null : const RouteSettings(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: isDismissible,
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
                      Icons.description_rounded,
                      color: AppTheme.accentPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Términos y Condiciones',
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
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    '''Bienvenido a SEE (Sistema de Equilibrio Emocional). Al descargar, instalar y utilizar esta aplicación, usted acepta los siguientes Términos y Condiciones.
                    
1. Uso Proporcionado y Limitaciones
SEE es una herramienta de apoyo y registro emocional, diseñada para ayudar al usuario a identificar crisis, registrar victorias y contar con recursos de respiración y relajación. Bajo ninguna circunstancia SEE reemplaza la atención médica, terapia, asesoramiento psicológico profesional o tratamiento psiquiátrico de emergencia.

2. Situaciones de Emergencia
Si se encuentra en una situación de peligro inmediato, tiene pensamientos suicidas o de autolesión, debe contactar de inmediato a los servicios de emergencia de su país o buscar ayuda profesional presencial urgente. SEE no provee intervención activa de urgencia vital.

3. Responsabilidad del Usuario
El usuario es responsable de mantener la confidencialidad de su cuenta y contraseña. SEE no se hace responsable por el acceso no autorizado al dispositivo del usuario ni por la pérdida temporal o permanente de la información en caso de olvidar las credenciales.

4. Propiedad Intelectual
Todos los derechos de propiedad intelectual del software, diseño, iconografía y bases de datos pertenecen a los desarrolladores y creadores de SEE. Queda prohibida la copia, reproducción, la ingeniería inversa o distribución de la aplicación sin nuestro consentimiento expreso.

5. Disponibilidad del Servicio
Haremos lo posible por mantener una disponibilidad continua de la aplicación y la sincronización en la nube; sin embargo, no nos hacemos responsables de interrupciones temporales ocasionadas por mantenimiento, fallas en los servidores (AWS) o en su conexión a internet.

6. Modificaciones a los Términos
Nos reservamos el derecho de modificar o actualizar estos Términos y Condiciones en cualquier momento. Usted será notificado de cambios sustanciales al iniciar la aplicación.

Al continuar usando SEE, usted acepta haber leído, entendido y acordado regirse por los presentes Términos y Condiciones.''',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentButton,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cerrar',
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
