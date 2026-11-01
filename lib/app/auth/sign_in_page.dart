import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';
import 'auth_state.dart';

/// Email sign-in and registration.
class SignInPage extends StatefulWidget {
  /// Creates the sign-in page.
  const SignInPage({this.projectLabel = '', super.key});

  /// Shown under the form so it is obvious which project is targeted.
  final String projectLabel;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _register = false;
  var _obscure = true;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, next) =>
          next is AuthSignedOut && next.notice != null,
      listener: (context, state) => setState(() => _register = false),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    children: [
                      Text(
                        'ANYTHINK SAMPLE',
                        style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.4,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Notes', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in against the notes project and read your own '
                        'records. The client underneath is the seed of a Flutter '
                        'package: it stores the session, rotates the refresh '
                        'token, and retries once after a 401.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Sign in')),
                          ButtonSegment(value: true, label: Text('Register')),
                        ],
                        selected: {_register},
                        onSelectionChanged: (selection) {
                          setState(() => _register = selection.first);
                        },
                      ),
                      const SizedBox(height: 20),
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          final signedOut = state is AuthSignedOut
                              ? state
                              : const AuthSignedOut();
                          return Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (signedOut.notice != null) ...[
                                  _Banner(
                                    text: signedOut.notice!,
                                    tone: _BannerTone.notice,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (signedOut.message != null) ...[
                                  _Banner(
                                    text: signedOut.message!,
                                    tone: _BannerTone.error,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (_register) ...[
                                  TextFormField(
                                    controller: _firstName,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'First name',
                                    ),
                                    validator: (value) =>
                                        _required(value, 'Enter a first name.'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _lastName,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Last name',
                                    ),
                                    validator: (value) =>
                                        _required(value, 'Enter a last name.'),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                  ),
                                  validator: _emailRule,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  autofillHints: _register
                                      ? const [AutofillHints.newPassword]
                                      : const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(signedOut),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) => _register
                                      ? _passwordRule(value)
                                      : _required(
                                          value,
                                          'Enter your password.',
                                        ),
                                ),
                                if (_register) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'At least 8 characters, with upper and lower '
                                    'case, a number and a symbol.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: signedOut.submitting
                                      ? null
                                      : () => _submit(signedOut),
                                  child: signedOut.submitting
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _register
                                              ? 'Create account'
                                              : 'Sign in',
                                        ),
                                ),
                                if (widget.projectLabel.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    widget.projectLabel,
                                    style: theme.textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _submit(AuthSignedOut state) {
    if (state.submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final cubit = context.read<AuthCubit>();
    if (_register) {
      cubit.register(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      return;
    }
    cubit.signIn(email: _email.text.trim(), password: _password.text);
  }
}

enum _BannerTone { error, notice }

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.tone});

  final String text;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = tone == _BannerTone.error;
    final color = error ? theme.colorScheme.error : theme.colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}

String? _required(String? value, String message) {
  if (value == null || value.trim().isEmpty) {
    return message;
  }
  return null;
}

String? _emailRule(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return 'Enter an email address.';
  }
  final at = text.indexOf('@');
  if (at <= 0 || !text.substring(at).contains('.')) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? _passwordRule(String? value) {
  final text = value ?? '';
  if (text.length < 8 ||
      !text.contains(RegExp('[a-z]')) ||
      !text.contains(RegExp('[A-Z]')) ||
      !text.contains(RegExp('[0-9]')) ||
      !text.contains(RegExp(r'[^A-Za-z0-9]'))) {
    return 'Password does not meet the rules below.';
  }
  return null;
}
