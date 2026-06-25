import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/appearance_provider.dart';
import '../state/auth_provider.dart';
import 'theme/appearance.dart';
import 'widgets/game_button.dart';

const bool _useEmulator = bool.fromEnvironment('USE_EMULATOR');

/// Opens phone sign-in as a modal bottom sheet. Resolves when dismissed.
Future<void> showSignInSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SignInSheet(),
  );
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
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
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
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+1 415 555 2671',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: withHaptic(state.busy
                ? null
                : () => controller.sendCode(_phoneController.text.trim())),
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
        if (_useEmulator) const _DevAnonButton(),
      ],
    );
  }
}

class _DevAnonButton extends ConsumerWidget {
  const _DevAnonButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(phoneAuthControllerProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: TextButton(
        onPressed: state.busy
            ? null
            : () => ref.read(phoneAuthControllerProvider.notifier).signInDevAccount(),
        child: const Text('Skip login (dev)', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}
