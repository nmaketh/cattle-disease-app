import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../widgets/skeleton.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

const _devServerSettingsEnabled = bool.fromEnvironment(
  'ENABLE_DEV_SERVER_SETTINGS',
  defaultValue: false,
);
const _logoAsset = 'assets/branding/sudvet_logo.png';
const _uiGreen = Color(0xFF2E7D4F);
const _uiWarm = Color(0xFFF7FBF8);
const _uiBorder = Color(0xFFD8E2D8);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _inlineError;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _inlineError = null);

    context.read<AuthBloc>().add(
      AuthLoginRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  bool get _hasConnectionIssue {
    final message = _inlineError?.toLowerCase() ?? '';
    if (message.isEmpty) {
      return false;
    }
    return message.contains('unable to reach') ||
        message.contains('server unavailable') ||
        message.contains('server is unavailable') ||
        message.contains('timed out') ||
        message.contains('waking up') ||
        message.contains('internet connection');
  }

  String get _displayErrorMessage {
    if (!_hasConnectionIssue) {
      return _inlineError ?? '';
    }
    return 'SudVet server unavailable. Retry or check connection.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F1411) : _uiWarm;
    final cardBg = isDark ? const Color(0xFF151C17) : Colors.white;
    final panelBg = isDark ? const Color(0xFF1A231D) : const Color(0xFFEAF5EE);
    final fieldBg = isDark ? const Color(0xFF121814) : Colors.white;
    final fieldBorder = isDark ? const Color(0xFF2E3931) : _uiBorder;
    final titleColor = isDark ? Colors.white : const Color(0xFF111714);
    final bodyColor = isDark ? const Color(0xFFB8C4BA) : const Color(0xFF516055);
    final lineColor = isDark ? const Color(0xFF2C3730) : const Color(0xFFD9E0D9);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          setState(() => _inlineError = state.message);
        }
      },
      child: Scaffold(
        backgroundColor: pageBg,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: fieldBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 106,
                            decoration: BoxDecoration(
                              color: panelBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: fieldBorder),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                _logoAsset,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Text(
                                    'SUDVET',
                                    style: TextStyle(
                                      color: _uiGreen,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 28,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Login',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: titleColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in to continue cattle screening and vet follow-up.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: bodyColor,
                              fontSize: 12.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              final loading = state is AuthAuthenticating && !state.checkingSession;
                              return SizedBox(
                                height: 50,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: fieldBorder),
                                    backgroundColor: fieldBg,
                                  ),
                                  onPressed: loading
                                      ? null
                                      : () {
                                          setState(() => _inlineError = null);
                                          context.read<AuthBloc>().add(const AuthGoogleRequested());
                                        },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1D251F) : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: fieldBorder),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'G',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF4285F4),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text('Google account'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: Divider(color: lineColor)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'or',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: bodyColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: lineColor)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _FieldLabel(text: 'Email', color: titleColor),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) => Validators.email(value ?? ''),
                            style: theme.textTheme.bodyLarge?.copyWith(color: titleColor),
                            decoration: InputDecoration(
                              hintText: 'Enter your email',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: bodyColor.withValues(alpha: 0.7),
                              ),
                              filled: true,
                              fillColor: fieldBg,
                              prefixIcon: Icon(Icons.email_outlined, color: bodyColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: fieldBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: fieldBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: _uiGreen, width: 1.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FieldLabel(text: 'Password', color: titleColor),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            validator: (value) => Validators.required(value ?? '', label: 'Password'),
                            style: theme.textTheme.bodyLarge?.copyWith(color: titleColor),
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: bodyColor.withValues(alpha: 0.7),
                              ),
                              filled: true,
                              fillColor: fieldBg,
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: bodyColor),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: bodyColor,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: fieldBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: fieldBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: _uiGreen, width: 1.6),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.go('/forgot-password'),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            child: _inlineError == null
                                ? const SizedBox.shrink(key: ValueKey('no-error'))
                                : Container(
                                    key: ValueKey(_inlineError),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _hasConnectionIssue
                                              ? Icons.cloud_off_rounded
                                              : Icons.error_outline_rounded,
                                          size: 18,
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _displayErrorMessage,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onErrorContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (_hasConnectionIssue)
                                          TextButton(
                                            onPressed: () {
                                              if (_formKey.currentState?.validate() ?? false) {
                                                _submit();
                                              }
                                            },
                                            child: const Text('Retry'),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              final loading = state is AuthAuthenticating && !state.checkingSession;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 52,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _uiGreen,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: loading ? null : _submit,
                                      child: loading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'LOGIN',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: theme.textTheme.bodySmall?.copyWith(color: bodyColor),
                                      ),
                                      TextButton(
                                        onPressed: loading ? null : () => context.go('/signup'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('Create account'),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                final loading =
                                    state is AuthAuthenticating && !state.checkingSession;
                                return loading
                                    ? const Center(
                                        key: ValueKey('logging-in'),
                                        child: SkeletonBox(
                                          width: 220,
                                          height: 12,
                                          radius: 8,
                                        ),
                                      )
                                    : Text(
                                        key: const ValueKey('login-footer'),
                                        'Use your SudVet account to continue.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall?.copyWith(color: bodyColor),
                                      );
                              },
                            ),
                          ),
                          if (_devServerSettingsEnabled)
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                onPressed: () => context.push('/setup-api'),
                                child: const Text('Server settings (advanced)'),
                              ),
                            ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
    );
  }
}
