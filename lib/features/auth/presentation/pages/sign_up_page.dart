import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_router.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../providers/auth_providers.dart';

@RoutePage()
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    AppLogger.action('SignUpPage', 'tapped "send the verification code" for $email');
    final ok = await ref.read(authNotifierProvider.notifier).register(
          email: email,
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      // The OTP screen needs the address the code was sent to.
      ref.read(pendingSignupEmailProvider.notifier).set(email);
      context.push(AppRoutes.verifyOtp);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر إنشاء الحساب')),
      );
    }
  }

  Future<void> _continueWithGithub() async {
    AppLogger.action('SignUpPage', 'tapped "continue with GitHub"');
    final result = await ref.read(authNotifierProvider.notifier).signInWithGithub();
    if (!mounted) return;
    if (result.dataOrNull != null) {
      context.go(AppRoutes.home);
      return;
    }
    final reason = result.failureOrNull?.message ?? 'تعذّر الاتصال بـ GitHub';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(reason)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أنشئ حسابك',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'بدون كلمة مرور — سنرسل لك كودًا من 6 أرقام كل مرة تدخل.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'أدخل الاسم' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'إيميل العمل'),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'أدخل البريد الإلكتروني';
                    if (!email.contains('@')) return 'بريد إلكتروني غير صالح';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'استخدم نفس الإيميل الذي وصلتك عليه الدعوة، حتى تنضم لفريقك مباشرة.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    helperText: '8 أحرف على الأقل',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.length < 8) {
                      return 'كلمة المرور لا تقل عن 8 أحرف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: isLoading ? null : _sendCode,
                  child: const Text('إرسال كود التحقق'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('أو', style: Theme.of(context).textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _continueWithGithub,
                  icon: const Icon(Icons.code, size: 20),
                  label: const Text('المتابعة باستخدام GitHub'),
                ),
                const SizedBox(height: 24),
                Text(
                  'بالمتابعة أنت توافق على شروط الاستخدام وسياسة الخصوصية.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
