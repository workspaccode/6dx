import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/github_device_code.dart';
import '../providers/auth_providers.dart';

@RoutePage()
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _showEmailForm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    AppLogger.action('LoginPage', 'tapped "sign in with email" for $email');
    if (email.isEmpty || password.isEmpty) {
      _showSnack('أدخل البريد الإلكتروني وكلمة المرور');
      return;
    }
    final ok = await ref.read(authNotifierProvider.notifier).signInWithEmail(
          email: email,
          password: password,
        );
    if (!mounted) return;
    if (ok) {
      context.go(AppRoutes.home);
    } else {
      _showSnack('تعذّر تسجيل الدخول، حاول مرة أخرى');
    }
  }

  /// GitHub sign-in. Supabase runs the OAuth round trip in the browser and
  /// answers through a deep link; the fallback backend shows a device code the
  /// user confirms on github.com and polls until it is approved.
  Future<void> _continueWithGithub() async {
    AppLogger.action('LoginPage', 'tapped "continue with GitHub"');
    final notifier = ref.read(authNotifierProvider.notifier);

    if (!notifier.usesDeviceCode) {
      final result = await notifier.signInWithGithub();
      if (!mounted) return;
      final user = result.dataOrNull;
      if (user != null) {
        AppLogger.action(
          'LoginPage',
          'sign-in with GitHub finished, opening the app',
        );
        context.go(AppRoutes.home);
        return;
      }
      final reason = result.failureOrNull?.message ?? 'تعذّر الاتصال بـ GitHub';
      AppLogger.action('LoginPage', 'sign-in with GitHub failed: $reason');
      _showSnack(reason);
      return;
    }

    final started = await notifier.startGithubDeviceFlow();
    final deviceCode = started.dataOrNull;
    if (!mounted) return;

    if (deviceCode == null) {
      final reason = started.failureOrNull?.message ?? 'تعذّر الاتصال بـ GitHub';
      AppLogger.action('LoginPage', 'sign-in with GitHub failed: $reason');
      _showSnack(reason);
      return;
    }

    final signedIn = await _runDeviceFlow(deviceCode);
    if (!mounted) return;
    if (signedIn) {
      AppLogger.action('LoginPage', 'sign-in with GitHub finished, opening the app');
      context.go(AppRoutes.home);
    }
  }

  /// Runs the device flow. The sheet owns the polling and closes itself as
  /// soon as GitHub answers, so no route is popped from the outside.
  Future<bool> _runDeviceFlow(GithubDeviceCode deviceCode) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      builder: (sheetContext) => _DeviceCodeSheet(
        userCode: deviceCode.userCode,
        verificationUri: deviceCode.verificationUri,
        startFlow: (onPending) =>
            _pollForApproval(deviceCode, onPending),
        onOpenBrowser: () => _openBrowser(deviceCode.verificationUri),
      ),
    );
    return result == true;
  }

  /// Polls GitHub until the user approved the device and signs in.
  Future<bool> _pollForApproval(
    GithubDeviceCode deviceCode,
    void Function(bool pending) onPending,
  ) async {
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .completeGithubDeviceFlow(deviceCode, onPending: onPending);
    return ok;
  }

  Future<void> _openBrowser(String uri) async {
    final url = Uri.tryParse(uri);
    if (url == null) return;
    try {
      final opened =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showSnack('تعذّر فتح المتصفح — افتح $uri يدويًا');
      }
    } catch (error) {
      if (mounted) _showSnack('تعذّر فتح المتصفح — افتح $uri يدويًا');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AppLogo(),
                    ),
                    const SizedBox(height: 40),
                    const _HeroCard(),
                    const SizedBox(height: 32),
                    Text(
                      'فريقك، مهامك، ومستودعك في مكان واحد',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'أنشئ مشروعًا، اربطه بمستودع GitHub، ادعُ فريقك بالإيميل، '
                      'ووزّع المهام وتابعها من الـ PR حتى الدمج.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: isLoading ? null : _continueWithGithub,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : const Icon(Icons.code, size: 20),
                      label: Text(isLoading
                          ? 'جارٍ الاتصال بـ GitHub…'
                          : 'المتابعة باستخدام GitHub'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => setState(() => _showEmailForm = true),
                      child: const Text('الدخول بالبريد الإلكتروني'),
                    ),
                    if (_showEmailForm) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: isLoading ? null : _submitEmailSignIn,
                        child: const Text('تسجيل الدخول'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading ? null : () => context.push(AppRoutes.signUp),
                      child: const Text('إنشاء حساب جديد'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 14, color: AppColors.textDim),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'لن نطلب صلاحيات على أي مستودع الآن — تختار المستودع بنفسك لاحقًا عند ربط المشروع.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textDim,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Decorative card preview shown above the login form.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'معاينة',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'مراجعة',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'صفحة تسجيل الدخول بكود OTP',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _MonoTag(label: 'معاينة الواجهة'),
              const SizedBox(width: 8),
              const Text(
                '4/4 فحوصات ناجحة',
                style: TextStyle(fontSize: 11, color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonoTag extends StatelessWidget {
  const _MonoTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 11,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Bottom sheet shown during the GitHub device flow.
///
/// It starts the polling itself and closes as soon as GitHub approves (or
/// rejects) the device.
class _DeviceCodeSheet extends StatefulWidget {
  const _DeviceCodeSheet({
    required this.userCode,
    required this.verificationUri,
    required this.startFlow,
    required this.onOpenBrowser,
  });

  final String userCode;
  final String verificationUri;

  /// Starts the polling; the returned future resolves with the sign-in result.
  final Future<bool> Function(ValueChanged<bool> onPending) startFlow;

  final VoidCallback onOpenBrowser;

  @override
  State<_DeviceCodeSheet> createState() => _DeviceCodeSheetState();
}

class _DeviceCodeSheetState extends State<_DeviceCodeSheet> {
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    // Start after the first frame: the polling reports progress with
    // setState, which is not allowed while the first frame is building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    bool ok;
    try {
      ok = await widget.startFlow((pending) {
        if (mounted) setState(() => _pending = pending);
      });
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    AppLogger.action(
      'LoginPage',
      ok ? 'sign-in with GitHub: approved' : 'sign-in with GitHub: failed',
    );
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ادخل الكود في GitHub',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'افتح صفحة GitHub واكتب الكود التالي لتأكيد الدخول.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Text(
              widget.userCode,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.onOpenBrowser,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('فتح GitHub'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_pending)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.hourglass_empty_rounded,
                    size: 16, color: AppColors.textDim),
              const SizedBox(width: 8),
              Text(
                _pending ? 'في انتظار موافقتك على GitHub…' : 'لم تبدأ بعد',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
