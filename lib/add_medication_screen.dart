import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_interactions.dart';
import 'app_layout.dart';
import 'data/medication_catalog_client.dart';
import 'liquid_glass_back_button.dart';
import 'liquid_glass_search_field.dart';

/// A medication that can be added to the user's schedule.
@immutable
class MedicationOption {
  const MedicationOption({
    required this.id,
    required this.name,
    required this.genericName,
    required this.strength,
    required this.form,
    this.imageUrl = '',
    this.fallbackColor = const Color(0xFFDDE4EB),
    this.fallbackIcon = CupertinoIcons.capsule_fill,
    this.catalogVersion = '',
  });

  final String id;
  final String name;
  final String genericName;
  final String strength;
  final String form;
  final String imageUrl;
  final Color fallbackColor;
  final IconData fallbackIcon;
  final String catalogVersion;

  String get doseDescription => '$strength · $form';

  MedicationCatalogRecord toCatalogRecord() => MedicationCatalogRecord(
    rxcui: id,
    name: name,
    genericName: genericName,
    strength: strength,
    form: form,
    sourceVersion: catalogVersion,
  );

  factory MedicationOption.fromCatalog(MedicationCatalogRecord record) {
    return MedicationOption(
      id: record.rxcui,
      name: record.name,
      genericName: record.genericName,
      strength: record.strength,
      form: record.form,
      catalogVersion: record.sourceVersion,
    );
  }
}

