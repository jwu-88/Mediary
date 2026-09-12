import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_interactions.dart';
import 'app_layout.dart';
import 'app_theme.dart';
import 'in_app_page.dart';
import 'liquid_glass_back_button.dart';
import 'profile_image_policy.dart';

String? validateProfilePhotoUrl(String? value) =>
    validateProfileImageUrl(value);

class ProfileDraft {
  const ProfileDraft({
    required this.name,
    required this.email,
    required this.bloodType,
    required this.allergies,
    required this.careTeam,
    this.photoUrl,
  });

  final String name;
  final String email;
  final String bloodType;
  final List<String> allergies;
  final String careTeam;
  final String? photoUrl;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    this.pageTitle = 'Account',
    this.displayName,
    this.photoUrl,
    this.initialBloodType,
    this.initialAllergies,
    this.initialCareTeam,
    this.activeMedicationCount = 0,
    this.activeMedicationNames = const [],
    this.onOpenLibrary,
    this.onOpenSettings,
    this.onBack,
    this.onSignOut,
    this.onSave,
    this.bottomPadding = 120,
  });

  final String email;
  final String pageTitle;
  final String? displayName;
  final String? photoUrl;
  final String? initialBloodType;
  final List<String>? initialAllergies;
  final String? initialCareTeam;
  final int activeMedicationCount;
  final List<String> activeMedicationNames;
  final VoidCallback? onOpenLibrary;

  /// Retained for callers that have not yet migrated to the Settings shell.
  /// Account no longer presents a nested Settings row.
  final VoidCallback? onOpenSettings;
  final VoidCallback? onBack;
  final Future<void> Function()? onSignOut;
  final Future<void> Function(ProfileDraft draft)? onSave;
  final double bottomPadding;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _red = Color(0xFFC9342C);
  static const _bloodTypes = ['A+', 'A−', 'B+', 'B−', 'O+', 'O−', 'AB+', 'AB−'];

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _careTeamController;
  late final FocusNode _nameFocus;
  late final FocusNode _emailFocus;
  late final FocusNode _careTeamFocus;

  late String _savedName;
  late String _savedEmail;
  String? _savedPhotoUrl;
  late String _savedBloodType;
  late List<String> _savedAllergies;
  late String _savedCareTeam;

  String _draftBloodType = 'O+';
  List<String> _draftAllergies = [];
  String? _draftPhotoUrl;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isSigningOut = false;
  String? _nameError;
  String? _emailError;
  String? _careTeamError;
  String? _saveError;
  String? _inlineFeedback;
  bool _inlineFeedbackIsError = false;
  String _announcement = '';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _isDark ? AppColors.darkBackground : const Color(0xFFF2F2F7);
  Color get _surface => _isDark ? AppColors.darkSurface : Colors.white;
  Color get _ink => _isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
  Color get _muted =>
      _isDark ? const Color(0xFFB8B8BE) : const Color(0xFF515157);
  Color get _line =>
      _isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD9D9DE);

  @override
  void initState() {
    super.initState();
    final displayName = widget.displayName?.trim();
    _savedName = displayName == null || displayName.isEmpty
        ? _nameFromEmail(widget.email)
        : displayName;
    _savedEmail = widget.email;
    _savedPhotoUrl = widget.photoUrl;
    _savedBloodType = widget.initialBloodType ?? 'O+';
    _savedAllergies = [...(widget.initialAllergies ?? const [])];
    _savedCareTeam = widget.initialCareTeam ?? '';
    _draftPhotoUrl = _savedPhotoUrl;
    _nameController = TextEditingController(text: _savedName);
    _emailController = TextEditingController(text: _savedEmail);
    _careTeamController = TextEditingController(text: _savedCareTeam);
    _nameFocus = FocusNode()..addListener(_validateNameOnBlur);
    _emailFocus = FocusNode()..addListener(_validateEmailOnBlur);
    _careTeamFocus = FocusNode()..addListener(_validateCareTeamOnBlur);
  }

  @override
  void dispose() {
    _nameFocus
      ..removeListener(_validateNameOnBlur)
      ..dispose();
    _emailFocus
      ..removeListener(_validateEmailOnBlur)
      ..dispose();
    _careTeamFocus
      ..removeListener(_validateCareTeamOnBlur)
      ..dispose();
    _nameController.dispose();
    _emailController.dispose();
    _careTeamController.dispose();
    super.dispose();
  }

  String _nameFromEmail(String email) {
    final name = email.split('@').first.trim();
    return name.isEmpty ? 'Your name' : name;
  }

  String get _initials {
    final parts = _savedName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  void _announce(String message) {
    setState(() => _announcement = message);
  }

  void _validateNameOnBlur() {
    if (_isEditing && !_nameFocus.hasFocus) _validateName();
  }

  void _validateEmailOnBlur() {
    if (_isEditing && !_emailFocus.hasFocus) _validateEmail();
  }

  void _validateCareTeamOnBlur() {
    if (_isEditing && !_careTeamFocus.hasFocus) _validateCareTeam();
  }

  bool _validateName() {
    final error = _nameController.text.trim().length < 2
        ? 'Enter your full name.'
        : null;
    setState(() => _nameError = error);
    return error == null;
  }

  bool _validateEmail() {
    final value = _emailController.text.trim();
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    setState(() => _emailError = valid ? null : 'Enter a valid email address.');
    return valid;
  }

  bool _validateCareTeam() {
    final value = _careTeamController.text.trim();
    final error = value.isNotEmpty && value.length < 2
        ? 'Enter a care team or provider.'
        : null;
    setState(() => _careTeamError = error);
    return error == null;
  }

  void _startEditing() {
    _nameController.text = _savedName;
    _emailController.text = _savedEmail;
    _careTeamController.text = _savedCareTeam;
    setState(() {
      _draftBloodType = _savedBloodType;
      _draftAllergies = [..._savedAllergies];
      _draftPhotoUrl = _savedPhotoUrl;
      _nameError = null;
      _emailError = null;
      _careTeamError = null;
      _saveError = null;
      _inlineFeedback = null;
      _announcement = 'Profile editing mode. Name field focused.';
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  bool get _hasUnsavedChanges =>
      _nameController.text != _savedName ||
      _emailController.text != _savedEmail ||
      _careTeamController.text != _savedCareTeam ||
      _draftBloodType != _savedBloodType ||
      _draftPhotoUrl != _savedPhotoUrl ||
      !_sameItems(_draftAllergies, _savedAllergies);

  bool _sameItems(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void _exitEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isEditing = false;
      _isSaving = false;
      _nameError = null;
      _emailError = null;
      _careTeamError = null;
      _saveError = null;
      _draftPhotoUrl = _savedPhotoUrl;
      _announcement = 'Editing cancelled.';
    });
  }

  Future<void> _cancelEditing() async {
    if (!_hasUnsavedChanges) {
      _exitEditing();
      return;
    }

    FocusScope.of(context).unfocus();
    final discard = await pushInAppPage<bool>(
      context,
      builder: (context) => const KeyedSubtree(
        key: Key('discardProfileChangesPage'),
        child: InAppOptionPage<bool>(
          title: 'Discard Changes?',
          subtitle: 'Your profile edits will not be saved.',
          options: [
            InAppPageOption(
              label: 'Keep Editing',
              value: false,
              icon: CupertinoIcons.pencil,
            ),
            InAppPageOption(
              label: 'Discard Changes',
              value: true,
              icon: CupertinoIcons.trash,
              destructive: true,
            ),
          ],
        ),
      ),
    );
    if (discard == true && mounted) _exitEditing();
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final valid = _validateName() & _validateEmail() & _validateCareTeam();
    if (!valid) {
      _announce('Profile could not be saved. Check the highlighted fields.');
      if (_nameError != null) {
        _nameFocus.requestFocus();
      } else if (_emailError != null) {
        _emailFocus.requestFocus();
      } else {
        _careTeamFocus.requestFocus();
      }
      return;
    }

    final draft = ProfileDraft(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      bloodType: _draftBloodType,
      allergies: List.unmodifiable(_draftAllergies),
      careTeam: _careTeamController.text.trim(),
      photoUrl: _draftPhotoUrl,
    );
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onSave?.call(draft);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _savedName = draft.name;
        _savedEmail = draft.email;
        _savedBloodType = draft.bloodType;
        _savedAllergies = [...draft.allergies];
        _savedCareTeam = draft.careTeam;
        _savedPhotoUrl = draft.photoUrl;
        _isSaving = false;
        _isEditing = false;
        _announcement = 'Profile saved.';
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message.toString()
          : 'Profile could not be saved. Try again.';
      setState(() {
        _isSaving = false;
        _saveError = message;
        _announcement =
            'Profile could not be saved. Your changes are preserved.';
      });
    }
  }

  Future<void> _addAllergy() async {
    final controller = TextEditingController();
    final allergy = await pushInAppPage<String>(
      context,
      builder: (context) => InAppPageScaffold(
        title: 'Add Allergy',
        child: ListView(
          key: const Key('addAllergyPage'),
          children: [
            const _ProfilePageLead(
              icon: CupertinoIcons.bandage,
              title: 'Record an Allergy',
              body: 'Add a medication or ingredient you need to avoid.',
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('allergyField'),
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Allergy Name',
                hintText: 'For example, Penicillin',
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('confirmAddAllergyButton'),
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Add Allergy'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    final value = allergy?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    final duplicate = _draftAllergies.any(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    if (!duplicate) setState(() => _draftAllergies.add(value));
  }

  Future<void> _changeProfilePhoto() async {
    final controller = TextEditingController(text: _draftPhotoUrl ?? '');
    final formKey = GlobalKey<FormState>();
    final photoUrl = await pushInAppPage<String>(
      context,
      builder: (context) => InAppPageScaffold(
        title: 'Profile Photo',
        child: Form(
          key: formKey,
          child: ListView(
            key: const Key('profilePhotoPage'),
            children: [
              const _ProfilePageLead(
                icon: CupertinoIcons.person_crop_circle,
                title: 'Choose Your Photo',
                body:
                    'Paste a Mediary Storage or Google account image link, '
                    'or display your initials.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('profilePhotoUrlField'),
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                validator: validateProfilePhotoUrl,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://firebasestorage.googleapis.com/…',
                ),
                onFieldSubmitted: (value) {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(context, value.trim());
                  }
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('saveProfilePhotoButton'),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
                child: const Text('Save Photo'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const Key('useProfileInitialsButton'),
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('Use Initials'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (photoUrl == null || !mounted) return;
    setState(() {
      _draftPhotoUrl = photoUrl.isEmpty ? null : photoUrl;
      _announcement = photoUrl.isEmpty
          ? 'Profile photo removed.'
          : 'Profile photo updated.';
    });
  }

  Future<void> _openInfoPage({
    required String title,
    required String body,
    String? copyText,
  }) async {
    final copied = await pushInAppPage<bool>(
      context,
      builder: (context) => InAppPageScaffold(
        title: title,
        child: ListView(
          key: const Key('profileInfoPage'),
          children: [
            SelectionArea(
              child: Text(
                body,
                key: const Key('profileInfoBody'),
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.55),
              ),
            ),
            const SizedBox(height: 28),
            if (copyText != null) ...[
              FilledButton.tonalIcon(
                key: const Key('copyProfileInfoButton'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: copyText));
                  if (context.mounted) Navigator.pop(context, true);
                },
                icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
                label: const Text('Copy'),
              ),
              const SizedBox(height: 10),
            ],
            TextButton(
              key: const Key('doneProfileInfoButton'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (copied == true && mounted) {
      setState(() {
        _announcement = '$title copied.';
        _inlineFeedback = '$title copied.';
        _inlineFeedbackIsError = false;
      });
    }
  }

  Future<void> _showCareTeam() {
    return _openInfoPage(
      title: 'Care Team',
      body: _savedCareTeam,
      copyText: _savedCareTeam,
    );
  }

  Future<void> _showHealthReport() {
    final report =
        'Mediary Health Report\n'
        'Name: $_savedName\n'
        'Blood Type: $_savedBloodType\n'
        'Allergies: ${_savedAllergies.isEmpty ? 'None' : _savedAllergies.join(', ')}\n'
        'Active Medications: ${widget.activeMedicationCount}\n'
        'Care Team: $_savedCareTeam';
    return _openInfoPage(
      title: 'Health Report',
      body: report,
      copyText: report,
    );
  }

  Future<void> _showEmergencyProfile() {
    final summary =
        '$_savedName\n'
        'Blood Type: $_savedBloodType\n'
        'Allergies: ${_savedAllergies.isEmpty ? 'None' : _savedAllergies.join(', ')}\n'
        'Care Team: $_savedCareTeam';
    return _openInfoPage(
      title: 'Emergency Profile',
      body: summary,
      copyText: summary,
    );
  }

  Future<void> _openActiveMedications() async {
    if (widget.onOpenLibrary != null) {
      widget.onOpenLibrary!();
      return;
    }
    await _openInfoPage(
      title: 'Active Medications',
      body: widget.activeMedicationNames.isEmpty
          ? 'No active medications.'
          : widget.activeMedicationNames.join('\n'),
    );
  }

  Future<void> _signOut() async {
    final onSignOut = widget.onSignOut;
    if (onSignOut == null || _isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await onSignOut();
      if (!mounted) return;
      _announce('Signed out.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _announcement = 'Could not sign out. Try again.';
        _inlineFeedback = 'Could not sign out. Try again.';
        _inlineFeedbackIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: responsiveContentWidth(
                      context,
                      nativeMaxWidth: 760,
                    ),
                  ),
                  child: ListView(
                    key: const Key('profileScrollView'),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      widget.bottomPadding,
                    ),
                    children: [
                      _ProfileHeader(
                        pageTitle: widget.pageTitle,
                        isEditing: _isEditing,
                        isSaving: _isSaving,
                        ink: _ink,
                        muted: _muted,
                        onBack: widget.onBack,
                        onEdit: _startEditing,
                        onCancel: _cancelEditing,
                        onDone: _saveProfile,
                      ),
                      _buildHero(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _inlineFeedback == null
                            ? const SizedBox.shrink()
                            : _ProfileInlineFeedback(
                                key: const Key('profileInlineFeedback'),
                                message: _inlineFeedback!,
                                isError: _inlineFeedbackIsError,
                              ),
                      ),
                      if (_saveError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                          child: Text(
                            _saveError!,
                            key: const Key('profileSaveError'),
                            style: const TextStyle(
                              color: _red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      _sectionTitle(
                        'Health Details',
                        key: const Key('profileHealthDetailsTitle'),
                      ),
                      _buildHealthSummary(),
                      _sectionTitle('Care'),
                      _buildProfileList(),
                      if (widget.onSignOut != null) ...[
                        const SizedBox(height: 24),
                        _buildSignOutButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Semantics(
              liveRegion: true,
              label: _announcement,
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ProfileAvatar(
            photoUrl: _isEditing ? _draftPhotoUrl : _savedPhotoUrl,
            initials: _initials,
            isEditing: _isEditing,
            surfaceColor: _background,
            onTap: _changeProfilePhoto,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isEditing
                  ? Column(
                      key: const ValueKey('editProfileFields'),
                      children: [
                        _profileField(
                          key: const Key('profileNameField'),
                          controller: _nameController,
                          focusNode: _nameFocus,
                          errorText: _nameError,
                          label: 'Name',
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _emailFocus.requestFocus(),
                        ),
                        const SizedBox(height: 8),
                        _profileField(
                          key: const Key('profileEmailField'),
                          controller: _emailController,
                          focusNode: _emailFocus,
                          errorText: _emailError,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _careTeamFocus.requestFocus(),
                        ),
                      ],
                    )
                  : Align(
                      key: const ValueKey('readProfileFields'),
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _savedName,
                            key: const Key('profileName'),
                            style: TextStyle(
                              color: _ink,
                              fontSize: 18,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _savedEmail,
                            key: const Key('profileEmail'),
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileField({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required ValueChanged<String> onSubmitted,
    String? errorText,
  }) {
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(color: _ink, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        isDense: true,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _line),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {Key? key}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 9),
      child: Text(
        title,
        key: key,
        style: TextStyle(
          color: _ink,
          fontSize: 18,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -.25,
        ),
      ),
    );
  }

  Widget _buildHealthSummary() {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _line),
          bottom: BorderSide(color: _line),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _HealthItem(
                label: 'Blood Type',
                lineColor: _line,
                child: _isEditing
                    ? DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('bloodTypePicker'),
                          value: _draftBloodType,
                          isDense: true,
                          alignment: Alignment.center,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          items: _bloodTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _draftBloodType = value);
                            }
                          },
                        ),
                      )
                    : Text(
                        _savedBloodType,
                        key: const Key('bloodTypeValue'),
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: _HealthItem(
                label: 'Allergies',
                lineColor: _line,
                child: _isEditing
                    ? Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        runSpacing: 2,
                        children: [
                          for (final allergy in _draftAllergies)
                            InputChip(
                              key: ValueKey('allergy-$allergy'),
                              label: Text(allergy),
                              labelStyle: const TextStyle(fontSize: 10),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onDeleted: () => setState(
                                () => _draftAllergies.remove(allergy),
                              ),
                            ),
                          TextButton(
                            key: const Key('addAllergyButton'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _addAllergy,
                            child: const Text('Add'),
                          ),
                        ],
                      )
                    : Text(
                        _savedAllergies.isEmpty
                            ? 'None recorded'
                            : _savedAllergies.join(', '),
                        key: const Key('allergiesValue'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: _HealthItem(
                label: 'Medications',
                lineColor: Colors.transparent,
                child: TextButton(
                  key: const Key('activeMedicationsButton'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _openActiveMedications,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${widget.activeMedicationCount} active'),
                        const SizedBox(width: 3),
                        const Icon(CupertinoIcons.chevron_right, size: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: _surface,
        child: Column(
          children: [
            _ProfileRow(
              lineColor: _line,
              enabled: true,
              title: 'Care Team',
              subtitle: _isEditing ? null : _savedCareTeam,
              onTap: _isEditing ? null : _showCareTeam,
              content: _isEditing
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _profileField(
                        key: const Key('careTeamField'),
                        controller: _careTeamController,
                        focusNode: _careTeamFocus,
                        errorText: _careTeamError,
                        label: 'Care Team',
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveProfile(),
                      ),
                    )
                  : null,
              trailing: _isEditing
                  ? const SizedBox.shrink()
                  : Icon(CupertinoIcons.chevron_right, color: _muted, size: 15),
            ),
            _ProfileRow(
              lineColor: _line,
              enabled: !_isEditing,
              title: 'Health Report',
              subtitle: 'View or copy your summary',
              onTap: _showHealthReport,
              trailing: Icon(
                CupertinoIcons.chevron_right,
                color: _muted,
                size: 15,
              ),
            ),
            _ProfileRow(
              lineColor: Colors.transparent,
              enabled: !_isEditing,
              title: 'Emergency Profile',
              subtitle: 'Essential health details',
              onTap: _showEmergencyProfile,
              leading: const Icon(
                CupertinoIcons.staroflife_fill,
                color: _red,
                size: 20,
              ),
              trailing: Icon(
                CupertinoIcons.chevron_right,
                color: _muted,
                size: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: _surface,
        child: ResponsiveCupertinoButton(
          buttonKey: const Key('accountSignOutButton'),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onPressed: _isEditing || _isSigningOut ? null : _signOut,
          busy: _isSigningOut,
          semanticLabel: 'Sign Out',
          child: _isSigningOut
              ? const CupertinoActivityIndicator(radius: 9)
              : const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: _red,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ProfilePageLead extends StatelessWidget {
  const _ProfilePageLead({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 34),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: -.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ProfileInlineFeedback extends StatelessWidget {
  const _ProfileInlineFeedback({
    super.key,
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isError ? colors.error : colors.primary;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 12, 3, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? CupertinoIcons.exclamationmark_circle_fill
                  : CupertinoIcons.check_mark_circled_solid,
              color: color,
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.pageTitle,
    required this.isEditing,
    required this.isSaving,
    required this.ink,
    required this.muted,
    this.onBack,
    required this.onEdit,
    required this.onCancel,
    required this.onDone,
  });

  final String pageTitle;
  final bool isEditing;
  final bool isSaving;
  final Color ink;
  final Color muted;
  final VoidCallback? onBack;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actionStyle = TextButton.styleFrom(
      foregroundColor: colors.primary,
      minimumSize: const Size(64, 44),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );
    return Padding(
      key: const Key('profilePageHeader'),
      padding: const EdgeInsets.fromLTRB(2, 10, 0, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            LiquidGlassBackButton(
              key: const Key('accountBackButton'),
              semanticLabel: 'Back to Settings',
              onPressed: onBack!,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEditing) ...[
                  Text(
                    'EDITING',
                    key: const Key('profileEyebrow'),
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .44,
                    ),
                  ),
                  const SizedBox(height: 1),
                ],
                Text(
                  pageTitle,
                  key: const Key('profilePageTitle'),
                  style: TextStyle(
                    color: ink,
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                  ),
                ),
              ],
            ),
          ),
          if (isEditing)
            TextButton(
              key: const Key('cancelProfileEditButton'),
              style: actionStyle,
              onPressed: isSaving ? null : onCancel,
              child: const Text('Cancel'),
            ),
          TextButton(
            key: Key(isEditing ? 'doneProfileEditButton' : 'editProfileButton'),
            style: actionStyle.copyWith(
              textStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 15,
                  fontWeight: isEditing ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            onPressed: isEditing ? onDone : onEdit,
            child: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CupertinoActivityIndicator(radius: 8),
                  )
                : Text(isEditing ? 'Done' : 'Edit'),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.photoUrl,
    required this.initials,
    required this.isEditing,
    required this.surfaceColor,
    required this.onTap,
  });

  final String? photoUrl;
  final String initials;
  final bool isEditing;
  final Color surfaceColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl?.trim();
    final colors = Theme.of(context).colorScheme;
    final avatar = SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: colors.primaryContainer,
            foregroundImage: safeProfileImageProvider(photo),
            child: Text(
              initials,
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isEditing)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: surfaceColor, width: 2),
                ),
                child: Icon(
                  CupertinoIcons.camera_fill,
                  color: colors.onPrimary,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
    if (!isEditing) {
      return Semantics(
        label: 'Profile photo',
        child: KeyedSubtree(
          key: const Key('changeProfilePhotoButton'),
          child: avatar,
        ),
      );
    }
    return AppPressable(
      key: const Key('changeProfilePhotoButton'),
      onPressed: onTap,
      autoManageBusy: false,
      semanticLabel: 'Change profile photo',
      borderRadius: BorderRadius.circular(33),
      hoverScale: 1.025,
      pressedScale: .95,
      child: avatar,
    );
  }
}

class _HealthItem extends StatelessWidget {
  const _HealthItem({
    required this.label,
    required this.lineColor,
    required this.child,
  });

  final String label;
  final Color lineColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: lineColor)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: dark ? const Color(0xFFB8B8BE) : const Color(0xFF515157),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.lineColor,
    required this.enabled,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.content,
    this.leading,
    this.onTap,
  });

  final Color lineColor;
  final bool enabled;
  final String title;
  final String? subtitle;
  final Widget? content;
  final Widget? leading;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? AppColors.darkText : const Color(0xFF1C1C1E);
    final muted = dark ? const Color(0xFFB8B8BE) : const Color(0xFF5F5F65);
    final row = Container(
      constraints: const BoxConstraints(minHeight: 58),
      margin: const EdgeInsets.only(left: 14),
      padding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox(width: 28, child: Center(child: leading)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(color: muted, fontSize: 11)),
                ],
                ?content,
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
    final interactive = enabled && onTap != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : .42,
      child: interactive
          ? AppPressable(
              onPressed: onTap,
              autoManageBusy: false,
              semanticLabel: subtitle == null ? title : '$title, $subtitle',
              borderRadius: BorderRadius.zero,
              hoverScale: 1,
              hoverOffset: Offset.zero,
              pressedScale: .99,
              child: row,
            )
          : row,
    );
  }
}
