import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth_provider.dart';
import 'widgets/game_button.dart';

/// Phone-only sign in: enter number → enter SMS code. Validates the Firebase
/// auth plumbing; styling is intentionally minimal until the Phase 4 theme pass.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
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
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    final onCodeStep = state.step == PhoneAuthStep.enterCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('♠ Blackjack 101 ♥',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 24)),
                const SizedBox(height: 24),
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
                  Text('Code sent to ${state.phoneNumber}',
                      textAlign: TextAlign.center),
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
            ),
          ),
        ),
      ),
    );
  }
}
