import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_auth_service.dart';

final authServiceProvider = Provider<FirebaseAuthService>((ref) => FirebaseAuthService());

/// The current Firebase user, or null. Drives the signed-in/out UI gates.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

enum PhoneAuthStep { enterPhone, enterCode, signedIn }

class PhoneAuthState {
  final PhoneAuthStep step;
  final String phoneNumber;
  final bool busy;
  final String? error;

  const PhoneAuthState({
    this.step = PhoneAuthStep.enterPhone,
    this.phoneNumber = '',
    this.busy = false,
    this.error,
  });

  PhoneAuthState copyWith({
    PhoneAuthStep? step,
    String? phoneNumber,
    bool? busy,
    String? error,
    bool clearError = false,
  }) =>
      PhoneAuthState(
        step: step ?? this.step,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}

class PhoneAuthController extends Notifier<PhoneAuthState> {
  PhoneCodeHandle? _handle;

  FirebaseAuthService get _service => ref.read(authServiceProvider);

  @override
  PhoneAuthState build() => const PhoneAuthState();

  /// Step 1 — request an SMS code. [phoneNumber] must be E.164 (+countrycode...).
  Future<void> sendCode(String phoneNumber) async {
    state = state.copyWith(busy: true, clearError: true, phoneNumber: phoneNumber);
    try {
      _handle = await _service.sendCode(
        phoneNumber,
        onAutoVerified: () => state = state.copyWith(step: PhoneAuthStep.signedIn, busy: false),
        onError: (msg) => state = state.copyWith(error: msg, busy: false),
      );
      // Auto-verification may have already advanced us to signedIn.
      if (state.step != PhoneAuthStep.signedIn) {
        state = state.copyWith(step: PhoneAuthStep.enterCode, busy: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), busy: false);
    }
  }

  /// Step 2 — confirm the 6-digit SMS code.
  Future<void> verifyCode(String smsCode) async {
    final handle = _handle;
    if (handle == null) {
      state = state.copyWith(error: 'Request a code first.');
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _service.confirmCode(handle, smsCode);
      state = state.copyWith(step: PhoneAuthStep.signedIn, busy: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), busy: false);
    }
  }

  /// Return to the phone-entry step (e.g. wrong number, or "resend").
  void reset() {
    _handle = null;
    state = const PhoneAuthState();
  }

  Future<void> signInDevAccount() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _service.signInDevAccount();
    } catch (e) {
      state = state.copyWith(error: e.toString(), busy: false);
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    reset();
  }
}

final phoneAuthControllerProvider =
    NotifierProvider<PhoneAuthController, PhoneAuthState>(PhoneAuthController.new);
