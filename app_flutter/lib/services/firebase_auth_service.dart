import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Opaque handle returned after a code is requested. Carries whatever the
/// underlying platform needs to later confirm the SMS code:
///  - mobile: a verificationId string
///  - web: a ConfirmationResult
class PhoneCodeHandle {
  final String? verificationId; // mobile
  final ConfirmationResult? confirmationResult; // web
  const PhoneCodeHandle({this.verificationId, this.confirmationResult});
}

/// Thin wrapper over FirebaseAuth that hides the mobile/web phone-auth split.
class FirebaseAuthService {
  final FirebaseAuth _auth;
  FirebaseAuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Requests an SMS code for [phoneNumber] (E.164, e.g. +14155552671).
  ///
  /// On mobile, [onAutoVerified] may fire when the device auto-retrieves the
  /// code (Android) — in that case the user is signed in without entering a code.
  /// Returns a handle used by [confirmCode]. On web, auto-verification never
  /// happens and reCAPTCHA is presented by the SDK.
  Future<PhoneCodeHandle> sendCode(
    String phoneNumber, {
    void Function()? onAutoVerified,
    void Function(String message)? onError,
  }) async {
    if (kIsWeb) {
      final result = await _auth.signInWithPhoneNumber(phoneNumber);
      return PhoneCodeHandle(confirmationResult: result);
    }

    final completer = Completer<PhoneCodeHandle>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        onAutoVerified?.call();
      },
      verificationFailed: (FirebaseAuthException e) {
        final msg = _friendlyError(e);
        onError?.call(msg);
        if (!completer.isCompleted) completer.completeError(msg);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(PhoneCodeHandle(verificationId: verificationId));
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) {
          completer.complete(PhoneCodeHandle(verificationId: verificationId));
        }
      },
    );
    return completer.future;
  }

  /// Confirms the [smsCode] against a handle from [sendCode]; signs the user in.
  Future<void> confirmCode(PhoneCodeHandle handle, String smsCode) async {
    try {
      if (handle.confirmationResult != null) {
        await handle.confirmationResult!.confirm(smsCode);
        return;
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: handle.verificationId!,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That phone number looks invalid. Include the country code, e.g. +1.';
      case 'invalid-verification-code':
        return 'That code is incorrect. Double-check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a bit and try again.';
      case 'session-expired':
        return 'The code expired. Request a new one.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
