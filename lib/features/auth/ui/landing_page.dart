import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _logoAsset = 'assets/branding/sudvet_logo.png';
const _svPrimary = Color(0xFF2E7D4F);
const _svDeep = Color(0xFF1F5C3A);
const _svOchre = Color(0xFFC79A3B);
const _svWarmBg = Color(0xFFF7F5EF);
const _svBorder = Color(0xFFD8DCCF);
const _svText = Color(0xFF1E241F);
const _svMuted = Color(0xFF5E675F);
const _devServerSettingsEnabled = bool.fromEnvironment(
  'ENABLE_DEV_SERVER_SETTINGS',
  defaultValue: false,
);

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final isCompact = width < 560;
    final pageBg = isDark ? const Color(0xFF111612) : _svWarmBg;
    final accentTop = isDark ? const Color(0xFF2F7C4D) : _svPrimary;
    final accentAlt = isDark ? const Color(0xFFD0A24E) : _svOchre;

    return Scaffold(
      body: Container(
        color: pageBg,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accentTop, accentAlt]),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(isCompact ? 14 : 18, isCompact ? 12 : 16, isCompact ? 14 : 18, 18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _HeroPanel(
                                    theme: theme,
                                    isCompact: false,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const SizedBox(
                                  width: 420,
                                  child: _ActionPanel(isCompact: false),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _HeroPanel(theme: theme, isCompact: isCompact),
                                const SizedBox(height: 12),
                                _ActionPanel(isCompact: isCompact),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.theme,
    required this.isCompact,
  });

  final ThemeData theme;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyTextColor = isDark ? const Color(0xFFB8C4BA) : _svMuted;
    final workflowCardBg = isDark ? const Color(0xFF1A211B) : const Color(0xFFFFFEFB);
    final workflowCardBorder = isDark ? const Color(0xFF313B33) : _svBorder;
    final workflowTitleColor = isDark ? const Color(0xFFEAF0E7) : _svText;
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 16 : 20,
          isCompact ? 16 : 20,
          isCompact ? 16 : 20,
          isCompact ? 14 : 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LogoHeader(isCompact: isCompact),
            SizedBox(height: isCompact ? 14 : 18),
            Text(
              'Cattle screening and vet referral.',
              style: theme.textTheme.titleLarge?.copyWith(
                height: 1.15,
                fontSize: isCompact ? 17 : 22,
              ),
            ),
            SizedBox(height: isCompact ? 6 : 10),
            if (!isCompact)
              Text(
                'Image screening for LSD/FMD, clinical rules for ECF/CBPP, and structured case follow-up.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: bodyTextColor,
                  fontSize: 15,
                ),
              )
            else
              Text(
                'For CHWs and veterinarians.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: bodyTextColor,
                  fontSize: 12.2,
                ),
              ),
            SizedBox(height: isCompact ? 10 : 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _Pill(label: 'LSD'),
                _Pill(label: 'FMD'),
                _Pill(label: 'ECF'),
                _Pill(label: 'CBPP'),
              ],
            ),
            if (isCompact) ...[
              const SizedBox(height: 10),
              const _CompactWorkflowStrip(),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: workflowCardBg,
                  border: Border.all(color: workflowCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Field workflow',
                      style: TextStyle(
                        color: workflowTitleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 12),
                    _ProcessRow(
                      step: '1',
                      title: 'Capture',
                      subtitle: 'Add images and observed symptoms.',
                    ),
                    SizedBox(height: 12),
                    _ProcessRow(
                      step: '2',
                      title: 'Screen',
                      subtitle: 'Review AI + clinical rule outputs.',
                    ),
                    SizedBox(height: 12),
                    _ProcessRow(
                      step: '3',
                      title: 'Refer',
                      subtitle: 'Send to vet and track follow-up.',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactWorkflowStrip extends StatelessWidget {
  const _CompactWorkflowStrip();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF1A211B) : const Color(0xFFFFFEFB);
    final panelBorder = isDark ? const Color(0xFF313B33) : _svBorder;
    final chipBg = isDark ? const Color(0xFF232B24) : const Color(0xFFF6F8F1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Field workflow',
            style: TextStyle(
              color: isDark ? const Color(0xFFEAF0E7) : _svText,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CompactStepPill(step: '1', label: 'Capture', chipBg: chipBg, chipBorder: panelBorder),
              _CompactStepPill(step: '2', label: 'Screen', chipBg: chipBg, chipBorder: panelBorder),
              _CompactStepPill(step: '3', label: 'Refer', chipBg: chipBg, chipBorder: panelBorder),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Photos, symptoms, vet follow-up.',
            style: TextStyle(
              color: isDark ? const Color(0xFFB8C4BA) : _svMuted,
              fontSize: 11.8,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStepPill extends StatelessWidget {
  const _CompactStepPill({
    required this.step,
    required this.label,
    required this.chipBg,
    required this.chipBorder,
  });

  final String step;
  final String label;
  final Color chipBg;
  final Color chipBorder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeBg = isDark ? const Color(0xFF253429) : const Color(0xFFE8F1E9);
    final badgeBorder = isDark ? const Color(0xFF395544) : const Color(0xFFD0E2D4);
    final labelColor = isDark ? const Color(0xFFEAF0E7) : _svText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeBorder),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: _svDeep,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final helperColor = isDark ? const Color(0xFFB8C4BA) : _svMuted;
    return Card(
      child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 16 : 18,
            isCompact ? 16 : 18,
            isCompact ? 16 : 18,
            isCompact ? 14 : 16,
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Get Started',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: isCompact ? 20 : 24,
              ),
            ),
            SizedBox(height: isCompact ? 4 : 6),
            if (!isCompact)
              Text(
                'Sign in or create an account to continue.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: helperColor,
                  fontSize: 14,
                ),
              )
            else
              Text(
                'Choose an option to continue.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: helperColor,
                  fontSize: 11.8,
                ),
              ),
            SizedBox(height: isCompact ? 12 : 14),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Sign In'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/signup'),
              child: const Text('Create Account'),
            ),
            SizedBox(height: isCompact ? 4 : 12),
            if (!isCompact)
              Text(
                'SudVet supports screening, referral, and case follow-up.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: helperColor),
              )
            else if (_devServerSettingsEnabled)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => context.go('/setup-api'),
                  child: const Text('Server settings (advanced)'),
                ),
              ),
            if (!isCompact && _devServerSettingsEnabled)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => context.go('/setup-api'),
                  child: const Text('Server settings (advanced)'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shellBg = isDark ? const Color(0xFF1A211B) : const Color(0xFFFFFEFB);
    final logoBg = isDark ? const Color(0xFF202923) : const Color(0xFFF3F6EC);
    final border = isDark ? const Color(0xFF313B33) : _svBorder;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 6 : 10),
      decoration: BoxDecoration(
        color: shellBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: isCompact ? 128 : 190,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: logoBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8 : 12,
                    vertical: isCompact ? 6 : 10,
                  ),
                  child: Image.asset(
                    _logoAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SUDVET',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: _svPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SCREEN. REFER. PROTECT.',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _svDeep,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stepBadgeBg = isDark ? const Color(0xFF253429) : const Color(0xFFE8F1E9);
    final stepBadgeBorder = isDark ? const Color(0xFF395544) : const Color(0xFFD0E2D4);
    final titleColor = isDark ? const Color(0xFFEAF0E7) : _svText;
    final subtitleColor = isDark ? const Color(0xFFB8C4BA) : _svMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: stepBadgeBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: stepBadgeBorder),
          ),
          child: Center(
            child: Text(
              step,
                style: TextStyle(
                  color: _svDeep,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2A251B) : const Color(0xFFFBF4E1);
    final border = isDark ? const Color(0xFF5A4C2A) : const Color(0xFFE4D0A5);
    final textColor = isDark ? const Color(0xFFF0E6CE) : _svText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: textColor),
      ),
    );
  }
}
