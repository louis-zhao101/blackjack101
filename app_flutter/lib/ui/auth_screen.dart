import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../services/firebase_auth_service.dart';
import '../state/appearance_provider.dart';
import '../state/auth_provider.dart';
import 'theme/appearance.dart';
import 'widgets/game_button.dart';

/// Opens phone sign-in as a modal bottom sheet. Resolves when dismissed.
Future<void> showSignInSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SignInSheet(),
  );
}

/// Re-verifies the signed-in user with a fresh SMS code, required before
/// destructive actions like account deletion (Firebase's `delete()` needs a
/// recent sign-in). Texts the code to the account's own number, so there's no
/// way to re-auth as a different account. Resolves true only on success.
Future<bool> showReauthSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ReauthSheet(),
  );
  return ok ?? false;
}

class _ReauthSheet extends ConsumerStatefulWidget {
  const _ReauthSheet();

  @override
  ConsumerState<_ReauthSheet> createState() => _ReauthSheetState();
}

class _ReauthSheetState extends ConsumerState<_ReauthSheet> {
  final _codeController = TextEditingController();
  PhoneCodeHandle? _handle;
  bool _busy = true; // starts busy — the code is requested as the sheet opens
  bool _codeSent = false;
  bool _done = false; // guards a double-pop if Android auto-retrieves the code
  String? _error;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final auth = ref.read(authServiceProvider);
    final phone = auth.currentUser?.phoneNumber;
    if (phone == null || phone.isEmpty) {
      if (mounted) Navigator.pop(context, false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final handle = await auth.sendCode(
        phone,
        onAutoVerified: () {
          if (mounted && !_done) {
            _done = true;
            Navigator.pop(context, true);
          }
        },
        onError: (m) {
          if (mounted) {
            setState(() {
              _error = m;
              _busy = false;
            });
          }
        },
      );
      if (!mounted || _done) return;
      setState(() {
        _handle = handle;
        _codeSent = true;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  Future<void> _verify() async {
    final handle = _handle;
    final code = _codeController.text.trim();
    if (handle == null || code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).reauthenticateWithCode(handle, code);
      if (mounted && !_done) {
        _done = true;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final phone = ref.read(authServiceProvider).currentUser?.phoneNumber ?? 'your number';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.feltDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: theme.feltBorder),
            left: BorderSide(color: theme.feltBorder),
            right: BorderSide(color: theme.feltBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTokens.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text('Confirm it\'s you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: theme.gold)),
                const SizedBox(height: 4),
                Text(
                  _codeSent
                      ? 'Enter the code we texted to $phone to permanently delete your account.'
                      : 'Verifying your number to delete your account…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppTokens.textSecondary),
                ),
                const SizedBox(height: 20),
                if (_codeSent) ...[
                  TextField(
                    controller: _codeController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    enabled: !_busy,
                    style: const TextStyle(
                        color: AppTokens.textPrimary, letterSpacing: 4),
                    decoration: const InputDecoration(
                      labelText: '6-digit code',
                      labelStyle: TextStyle(color: AppTokens.textSecondary),
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : withHaptic(_verify),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Confirm & delete'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : withHaptic(_send),
                    child: const Text('Resend code'),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInSheet extends ConsumerWidget {
  const _SignInSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.feltDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: theme.feltBorder),
            left: BorderSide(color: theme.feltBorder),
            right: BorderSide(color: theme.feltBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTokens.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const _SignInForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Phone-only sign in: enter number → enter SMS code.
class _SignInForm extends ConsumerStatefulWidget {
  const _SignInForm();

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final _codeController = TextEditingController();

  // The full E.164 number (dial code + national number), kept fresh via the
  // phone field's onChanged so "Send code" has a ready-to-submit value.
  String _completePhone = '';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Close the sheet once the user is actually signed in.
    ref.listen(authStateProvider, (prev, next) {
      if (next.value != null && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    final theme = ref.watch(appearanceProvider);
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    final onCodeStep = state.step == PhoneAuthStep.enterCode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('♠ Blackjack 101 ♥',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.gold)),
        const SizedBox(height: 4),
        const Text('Sign in to save and view your stats',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTokens.textSecondary)),
        const SizedBox(height: 20),
        if (!onCodeStep) ...[
          IntlPhoneField(
            initialCountryCode: 'US',
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppTokens.textPrimary),
            dropdownTextStyle: const TextStyle(color: AppTokens.textPrimary),
            dropdownIcon: const Icon(Icons.arrow_drop_down, color: AppTokens.textSecondary),
            decoration: const InputDecoration(
              labelText: 'Phone number',
              border: OutlineInputBorder(),
            ),
            onChanged: (phone) => _completePhone = phone.completeNumber,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: withHaptic(state.busy
                ? null
                : () => controller.sendCode(_completePhone.trim())),
            child: state.busy
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send code'),
          ),
        ] else ...[
          Text('Code sent to ${state.phoneNumber}', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(
              labelText: '6-digit code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: withHaptic(state.busy
                ? null
                : () => controller.verifyCode(_codeController.text.trim())),
            child: state.busy
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Verify'),
          ),
          TextButton(
            onPressed: withHaptic(state.busy ? null : controller.reset),
            child: const Text('Use a different number'),
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 16),
          Text(state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}
