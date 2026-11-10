import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'local_accounts.dart';
import 'school_demo.dart';

enum _AuthStep { login, first, forgot, password, name }

class SchoolAuthPage extends StatefulWidget {
  const SchoolAuthPage({
    super.key,
    required this.school,
    required this.accounts,
  });
  final DemoSchool school;
  final LocalAccounts accounts;
  @override
  State<SchoolAuthPage> createState() => _SchoolAuthPageState();
}

class _SchoolAuthPageState extends State<SchoolAuthPage> {
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController(),
      _name = TextEditingController();
  _AuthStep _step = _AuthStep.login;
  int _grade = 11;
  bool _busy = false, _hidden = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(_AuthStep step) => setState(() {
    _step = step;
    _error = null;
  });
  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await widget.accounts.login(_email.text, _password.text);
      if (mounted) Navigator.pop(context, account);
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not log in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await widget.accounts.create(
        username: _email.text,
        password: _password.text,
        name: _name.text,
        grade: _grade,
      );
      if (mounted) Navigator.pop(context, account);
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save your account. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _requestEmail() {
    try {
      widget.accounts.emailFor(_email.text);
      setState(
        () =>
            _error = 'Email service is not configured. No email has been sent.',
      );
    } on AccountException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Widget _field(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 10),
      Semantics(label: label, child: child),
    ],
  );
  Widget _schoolEmail() => _field(
    'School email',
    DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _email,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Username',
                semanticCounterText: 'School email username',
              ),
              onSubmitted: (_) {
                if (_step == _AuthStep.login) _login();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '@${schoolEmailDomain(widget.school)}',
              key: const ValueKey('fixed-email-domain'),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _AuthStep.login => 'Welcome back',
      _AuthStep.first => 'First login',
      _AuthStep.forgot => 'Forgot password',
      _AuthStep.password => 'Set a demo password',
      _AuthStep.name => 'Your real name',
    };
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (_step == _AuthStep.login) {
              Navigator.pop(context);
            } else {
              _go(_AuthStep.login);
            }
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, size) => SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: CompassWordmark(size: 26)),
                          const SizedBox(height: 12),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SchoolMark(school: widget.school, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  shortSchoolName(widget.school),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 30),
                          if (_step == _AuthStep.login ||
                              _step == _AuthStep.first ||
                              _step == _AuthStep.forgot)
                            _schoolEmail(),
                          if (_step == _AuthStep.login ||
                              _step == _AuthStep.password) ...[
                            if (_step == _AuthStep.login)
                              const SizedBox(height: 24),
                            _field(
                              'Password',
                              TextField(
                                controller: _password,
                                obscureText: _hidden,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  suffixIcon: IconButton(
                                    tooltip: _hidden
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () =>
                                        setState(() => _hidden = !_hidden),
                                    icon: Icon(
                                      _hidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) {
                                  if (_step == _AuthStep.login) _login();
                                },
                              ),
                            ),
                            if (_step == _AuthStep.password) ...[
                              const SizedBox(height: 24),
                              _field(
                                'Confirm password',
                                TextField(
                                  controller: _confirm,
                                  obscureText: true,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                ),
                              ),
                            ],
                          ],
                          if (_step == _AuthStep.name) ...[
                            _field(
                              'Full name',
                              TextField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 60,
                                decoration: const InputDecoration(
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _field(
                              'Grade',
                              DropdownButtonFormField<int>(
                                initialValue: _grade,
                                items: [
                                  for (var g = 9; g <= 12; g++)
                                    DropdownMenuItem(
                                      value: g,
                                      child: Text('Grade $g'),
                                    ),
                                ],
                                onChanged: (g) => setState(() => _grade = g!),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 20),
                            Text(
                              _error!,
                              key: const ValueKey('auth-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 36),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : switch (_step) {
                                    _AuthStep.login => _login,
                                    _AuthStep.first ||
                                    _AuthStep.forgot => _requestEmail,
                                    _AuthStep.password => () {
                                      if (_password.text.length < 10 ||
                                          _password.text.length > 128) {
                                        setState(
                                          () =>
                                              _error = 'Use 10–128 characters.',
                                        );
                                        return;
                                      }
                                      if (_password.text != _confirm.text) {
                                        setState(
                                          () => _error =
                                              'The passwords do not match.',
                                        );
                                        return;
                                      }
                                      _go(_AuthStep.name);
                                    },
                                    _AuthStep.name => _create,
                                  },
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(switch (_step) {
                                    _AuthStep.login => 'Log in',
                                    _AuthStep.first => 'Send setup email',
                                    _AuthStep.forgot => 'Send reset email',
                                    _AuthStep.password => 'Continue',
                                    _AuthStep.name => 'Create demo account',
                                  }),
                          ),
                          if (_step == _AuthStep.first) ...[
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: () {
                                try {
                                  widget.accounts.emailFor(_email.text);
                                  _go(_AuthStep.password);
                                } on AccountException catch (e) {
                                  setState(() => _error = e.message);
                                }
                              },
                              child: const Text('Set up a local demo account'),
                            ),
                          ],
                          const SizedBox(height: 40),
                          if (_step == _AuthStep.login) const Spacer(),
                          if (_step == _AuthStep.login)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => _go(_AuthStep.forgot),
                                  child: const Text('Forgot password'),
                                ),
                                TextButton(
                                  onPressed: () => _go(_AuthStep.first),
                                  child: const Text('First login'),
                                ),
                              ],
                            ),
                          if (_step == _AuthStep.password)
                            Text(
                              'Use a password only for this demo.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
