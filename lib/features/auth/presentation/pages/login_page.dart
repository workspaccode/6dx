import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_logo.dart';
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

  Future<void> _continueWithGithub() async {
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .signInWithGithub(code: 'device-flow');
    if (!mounted) return;
    if (ok) {
      context.go(AppRoutes.home);
    } else {
      _showSnack('تعذّر الاتصال بـ GitHub');
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
                      icon: const Icon(Icons.code, size: 20),
                      label: const Text('المتابعة باستخدام GitHub'),
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
