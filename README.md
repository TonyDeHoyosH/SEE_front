# AWOS - A Way Out of Suffering

![Flutter](https://img.shields.io/badge/Flutter-3.41.0-blue)
![Dart](https://img.shields.io/badge/Dart-3.2%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

Una aplicación móvil MVP para el manejo de crisis de salud mental, desarrollada con Flutter.

---

## Descripción

AWOS es una aplicación de salud mental que ayuda a los usuarios a:
- Gestionar momentos de crisis con técnicas de respiración guiadas
- Registrar victorias personales diarias
- Acceder a cápsulas de contenido calmante
- Monitorear su progreso emocional

---

## Arquitectura

El proyecto sigue **Clean Architecture** con la siguiente estructura:

```
lib/
├── config/          # Configuración (theme, constantes)
├── models/          # Modelos de datos (User, Crisis, Victory, etc.)
├── providers/       # State management (Provider pattern)
├── services/        # Capa de servicios (API Mock y HTTP)
├── screens/         # Pantallas UI (Auth, Home, Crisis, etc.)
└── widgets/         # Widgets reutilizables
```

---

## Etapas Completadas

### Etapa 1: Cimientos y Modelos
- Configuración de dependencias
- 7 modelos de datos con serialización JSON
- Servicio Mock para desarrollo sin backend
- Theme personalizado con Google Fonts

### Etapa 2: Autenticación
- Pantallas de Login y Register con validaciones
- AuthProvider con state management
- Navegación condicional basada en auth
- Persistencia de token con SharedPreferences

### Etapa 3: Dashboard y Catálogos
- DataProvider para catálogos (emociones, tipos de victoria, evaluaciones)
- HomeScreen con dashboard dinámico
- Botones de estado emocional ("BIEN" / "EN CRISIS")
- BottomNavigationBar con 3 secciones
- Tarjetas de resumen (victorias semanales, última crisis)

---

## Dependencias Principales

```yaml
dependencies:
  provider: ^6.1.1           # State management
  http: ^1.1.2               # HTTP client
  shared_preferences: ^2.2.2 # Local storage
  intl: ^0.18.1              # Internacionalización
  google_fonts: ^6.1.0       # Tipografías
```

---

## Configuración Inicial

### Prerrequisitos
- Flutter SDK 3.2.0 o superior
- Dart 3.2.0 o superior
- Android Studio / VS Code con extensiones de Flutter

### Instalación

1. **Clonar el repositorio:**
   ```bash
   git clone <repository-url>
   cd Front_SEE
   ```

2. **Crear estructura nativa (si es necesario):**
   ```bash
   flutter create .
   ```

3. **Instalar dependencias:**
   ```bash
   flutter pub get
   ```

4. **Verificar configuración:**
   ```bash
   flutter doctor -v
   ```

5. **Ejecutar en emulador/dispositivo:**
   ```bash
   flutter run
   ```

---

## Testing

### Análisis estático:
```bash
flutter analyze
```

### Tests (cuando estén implementados):
```bash
flutter test
```

---

##  Design System

**Paleta de colores:**
- **Primary Slate:** `#475569` - Color principal
- **Secondary Green:** `#86EFAC` - Acentos positivos
- **Background:** `#F8FAFC` - Fondo claro
- **Teal Accent:** `#5EEAD4` - Victorias
- **Salmon:** `#FB7185` - Crisis/Alerta

**Tipografía:**
- Google Fonts: **Lato**

---

## Modelos de Datos

| Modelo | Descripción |
|--------|-------------|
| `User` | Usuario con email, nombrePreferido, token |
| `Emotion` | Catálogo de emociones (Miedo, Tristeza, etc.) |
| `VictoryType` | Tipos de victorias (Higiene, No Consumo, etc.) |
| `Evaluation` | Evaluaciones post-crisis (Mejor, Igual, Peor) |
| `Capsule` | Contenido calmante asociado a emociones |
| `Crisis` | Registro de sesión de crisis |
| `Victory` | Registro de victoria del usuario |
| `DashboardData` | Datos de resumen del dashboard |

---

## Contribución

Este es un proyecto académico/MVP. Para contribuir:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## Notas de Desarrollo

- **MockApiService** está activo por defecto en `main.dart`
- Delay de red simulado: 1 segundo
- Para cambiar a HTTP real: reemplazar `MockApiService()` por `HttpApiService(baseUrl: 'URL')`
- Los catálogos se cargan automáticamente al iniciar la app
- El dashboard se carga al entrar a la pantalla Home

---

## Licencia

Este proyecto está bajo licencia MIT. Ver archivo `LICENSE` para más detalles.

---

## 👨‍💻 Autor

**Proyecto AWOS**  
Universidad Politécnica de Chiapas - Proyecto Integrador 5A 2026

---

##  Soporte

Para preguntas o problemas, contacta a través de [adehoyosh@gmail.com]

---

**¡Gracias por contribuir a la salud mental digital!** 

---

## Asistencia de Inteligencia Artificial

Parte del código de este proyecto fue desarrollado con el apoyo de herramientas de inteligencia artificial generativa como asistentes de codificación. Esto incluye la generación de estructuras base, sugerencias de implementación y validación de patrones arquitectónicos.

El uso de estas herramientas fue deliberado y supervisado: cada fragmento de código generado fue revisado, adaptado y validado por el equipo de desarrollo para garantizar su correcta integración con la arquitectura MVVM del proyecto, el cumplimiento de los estándares de seguridad definidos y la coherencia con los requisitos funcionales del sistema.

La IA fue utilizada como un recurso de productividad, no como un sustituto del criterio de ingeniería. La responsabilidad sobre las decisiones de diseño, la arquitectura y la calidad del software recae íntegramente en el equipo desarrollador.
