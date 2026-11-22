import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'data/school_registry.dart';

class SchoolRegistrationPage extends StatefulWidget {
  const SchoolRegistrationPage({
    super.key,
    required this.loadApplication,
    required this.submit,
  });

  final Future<SchoolApplication?> Function() loadApplication;
  final Future<void> Function(SchoolApplicationDraft) submit;

  @override
  State<SchoolRegistrationPage> createState() => _SchoolRegistrationPageState();
}

class _SchoolRegistrationPageState extends State<SchoolRegistrationPage> {
  static final _domainPattern = RegExp(
    r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
  );
  static final _emailPattern = RegExp(r'^[^\s@<>]+@[a-z0-9.-]+$');
  static final _colorPattern = RegExp(r'^#?[0-9a-fA-F]{6}$');

  final _formKey = GlobalKey<FormState>();
  final _schoolName = TextEditingController();
  final _location = TextEditingController();
  final _domain = TextEditingController();
  final _applicantName = TextEditingController();
  final _role = TextEditingController();
  final _contact = TextEditingController();
  final _color = TextEditingController();
  late Future<SchoolApplication?> _application;
  String? _submittedSchool;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _application = widget.loadApplication();
  }

  @override
  void dispose() {
    _schoolName.dispose();
    _location.dispose();
    _domain.dispose();
    _applicantName.dispose();
    _role.dispose();
    _contact.dispose();
    _color.dispose();
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().length < 2
      ? 'Enter at least 2 characters.'
      : null;

  String? _validateDomain(String? value) {
    final domain = (value ?? '').trim().toLowerCase();
    return _domainPattern.hasMatch(domain)
        ? null
        : 'Enter a domain like school.edu.';
  }

  String? _validateContact(String? value) {
    final email = (value ?? '').trim().toLowerCase();
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid school email.';
    final domain = _domain.text.trim().toLowerCase();
    if (_domainPattern.hasMatch(domain) && email.split('@').last != domain) {
      return 'Use an email from the school domain above.';
    }
    return null;
  }

  String? _validateColor(String? value) {
    final color = (value ?? '').trim();
    return color.isEmpty || _colorPattern.hasMatch(color)
        ? null
        : 'Enter a six-digit color like #244A73.';
  }

  String _normalizedColor(String input) {
    final color = input.trim().replaceFirst('#', '').toUpperCase();
    return color.isEmpty ? schoolRegistrationDefaultColor : '#$color';
  }

  Future<void> _submit() async {
    if (_submitting || _formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    final draft = SchoolApplicationDraft(
      schoolName: _schoolName.text.trim(),
      applicantName: _applicantName.text.trim(),
      applicantRole: _role.text.trim(),
      contactEmail: _contact.text.trim().toLowerCase(),
      emailDomain: _domain.text.trim().toLowerCase(),
      location: _location.text.trim(),
      color: _normalizedColor(_color.text),
    );
    setState(() => _submitting = true);
    try {
      await widget.submit(draft);
      if (mounted) setState(() => _submittedSchool = draft.schoolName);
    } on SchoolRegistrationException catch (error) {
      SchoolApplication? existing;
      try {
        existing = await widget.loadApplication();
      } catch (_) {
        // Preserve the submission error when status cannot be refreshed.
      }
      if (mounted && existing != null) {
        setState(() => _application = Future.value(existing));
      } else if (mounted) {
        showAppError(context, error.message);
      }
    } catch (_) {
      if (mounted) showAppError(context, 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required int limit,
    String? hint,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.words,
    Widget? suffix,
    bool last = false,
  }) => TextFormField(
    controller: controller,
    enabled: !_submitting,
    textCapitalization: capitalization,
    textInputAction: last ? TextInputAction.done : TextInputAction.next,
    keyboardType: keyboardType,
    autocorrect: keyboardType != TextInputType.emailAddress,
    inputFormatters: [LengthLimitingTextInputFormatter(limit)],
    validator: validator,
    onFieldSubmitted: last ? (_) => _submit() : null,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      errorMaxLines: 2,
    ),
  );

  Widget _receipt(String school, SchoolApplicationStatus status) {
    final (headline, detail, icon) = switch (status) {
      SchoolApplicationStatus.pending => (
        'Application submitted',
        'Your school will appear in Find your school after approval.',
        Icons.hourglass_empty_rounded,
      ),
      SchoolApplicationStatus.approved => (
        'Application approved',
        'Your school is listed in Find your school.',
        Icons.check_circle_outline_rounded,
      ),
      SchoolApplicationStatus.rejected => (
        'Application declined',
        null,
        Icons.info_outline_rounded,
      ),
    };
    final theme = Theme.of(context);
    return ContentColumn(
      maxWidth: 540,
      children: [
        const SizedBox(height: 18),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Icon(icon, size: 28, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 16),
        Text(headline, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 6),
        Text(school, style: theme.textTheme.titleMedium),
        if (detail != null) ...[
          const SizedBox(height: 10),
          Text(detail, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 24),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _colorSwatch() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _color,
    builder: (context, value, _) {
      final code = _normalizedColor(value.text).substring(1);
      final parsed = code.length == 6 ? int.tryParse(code, radix: 16) : null;
      return Center(
        widthFactor: 1,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: parsed == null
                ? Theme.of(context).colorScheme.outlineVariant
                : Color(0xff000000 | parsed),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: const SizedBox.square(dimension: 18),
        ),
      );
    },
  );

  Widget _form() => Form(
    key: _formKey,
    child: ContentColumn(
      maxWidth: 540,
      children: [
        _field(
          controller: _schoolName,
          label: 'School name',
          limit: 120,
          validator: _required,
        ),
        const SizedBox(height: 14),
        _field(
          controller: _location,
          label: 'City or region (optional)',
          limit: 120,
        ),
        const SizedBox(height: 14),
        _field(
          controller: _domain,
          label: 'School email domain',
          hint: 'school.edu',
          limit: 253,
          keyboardType: TextInputType.emailAddress,
          capitalization: TextCapitalization.none,
          validator: _validateDomain,
        ),
        const SizedBox(height: 14),
        _field(
          controller: _contact,
          label: 'School contact email',
          limit: 254,
          keyboardType: TextInputType.emailAddress,
          capitalization: TextCapitalization.none,
          validator: _validateContact,
        ),
        const SizedBox(height: 14),
        _field(
          controller: _color,
          label: 'School color (optional)',
          hint: schoolRegistrationDefaultColor,
          limit: 7,
          capitalization: TextCapitalization.characters,
          validator: _validateColor,
          suffix: _colorSwatch(),
        ),
        const SizedBox(height: 14),
        _field(
          controller: _applicantName,
          label: 'Your full name',
          limit: 80,
          validator: _required,
        ),
        const SizedBox(height: 14),
        _field(
          controller: _role,
          label: 'Your role at the school',
          limit: 80,
          validator: _required,
          last: true,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Submitting application',
                  ),
                )
              : const Text('Submit for review'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final submittedSchool = _submittedSchool;
    return Scaffold(
      appBar: AppBar(title: const Text('Register a school')),
      body: SafeArea(
        top: false,
        child: submittedSchool != null
            ? _receipt(submittedSchool, SchoolApplicationStatus.pending)
            : FutureBuilder<SchoolApplication?>(
                future: _application,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ContentColumn(
                      maxWidth: 540,
                      children: [
                        const Text('Could not load your application.'),
                        TextButton(
                          onPressed: () => setState(
                            () => _application = widget.loadApplication(),
                          ),
                          child: const Text('Try again'),
                        ),
                      ],
                    );
                  }
                  final application = snapshot.data;
                  return application == null
                      ? _form()
                      : _receipt(
                          application.draft.schoolName,
                          application.status,
                        );
                },
              ),
      ),
    );
  }
}
