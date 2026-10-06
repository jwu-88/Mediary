import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controls.dart';
import 'app_interactions.dart';
import 'app_layout.dart';
import 'app_theme.dart';
import 'data/mediary_models.dart';
import 'in_app_page.dart';
import 'liquid_glass_back_button.dart';
import 'medication_artwork.dart';
import 'profile_image_policy.dart';
import 'text_formatting.dart';

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
    this.activeMedications = const [],
    this.onRemoveMedication,
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
  final List<MedicationRecord> activeMedications;
  final Future<void> Function(String medicationId)? onRemoveMedication;
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
  static const _bloodTypes = [
    '',
    'A+',
    'A−',
    'B+',
    'B−',
    'O+',
    'O−',
    'AB+',
    'AB−',
  ];

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

  String _draftBloodType = '';
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
  final Set<String> _removedMedicationIds = <String>{};

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  List<MedicationRecord> get _visibleActiveMedications => widget
      .activeMedications
      .where((medication) => !_removedMedicationIds.contains(medication.id))
      .toList(growable: false);
  int get _visibleActiveMedicationCount => widget.activeMedications.isEmpty
      ? widget.activeMedicationCount
      : _visibleActiveMedications.length;
  List<String> get _visibleActiveMedicationNames =>
      widget.activeMedications.isEmpty
      ? widget.activeMedicationNames.map(titleCaseDisplay).toList()
      : _visibleActiveMedications
            .map((medication) => titleCaseDisplay(medication.name))
            .toList();
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
    final bloodType = (widget.initialBloodType ?? '').replaceAll('-', '−');
    _savedBloodType = _bloodTypes.contains(bloodType) ? bloodType : '';
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
            AppButton(
              key: const Key('confirmAddAllergyButton'),
              label: 'Add Allergy',
              onPressed: () => Navigator.pop(context, controller.text),
              expand: true,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.tertiary,
              onPressed: () => Navigator.pop(context),
              expand: true,
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
              AppButton(
                key: const Key('saveProfilePhotoButton'),
                label: 'Save Photo',
                expand: true,
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
              ),
              const SizedBox(height: 10),
              AppButton(
                key: const Key('useProfileInitialsButton'),
                label: 'Use Initials',
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () => Navigator.pop(context, ''),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.tertiary,
                expand: true,
                onPressed: () => Navigator.pop(context),
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
    String? copyError;
    final copied = await pushInAppPage<bool>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPageState) => InAppPageScaffold(
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
              if (copyError != null)
                _ProfileInlineFeedback(
                  key: const Key('profileCopyError'),
                  message: copyError!,
                  isError: true,
                ),
              const SizedBox(height: 28),
              if (copyText != null) ...[
                AppButton(
                  key: const Key('copyProfileInfoButton'),
                  label: 'Copy',
                  icon: CupertinoIcons.doc_on_doc,
                  expand: true,
                  onError: (error, stackTrace) {
                    if (context.mounted) {
                      setPageState(
                        () => copyError =
                            'This information could not be copied. Try again.',
                      );
                    }
                  },
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: copyText));
                    if (context.mounted) Navigator.pop(context, true);
                  },
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                key: const Key('doneProfileInfoButton'),
                label: 'Done',
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
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
        'Blood Type: ${_savedBloodType.isEmpty ? 'Not provided' : _savedBloodType}\n'
        'Allergies: ${_savedAllergies.isEmpty ? 'None recorded' : _savedAllergies.join(', ')}\n'
        'Active Medications: $_visibleActiveMedicationCount\n'
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
        'Blood Type: ${_savedBloodType.isEmpty ? 'Not provided' : _savedBloodType}\n'
        'Allergies: ${_savedAllergies.isEmpty ? 'None recorded' : _savedAllergies.join(', ')}\n'
        'Care Team: $_savedCareTeam';
    return _openInfoPage(
      title: 'Emergency Profile',
      body: summary,
      copyText: summary,
    );
  }

  Future<void> _openActiveMedications() async {
    final medications = _visibleActiveMedications;
    if (medications.isNotEmpty && widget.onRemoveMedication != null) {
      await pushInAppPage<void>(
        context,
        builder: (context) => _ActiveMedicationManagementPage(
          medications: medications,
          onRemove: (medication) async {
            await widget.onRemoveMedication!(medication.id);
            if (mounted) {
              setState(() => _removedMedicationIds.add(medication.id));
            }
          },
        ),
      );
      return;
    }
    if (widget.onOpenLibrary != null) {
      widget.onOpenLibrary!();
      return;
    }
    await _openInfoPage(
      title: 'Active Medications',
      body: _visibleActiveMedicationNames.isEmpty
          ? 'No active medications.'
          : _visibleActiveMedicationNames.join('\n'),
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
                      nativeMaxWidth: 1120,
                    ),
                  ),
                  child: ListView(
                    key: const Key('profileScrollView'),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageGutterOf(context),
                      AppSpacing.sm,
                      AppSpacing.pageGutterOf(context),
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
                        _ProfileInlineFeedback(
                          key: const Key('profileSaveError'),
                          message: _saveError!,
                          isError: true,
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
                              fontSize: 20,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _savedEmail,
                            key: const Key('profileEmail'),
                            style: AppTextStyles.body.copyWith(color: _muted),
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
      style: AppTextStyles.body.copyWith(color: _ink),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        isDense: true,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _line),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {Key? key}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _line),
          bottom: BorderSide(color: _line),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(15) > 22;
          final divider = stacked ? Colors.transparent : _line;
          final items = [
            _HealthItem(
              label: 'Blood Type',
              lineColor: divider,
              child: _isEditing
                  ? DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('bloodTypePicker'),
                        isExpanded: true,
                        value: _draftBloodType,
                        itemHeight: null,
                        alignment: Alignment.center,
                        style: AppTextStyles.body.copyWith(
                          color: _ink,
                          fontWeight: FontWeight.w600,
                        ),
                        items: _bloodTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type.isEmpty ? 'Not provided' : type,
                                ),
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
                      _savedBloodType.isEmpty
                          ? 'Not provided'
                          : _savedBloodType,
                      key: const Key('bloodTypeValue'),
                      style: AppTextStyles.body.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            _HealthItem(
              label: 'Allergies',
              lineColor: divider,
              child: _isEditing
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final allergy in _draftAllergies)
                          InputChip(
                            key: ValueKey('allergy-$allergy'),
                            label: Text(allergy),
                            labelStyle: AppTextStyles.caption,
                            onDeleted: () =>
                                setState(() => _draftAllergies.remove(allergy)),
                          ),
                        AppButton(
                          key: const Key('addAllergyButton'),
                          label: 'Add',
                          compact: true,
                          variant: AppButtonVariant.tertiary,
                          onPressed: _addAllergy,
                        ),
                      ],
                    )
                  : Text(
                      _savedAllergies.isEmpty
                          ? 'None recorded'
                          : _savedAllergies.join(', '),
                      key: const Key('allergiesValue'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            _HealthItem(
              label: 'Medications',
              lineColor: Colors.transparent,
              child: AppButton(
                key: const Key('activeMedicationsButton'),
                label: '$_visibleActiveMedicationCount active',
                compact: true,
                variant: AppButtonVariant.tertiary,
                onPressed: _openActiveMedications,
              ),
            ),
          ];
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  items[index],
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final item in items) Expanded(child: item)],
            ),
          );
        },
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
    return AppButton(
      key: const Key('accountSignOutButton'),
      label: 'Sign Out',
      variant: AppButtonVariant.destructiveSecondary,
      onPressed: _isEditing || _isSigningOut ? null : _signOut,
      busy: _isSigningOut,
      loadingLabel: 'Signing Out',
      semanticLabel: 'Sign Out',
      expand: true,
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
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError
                    ? CupertinoIcons.exclamationmark_circle_fill
                    : CupertinoIcons.check_mark_circled_solid,
                color: color,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(color: color),
                ),
              ),
            ],
          ),
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
    return Padding(
      key: const Key('profilePageHeader'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackActions =
              (isEditing && constraints.maxWidth < 520) ||
              MediaQuery.textScalerOf(context).scale(15) > 21;
          final title = Row(
            children: [
              if (onBack != null) ...[
                LiquidGlassBackButton(
                  key: const Key('accountBackButton'),
                  semanticLabel: 'Back to Settings',
                  onPressed: onBack!,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isEditing) ...[
                      Text(
                        'EDITING',
                        key: const Key('profileEyebrow'),
                        style: AppTextStyles.caption.copyWith(
                          color: muted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      pageTitle,
                      key: const Key('profilePageTitle'),
                      style: AppTextStyles.pageTitle.copyWith(color: ink),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (isEditing)
                AppButton(
                  key: const Key('cancelProfileEditButton'),
                  label: 'Cancel',
                  compact: true,
                  variant: AppButtonVariant.tertiary,
                  onPressed: isSaving ? null : onCancel,
                ),
              AppButton(
                key: Key(
                  isEditing ? 'doneProfileEditButton' : 'editProfileButton',
                ),
                label: isEditing ? 'Done' : 'Edit',
                compact: true,
                variant: isEditing
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
                onPressed: isSaving
                    ? null
                    : isEditing
                    ? onDone
                    : onEdit,
                busy: isSaving,
                loadingLabel: 'Saving',
              ),
            ],
          );
          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: AppSpacing.md),
                actions,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: AppSpacing.md),
              actions,
            ],
          );
        },
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
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(color: muted, fontSize: 12)),
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

