import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ProfileDraft {
  const ProfileDraft({
    required this.name,
    required this.email,
    required this.bloodType,
    required this.allergies,
    required this.careTeam,
  });

  final String name;
  final String email;
  final String bloodType;
  final List<String> allergies;
  final String careTeam;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.onOpenLibrary,
    this.onOpenSettings,
    this.onSave,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
  final VoidCallback? onOpenLibrary;
  final VoidCallback? onOpenSettings;
  final Future<void> Function(ProfileDraft draft)? onSave;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _blue = Color(0xFF0A62D0);
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
  String _savedBloodType = 'O+';
  List<String> _savedAllergies = ['Penicillin'];
  String _savedCareTeam = 'Dr. Hannah Lee · City Health';

  String _draftBloodType = 'O+';
  List<String> _draftAllergies = ['Penicillin'];
  bool _isEditing = false;
  bool _isSaving = false;
  bool _doseReminders = true;
  String? _nameError;
  String? _emailError;
  String? _careTeamError;
  String? _saveError;
  String _announcement = '';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _isDark ? const Color(0xFF101418) : const Color(0xFFF2F2F7);
  Color get _surface => _isDark ? const Color(0xFF1C1C1E) : Colors.white;
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
    final error = _careTeamController.text.trim().length < 2
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
      _nameError = null;
      _emailError = null;
      _careTeamError = null;
      _saveError = null;
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
      _announcement = 'Editing cancelled.';
    });
  }

  Future<void> _cancelEditing() async {
    if (!_hasUnsavedChanges) {
      _exitEditing();
      return;
    }

    final discard = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your profile edits will not be saved.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard Changes'),
          ),
        ],
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
        _isSaving = false;
        _isEditing = false;
        _announcement = 'Profile saved.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Profile could not be saved. Try again.';
        _announcement =
            'Profile could not be saved. Your changes are preserved.';
      });
    }
  }

  Future<void> _addAllergy() async {
    final controller = TextEditingController();
    final allergy = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add allergy'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const Key('allergyField'),
            controller: controller,
            autofocus: true,
            placeholder: 'Allergy name',
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    final value = allergy?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    final duplicate = _draftAllergies.any(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    if (!duplicate) setState(() => _draftAllergies.add(value));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ProfileHeader(
              isEditing: _isEditing,
              isSaving: _isSaving,
              ink: _ink,
              muted: _muted,
              onEdit: _startEditing,
              onCancel: _cancelEditing,
              onDone: _saveProfile,
            ),
            Expanded(
              child: ListView(
                key: const Key('profileScrollView'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  _buildHero(),
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
                  _sectionTitle('Health details'),
                  _buildHealthSummary(),
                  _sectionTitle('Profile & care'),
                  _buildProfileList(),
                ],
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
            photoUrl: widget.photoUrl,
            initials: _initials,
            isEditing: _isEditing,
            surfaceColor: _background,
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
                  : Column(
                      key: const ValueKey('readProfileFields'),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 9),
      child: Text(
        title,
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
                label: 'Blood type',
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
                              foregroundColor: _blue,
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
                    foregroundColor: _blue,
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: widget.onOpenLibrary,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('3 active'),
                        SizedBox(width: 3),
                        Icon(CupertinoIcons.chevron_right, size: 10),
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
              title: 'Care team',
              subtitle: _isEditing ? null : _savedCareTeam,
              content: _isEditing
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _profileField(
                        key: const Key('careTeamField'),
                        controller: _careTeamController,
                        focusNode: _careTeamFocus,
                        errorText: _careTeamError,
                        label: 'Care team',
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
              title: 'Health report',
              subtitle: 'Export your medication history',
              trailing: Icon(
                CupertinoIcons.chevron_right,
                color: _muted,
                size: 15,
              ),
            ),
            _ProfileRow(
              lineColor: _line,
              enabled: !_isEditing,
              title: 'Emergency profile',
              subtitle: 'Visible from the lock screen',
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
            _ProfileRow(
              lineColor: _line,
              enabled: true,
              title: 'Dose reminders',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _doseReminders ? 'On' : 'Off',
                    key: const Key('doseReminderStatus'),
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  CupertinoSwitch(
                    key: const Key('doseReminderSwitch'),
                    value: _doseReminders,
                    activeTrackColor: _blue,
                    onChanged: (value) {
                      setState(() {
                        _doseReminders = value;
                        _announcement =
                            'Dose reminders turned ${value ? 'on' : 'off'}.';
                      });
                    },
                  ),
                ],
              ),
            ),
            _ProfileRow(
              lineColor: _line,
              enabled: !_isEditing,
              title: 'Privacy & data',
              trailing: Icon(
                CupertinoIcons.chevron_right,
                color: _muted,
                size: 15,
              ),
            ),
            _ProfileRow(
              lineColor: Colors.transparent,
              enabled: !_isEditing,
              title: 'Settings',
              onTap: widget.onOpenSettings,
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
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.isEditing,
    required this.isSaving,
    required this.ink,
    required this.muted,
    required this.onEdit,
    required this.onCancel,
    required this.onDone,
  });

  final bool isEditing;
  final bool isSaving;
  final Color ink;
  final Color muted;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  static const _blue = Color(0xFF0A62D0);

  @override
  Widget build(BuildContext context) {
    final actionStyle = TextButton.styleFrom(
      foregroundColor: _blue,
      minimumSize: const Size(64, 44),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );
    return SizedBox(
      height: 78,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: isEditing
                ? TextButton(
                    key: const Key('cancelProfileEditButton'),
                    style: actionStyle,
                    onPressed: isSaving ? null : onCancel,
                    child: const Text('Cancel'),
                  )
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'EDITING' : 'ACCOUNT',
                  key: const Key('profileEyebrow'),
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .48,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your profile',
                  style: TextStyle(
                    color: ink,
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: TextButton(
              key: Key(
                isEditing ? 'doneProfileEditButton' : 'editProfileButton',
              ),
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
  });

  final String? photoUrl;
  final String initials;
  final bool isEditing;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl?.trim();
    return Semantics(
      button: isEditing,
      label: isEditing ? 'Change profile photo' : 'Profile photo',
      child: SizedBox(
        width: 66,
        height: 66,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFFDDE7FA),
              foregroundImage: photo == null || photo.isEmpty
                  ? null
                  : NetworkImage(photo),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF173B70),
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
                    color: const Color(0xFF0A62D0),
                    shape: BoxShape.circle,
                    border: Border.all(color: surfaceColor, width: 2),
                  ),
                  child: const Icon(
                    CupertinoIcons.camera_fill,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
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
    final ink = dark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final muted = dark ? const Color(0xFFB8B8BE) : const Color(0xFF5F5F65);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : .42,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
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
                      Text(
                        subtitle!,
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                    ?content,
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
