import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reflections_provider.dart';
import '../providers/victory_provider.dart';
import '../services/local_database_service.dart';

class FloatingNavbar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<FloatingNavbar> createState() => _FloatingNavbarState();
}

class _FloatingNavbarState extends State<FloatingNavbar> {
  int _capsulesCount = 1; // Default past 0 so it doesn't flash

  @override
  void initState() {
    super.initState();
    _checkCapsules();
  }

  @override
  void didUpdateWidget(covariant FloatingNavbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _checkCapsules();
    }
  }

  Future<void> _checkCapsules() async {
    final count = await LocalDatabaseService.countActiveCapsules();
    if (mounted) {
      setState(() {
        _capsulesCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 12,
      right: 12,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1025), // negro con tinte morado profundo
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D2040).withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.home_rounded, 'Home'),
            _buildNavItem(1, Icons.favorite_rounded, 'Victorias'),
            _buildNavItem(2, Icons.health_and_safety_rounded, 'Cápsulas'),
            _buildNavItem(3, Icons.edit_note_rounded, 'Reflexiones'),
            _buildNavItem(4, Icons.picture_as_pdf_rounded, 'Reporte'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isActive = widget.currentIndex == index;
    return GestureDetector(
      onTap: () => widget.onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  size: isActive ? 28 : 24,
                ),
                if (index == 1) ...[
                  Consumer<VictoryProvider>(
                    builder: (context, provider, child) {
                      if (provider.todayChecked.isEmpty) {
                        return Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
                if (index == 2) ...[
                  if (_capsulesCount == 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
                if (index == 3) ...[
                  // The Provider reads the pending reflections from DB during startup and updates
                  Consumer<ReflectionsProvider>(
                    builder: (context, provider, child) {
                      if (provider.pendingCount > 0) {
                        return Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${provider.pendingCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