class _ActiveMedicationManagementPage extends StatefulWidget {
  const _ActiveMedicationManagementPage({
    required this.medications,
    required this.onRemove,
  });

  final List<MedicationRecord> medications;
  final Future<void> Function(MedicationRecord medication) onRemove;

  @override
  State<_ActiveMedicationManagementPage> createState() =>
      _ActiveMedicationManagementPageState();
}

class _ActiveMedicationManagementPageState
    extends State<_ActiveMedicationManagementPage> {
  late final List<MedicationRecord> _medications = [...widget.medications];
  String? _removingId;
  String? _error;

  Future<void> _removeMedication(MedicationRecord medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Remove ${titleCaseDisplay(medication.name)}?'),
        content: const Text(
          'This permanently deletes the medication, its schedules, and its dose history.',
        ),
        actions: [
          AppButton(
            label: 'Keep',
            compact: true,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: 'Remove',
            compact: true,
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _removingId = medication.id;
      _error = null;
    });
    try {
      await widget.onRemove(medication);
      if (!mounted) return;
      setState(() {
        _medications.removeWhere((item) => item.id == medication.id);
        _removingId = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _removingId = null;
        _error = 'Could not remove this medication. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InAppPageScaffold(
      title: 'Active Medications',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Manage the medications in your private regimen. Removing one permanently deletes its schedules and dose history.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            _ProfileInlineFeedback(message: _error!, isError: true),
            const SizedBox(height: 12),
          ],
          if (_medications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No active medications.')),
            )
          else
            for (final medication in _medications)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  leading: MedicationArtwork(
                    key: Key('profileMedicationArtwork_${medication.id}'),
                    seed: medication.catalogId ?? medication.id,
                    label: titleCaseDisplay(medication.name),
                    size: 44,
                  ),
                  title: Text(titleCaseDisplay(medication.name)),
                  subtitle: Text(
                    titleCaseDisplay(
                      [
                        medication.genericName,
                        medication.strength,
                        medication.form,
                      ].where((value) => value.isNotEmpty).join(' · '),
                    ),
                  ),
                  trailing: AppIconButton(
                    key: Key('removeMedication_${medication.id}'),
                    tooltip: 'Remove ${titleCaseDisplay(medication.name)}',
                    icon: Icons.delete_outline,
                    busy: _removingId == medication.id,
                    onPressed: _removingId == medication.id
                        ? null
                        : () {
                            unawaited(_removeMedication(medication));
                          },
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