/// Pushes the medication picker and returns its selected medications.
///
/// A `null` result means that the person cancelled the picker.
Future<List<MedicationOption>?> showAddMedicationScreen(
  BuildContext context, {
  MedicationCatalogClient? catalogClient,
  List<MedicationOption> medications = const [],
  Set<String> initiallySelectedIds = const {},
}) {
  return Navigator.of(context).push<List<MedicationOption>>(
    CupertinoPageRoute(
      builder: (_) => AddMedicationScreen(
        catalogClient: catalogClient,
        medications: medications,
        initiallySelectedIds: initiallySelectedIds,
      ),
    ),
  );
}

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({
    super.key,
    this.catalogClient,
    this.medications = const [],
    this.initiallySelectedIds = const {},
  });

  final MedicationCatalogClient? catalogClient;
  final List<MedicationOption> medications;
  final Set<String> initiallySelectedIds;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  var _searchRequest = 0;
  var _isSearching = false;
  String? _searchError;
  List<MedicationOption> _results = const [];
  late final Set<String> _selectedIds = {...widget.initiallySelectedIds};
  late final Map<String, MedicationOption> _selectedMedications = {
    for (final medication in widget.medications)
      if (widget.initiallySelectedIds.contains(medication.id))
        medication.id: medication,
  };

  bool get _usesLiveCatalog => widget.catalogClient != null;

  List<MedicationOption> get _visibleMedications {
    if (_usesLiveCatalog) return _results;
    final query = _searchController.text.trim().toLowerCase();
    return widget.medications
        .where((medication) {
          return query.isEmpty ||
              medication.name.toLowerCase().contains(query) ||
              medication.genericName.toLowerCase().contains(query) ||
              medication.strength.toLowerCase().contains(query) ||
              medication.form.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (!_usesLiveCatalog) {
      setState(() {});
      return;
    }
    _searchDebounce?.cancel();
    final request = ++_searchRequest;
    final query = value.trim();
    setState(() {
      _searchError = null;
      _results = const [];
      _isSearching = query.length >= 2;
    });
    if (query.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final page = await widget.catalogClient!.search(query);
        if (!mounted || request != _searchRequest) return;
        setState(() {
          _results = [
            for (final item in page.items) MedicationOption.fromCatalog(item),
          ];
          _isSearching = false;
        });
      } catch (error) {
        if (!mounted || request != _searchRequest) return;
        setState(() {
          _searchError = error.toString();
          _isSearching = false;
        });
      }
    });
  }

  void _toggleMedication(MedicationOption medication) {
    setState(() {
      if (!_selectedIds.add(medication.id)) {
        _selectedMedications.remove(medication.id);
      } else {
        _selectedMedications[medication.id] = medication;
      }
    });
  }

  void _completeSelection() {
    final source = _usesLiveCatalog ? _results : widget.medications;
    final result = [
      for (final medication in source)
        if (_selectedIds.contains(medication.id)) medication,
      for (final id in _selectedIds)
        if (!source.any((medication) => medication.id == id) &&
            _selectedMedications[id] != null)
          _selectedMedications[id]!,
    ];
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final medications = _visibleMedications;
    final selectionCount = _selectedIds.length;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = viewportWidth >= 900
        ? responsiveContentWidth(context, nativeMaxWidth: 760)
        : 560.0;
    final actionWidth = viewportWidth >= 900
        ? responsiveContentWidth(context, nativeMaxWidth: 728)
        : 528.0;

    return Scaffold(
      key: const Key('addMedicationScreen'),
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        leading: Center(
          child: LiquidGlassBackButton(
            key: const Key('cancelAddMedicationButton'),
            semanticLabel: 'Back from Add Medication',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: const Text(
          'Add Medication',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: LiquidGlassSearchField(
                    controller: _searchController,
                    textFieldKey: const Key('medicationSearchField'),
                    onChanged: _onSearchChanged,
                    hintText: 'Search Medications',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Medication',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        selectionCount == 0
                            ? 'Select Items'
                            : '$selectionCount Selected',
                        key: const Key('selectionCount'),
                        style: TextStyle(
                          color: selectionCount == 0
                              ? colors.onSurfaceVariant
                              : colors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchError != null
                      ? _CatalogError(message: _searchError!)
                      : medications.isEmpty
                      ? _EmptyMedicationSearch(
                          onClear: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          prompt:
                              _usesLiveCatalog &&
                              _searchController.text.trim().isEmpty,
                        )
                      : ListView.separated(
                          key: const Key('medicationOptionsList'),
                          padding: const EdgeInsets.only(bottom: 84),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: medications.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 86,
                            endIndent: 16,
                            color: colors.outlineVariant.withValues(alpha: .7),
                          ),
                          itemBuilder: (context, index) {
                            final medication = medications[index];
                            return _MedicationOptionRow(
                              medication: medication,
                              selected: _selectedIds.contains(medication.id),
                              onPressed: () => _toggleMedication(medication),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: actionWidth),
            child: _LiquidGlassAddButton(
              key: const Key('addSelectedMedicationsButton'),
              onPressed: selectionCount == 0 ? null : _completeSelection,
              label: selectionCount == 0
                  ? 'Add Selected'
                  : 'Add Selected ($selectionCount)',
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassAddButton extends StatelessWidget {
  const _LiquidGlassAddButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.maybeOf(context);
    final highContrast = mediaQuery?.highContrast ?? false;
    final reduceMotion = mediaQuery?.disableAnimations ?? false;
    final enabled = onPressed != null;
    final enabledAccent = highContrast
        ? Color.lerp(colors.primary, dark ? Colors.white : Colors.black, .18)!
        : colors.primary;
    final buttonColor = enabled
        ? enabledAccent.withValues(alpha: highContrast ? .98 : .92)
        : (dark ? const Color(0xFF292A2F) : const Color(0xFFE1E3E8));

    return AppPressable(
      onPressed: onPressed,
      enabled: enabled,
      haptic: AppHapticKind.primaryAction,
      semanticLabel: label,
      excludeFromSemantics: true,
      borderRadius: BorderRadius.circular(25),
      hoverScale: 1.01,
      hoverOffset: const Offset(0, -1),
      pressedScale: .975,
      disabledOpacity: 1,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: enabledAccent.withValues(alpha: dark ? .25 : .20),
                      blurRadius: 22,
                      spreadRadius: -7,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: WebAwareBlur(
              sigma: 22,
              child: AnimatedContainer(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: buttonColor,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? colors.onPrimary
                          : colors.onSurfaceVariant.withValues(alpha: .68),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

class _MedicationOptionRow extends StatelessWidget {
  const _MedicationOptionRow({
    required this.medication,
    required this.selected,
    required this.onPressed,
  });

  final MedicationOption medication;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: AppPressable(
        key: Key('medicationOption_${medication.id}'),
        onPressed: onPressed,
        semanticLabel: '${medication.name}, ${medication.doseDescription}',
        borderRadius: BorderRadius.zero,
        hoverScale: 1,
        hoverOffset: Offset.zero,
        pressedScale: .99,
        child: Material(
          color: selected
              ? colors.primary.withValues(alpha: .055)
              : Colors.transparent,
          child: SizedBox(
            height: 78,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _MedicationImage(medication: medication),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          medication.genericName == medication.name
                              ? medication.doseDescription
                              : '${medication.genericName} · ${medication.doseDescription}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    key: Key('medicationSelection_${medication.id}'),
                    duration: const Duration(milliseconds: 160),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? colors.primary : Colors.transparent,
                      border: Border.all(
                        color: selected ? colors.primary : colors.outline,
                        width: selected ? 0 : 1.3,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            CupertinoIcons.check_mark,
                            color: colors.onPrimary,
                            size: 15,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicationImage extends StatelessWidget {
  const _MedicationImage({required this.medication});

  final MedicationOption medication;

  Widget _fallback() {
    return ColoredBox(
      color: medication.fallbackColor,
      child: Center(
        child: Icon(
          medication.fallbackIcon,
          color: const Color(0xAA4E5158),
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (medication.imageUrl.isEmpty) return _fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox.square(
        dimension: 54,
        child: Image.asset(
          medication.imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 216,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _fallback();
          },
          errorBuilder: (_, _, _) => _fallback(),
        ),
      ),
    );
  }
}

class _EmptyMedicationSearch extends StatelessWidget {
  const _EmptyMedicationSearch({required this.onClear, this.prompt = false});

  final VoidCallback onClear;
  final bool prompt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.search,
              color: colors.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              prompt ? 'Search the medication catalog' : 'No Medications Found',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              prompt
                  ? 'Search by medication name, strength, or form.'
                  : 'Try a different name or strength.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
            ),
            if (!prompt) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onClear, child: const Text('Clear Search')),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rateLimited = message.toLowerCase().contains('rate');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rateLimited
                  ? CupertinoIcons.timer
                  : CupertinoIcons.wifi_exclamationmark,
              color: colors.error,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              rateLimited ? 'Catalog limit reached' : 'Catalog unavailable',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              rateLimited
                  ? 'Please wait a moment and try again.'
                  : 'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
