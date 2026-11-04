import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sixdx/core/errors/failures.dart';
import 'package:sixdx/core/utils/result.dart';
import 'package:sixdx/features/auth/domain/entities/auth_user.dart';
import 'package:sixdx/features/auth/domain/entities/github_device_code.dart';
import 'package:sixdx/features/auth/domain/repositories/auth_repository.dart';
import 'package:sixdx/features/auth/presentation/pages/login_page.dart';
import 'package:sixdx/features/auth/presentation/providers/auth_providers.dart';

/// A repository that records what the login screen asks for.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.failAtStart = false,
    this.approval,
    this.usesDeviceCode = true,
    this.browserSignInFails = false,
  });

  final bool failAtStart;

  /// When set, the sign-in waits for this completer, so the test controls
  /// when GitHub "approves" the device.
  final Completer<bool>? approval;

  /// `false` mimics the browser based backend (Supabase).
  final bool usesDeviceCode;

  final bool browserSignInFails;

  int startCalls = 0;
  int completeCalls = 0;
  int browserCalls = 0;

  @override
  bool get usesGithubDeviceCode => usesDeviceCode;

  @override
  Future<Result<AuthUser>> signInWithGithub() async {
    browserCalls++;
    if (browserSignInFails) {
      return const Result.failure(Failure.network('تعذّر تسجيل الدخول'));
    }
    return const Result.success(
      AuthUser(id: '42', login: 'sami', name: 'Sami'),
    );
  }

  @override
  Future<Result<GithubDeviceCode>> startGithubDeviceFlow() async {
    startCalls++;
    if (failAtStart) {
      return const Result.failure(Failure.network('تعذّر الاتصال'));
    }
    return const Result.success(
      GithubDeviceCode(
        deviceCode: 'device-123',
        userCode: 'ABCD-1234',
        verificationUri: 'https://github.com/login/device',
        interval: 1,
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<Result<AuthUser>> completeGithubDeviceFlow(
    GithubDeviceCode deviceCode, {
    void Function(bool pending)? onPending,
  }) async {
    completeCalls++;
    onPending?.call(true);
    final approved = approval == null ? true : await approval!.future;
    if (!approved) {
      return const Result.failure(Failure.network('تعذّر تسجيل الدخول'));
    }
    return const Result.success(
      AuthUser(id: '42', login: 'sami', name: 'Sami'),
    );
  }

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      const Result.failure(Failure.unknown('not used'));

  @override
  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      const Result.failure(Failure.unknown('not used'));

  @override
  Future<Result<AuthUser>> verifyOtp({
    required String email,
    required String otp,
  }) async =>
      const Result.failure(Failure.unknown('not used'));

  @override
  Future<Result<AuthUser?>> currentUser() async => const Result.success(null);

  @override
  Future<Result<void>> signOut() async => const Result.success(null);
}

Future<void> _pumpLogin(WidgetTester tester, _FakeAuthRepository repository) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('HOME_SCREEN')),
      ),
    ],
  );

  return tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  testWidgets('the GitHub button starts the device flow and shows the user code',
      (tester) async {
    final repository = _FakeAuthRepository(approval: Completer<bool>());
    await _pumpLogin(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('المتابعة باستخدام GitHub'));
    // The sheet contains a progress indicator, so pumpAndSettle would never
    // return: pump a fixed number of frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.startCalls, 1);
    // The sheet shows the code the user has to type on github.com.
    expect(find.text('ABCD-1234'), findsOneWidget);
    expect(find.text('فتح GitHub'), findsOneWidget);
  });

  testWidgets('a successful sign-in navigates to the home screen',
      (tester) async {
    final approval = Completer<bool>();
    final repository = _FakeAuthRepository(approval: approval);
    await _pumpLogin(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('المتابعة باستخدام GitHub'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ABCD-1234'), findsOneWidget);

    // The user approves the device on github.com.
    approval.complete(true);
    await tester.pump();
    // the sheet closing animation + the route transition
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(repository.completeCalls, 1);
    expect(find.text('HOME_SCREEN'), findsOneWidget);
  });

  testWidgets('a failed attempt leaves the button usable again', (tester) async {
    final repository = _FakeAuthRepository(failAtStart: true);
    await _pumpLogin(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('المتابعة باستخدام GitHub'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.startCalls, 1);
    expect(find.text('المتابعة باستخدام GitHub'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'المتابعة باستخدام GitHub'),
    );
    expect(button.onPressed, isNotNull,
        reason: 'the button must not stay disabled after a failure');
  });

  testWidgets('the browser flow (Supabase) signs in without a device code',
      (tester) async {
    final repository = _FakeAuthRepository(usesDeviceCode: false);
    await _pumpLogin(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('المتابعة باستخدام GitHub'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(repository.browserCalls, 1);
    // No device code sheet: the browser owns the flow.
    expect(repository.startCalls, 0);
    expect(find.text('فتح GitHub'), findsNothing);
    expect(find.text('HOME_SCREEN'), findsOneWidget);
  });

  testWidgets('a browser sign-in failure shows the reason and stays usable',
      (tester) async {
    final repository = _FakeAuthRepository(
      usesDeviceCode: false,
      browserSignInFails: true,
    );
    await _pumpLogin(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('المتابعة باستخدام GitHub'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(repository.browserCalls, 1);
    expect(find.text('تعذّر تسجيل الدخول'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'المتابعة باستخدام GitHub'),
    );
    expect(button.onPressed, isNotNull);
  });
}
