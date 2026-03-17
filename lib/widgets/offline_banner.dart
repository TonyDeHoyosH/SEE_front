import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../config/theme.dart';

/// Global overlay banner shown when the device is offline.
/// When online and pending data exists, shows an animated sync button.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _wasOffline = false;
  bool _showRestoredMessage = false;
  bool _showOfflineMessage = false;
  Timer? _messageTimer;

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _triggerMessageTimer(bool isRestored) {
    _messageTimer?.cancel();
    setState(() {
      if (isRestored) {
        _showRestoredMessage = true;
        _showOfflineMessage = false;
      } else {
        _showOfflineMessage = true;
        _showRestoredMessage = false;
      }
    });

    _messageTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showRestoredMessage = false;
          _showOfflineMessage = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        final isOnline = connectivity.isOnline;

        // Detect state transitions
        if (!isOnline && !_wasOffline) {
          _wasOffline = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerMessageTimer(false);
          });
        } else if (isOnline && _wasOffline) {
          _wasOffline = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerMessageTimer(true);
          });
        }

        final showStatusBar = _showOfflineMessage || _showRestoredMessage;
        final showSyncBtn =
            isOnline && (connectivity.hasPendingSync || connectivity.isSyncing);

        if (!showStatusBar && !showSyncBtn) {
          return const SizedBox.shrink();
        }

        // Both can show at the same time
        return Stack(
          children: [
            if (showStatusBar)
              _StatusMessageBar(isRestored: _showRestoredMessage),
            if (showSyncBtn)
              Positioned(
                // Push the button below the status bar height (~50px) if bar is visible
                top: MediaQuery.of(context).padding.top +
                    (showStatusBar ? 56 : 8),
                right: 16,
                child: _SyncButton(connectivity: connectivity),
              ),
          ],
        );
      },
    );
  }
}

class _StatusMessageBar extends StatelessWidget {
  final bool isRestored;
  const _StatusMessageBar({required this.isRestored});

  @override
  Widget build(BuildContext context) {
    final bgColor = isRestored ? const Color(0xFF2E7D32) : const Color(0xFFB00020);
    final icon = isRestored ? Icons.wifi_rounded : Icons.wifi_off_rounded;
    final text = isRestored
        ? 'Conexión restaurada'
        : 'Sin conexión · Datos guardados localmente';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: bgColor.withValues(alpha: 0.95),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncButton extends StatefulWidget {
  final ConnectivityProvider connectivity;
  const _SyncButton({required this.connectivity});

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.connectivity.isSyncing) {
      return _buildContainer(
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
        label: 'Sincronizando...',
        onTap: null,
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_bounceAnimation, _rotationController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: _buildContainer(
            child: Transform.rotate(
              angle: _rotationController.value * 2 * pi,
              child: const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
            ),
            label: 'Sincronizar datos',
            onTap: () => widget.connectivity.syncAll(),
          ),
        );
      },
    );
  }

  Widget _buildContainer({
    required Widget child,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accentPrimary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentPrimary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
