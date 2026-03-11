import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingOverlay({super.key, required this.onDone});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const _slides = [
    _OnboardingSlide(
      emoji: '🏠',
      title: 'Tu espacio seguro',
      description:
          'En la pantalla principal encontrarás dos botones: si estás pasándola bien, registra tu ánimo. Si sientes que tus emociones son demasiado, presiona "Necesito ayuda" para iniciar el flujo de crisis.\n\nTambién puedes tocar tu foto de perfil (arriba a la derecha) para abrir el menú y acceder a tus ajustes.',
      color: Color(0xFFD9C8F0),
    ),
    _OnboardingSlide(
      emoji: '🏆',
      title: 'Victorias',
      description:
          'Tus victorias son tus logros personales: cosas que hiciste bien hoy, por pequeñas que sean.\n\nPuedes crearlas, editarlas y eliminarlas cuando quieras. Además, verás un resumen de tus últimas victorias para recordar todo lo que ya has avanzado.',
      color: Color(0xFFFDE5C8),
    ),
    _OnboardingSlide(
      emoji: '💊',
      title: 'Cápsulas',
      description:
          'Las cápsulas son recordatorios que tú mismo creas para los momentos difíciles. Cuando estés en crisis, la app te las mostrará para ayudarte a reconectar con tus motivaciones.\n\nPuedes crearlas por texto o por audio, y editarlas cuando lo necesites.',
      color: Color(0xFFC8E8F0),
    ),
    _OnboardingSlide(
      emoji: '📄',
      title: 'Reporte Clínico',
      description:
          'Aquí puedes generar y descargar tu reporte clínico, que muestra un resumen de tu actividad en la app: crisis, victorias, y más.\n\nTambién puedes ver y descargar reportes anteriores para compartir con tu terapeuta o guardarlos para ti.',
      color: Color(0xFFC8F0D9),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _dismiss();
    }
  }

  void _dismiss() {
    _fadeController.reverse().then((_) => widget.onDone());
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemCount: _slides.length,
                        itemBuilder: (context, index) {
                          return _SlideView(slide: _slides[index]);
                        },
                      ),
                    ),
                    // Bottom bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Dots
                          Row(
                            children: List.generate(_slides.length, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.only(right: 6),
                                width: i == _currentPage ? 20 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i == _currentPage
                                      ? AppTheme.accentButton
                                      : AppTheme.accentLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                          const Spacer(),
                          // Skip button
                          if (_currentPage < _slides.length - 1)
                            TextButton(
                              onPressed: _dismiss,
                              child: Text(
                                'Omitir',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Next / Done button
                          ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentButton,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            child: Text(
                              _currentPage < _slides.length - 1
                                  ? 'Siguiente'
                                  : '¡Entendido!',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: slide.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                slide.emoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            slide.title,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                slide.description,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.6,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  final String emoji;
  final String title;
  final String description;
  final Color color;

  const _OnboardingSlide({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });
}
