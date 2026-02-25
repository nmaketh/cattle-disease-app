import 'package:flutter/material.dart';

const _authLogoAsset = 'assets/branding/sudvet_logo.png';
const _authBorder = Color(0xFFD8DCCF);
const _authPanel = Color(0xFFFFFEFB);
const _authLogoBg = Color(0xFFF3F6EC);
const _authPrimary = Color(0xFF2E7D4F);
const _authDeep = Color(0xFF1F5C3A);

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.illustrationIcon = Icons.health_and_safety_rounded,
    this.illustrationLabel = 'Cattle health app illustration',
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData illustrationIcon;
  final String illustrationLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topBg = isDark ? const Color(0xFF152019) : const Color(0xFFE5F4EA);
    final bottomBg = isDark ? const Color(0xFF0F1411) : const Color(0xFFF3F7F3);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topBg, bottomBg],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, widget) {
                    return Transform.translate(
                      offset: Offset(0, 14 * (1 - value)),
                      child: Opacity(opacity: value, child: widget),
                    );
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AuthBrandHeader(
                            icon: illustrationIcon,
                            semanticsLabel: illustrationLabel,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            title,
                            style: theme.textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader({required this.icon, required this.semanticsLabel});

  final IconData icon;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF1A211B) : _authPanel;
    final logoBg = isDark ? const Color(0xFF1F2922) : _authLogoBg;
    final badgeBg = isDark ? const Color(0xFF202A23) : Colors.white.withValues(alpha: 0.92);
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _authBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: DecoratedBox(
            decoration: BoxDecoration(color: logoBg),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Image.asset(
                      _authLogoAsset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.medical_services_rounded,
                            color: _authPrimary,
                            size: 34,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _authBorder),
                    ),
                    child: Icon(icon, color: _authDeep, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
