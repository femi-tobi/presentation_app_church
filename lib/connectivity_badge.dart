import 'package:flutter/material.dart';
import 'connectivity_service.dart';
import 'dashboard_page.dart'; // For SacredColors, SacredTypography

class ConnectivityBadge extends StatelessWidget {
  const ConnectivityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ConnectivityService.instance,
      builder: (context, child) {
        final isOnline = ConnectivityService.instance.isOnline;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: isOnline
              ? _Badge(
                  key: const ValueKey('online'),
                  icon: Icons.cloud_done_outlined,
                  label: 'Online',
                  bgColor: const Color(0xFFD6F5E3),
                  borderColor: const Color(0xFF34A853).withValues(alpha: 0.3),
                  contentColor: const Color(0xFF1A7A3C),
                )
              : _Badge(
                  key: const ValueKey('offline'),
                  icon: Icons.cloud_off,
                  label: 'Offline',
                  bgColor: SacredColors.errorContainer,
                  borderColor: SacredColors.error.withValues(alpha: 0.2),
                  contentColor: SacredColors.onErrorContainer,
                ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color borderColor;
  final Color contentColor;

  const _Badge({
    super.key,
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.borderColor,
    required this.contentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: contentColor, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: SacredTypography.labelSm(context).copyWith(
              color: contentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
