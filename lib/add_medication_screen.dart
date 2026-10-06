import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_interactions.dart';
import 'app_layout.dart';
import 'data/medication_catalog_client.dart';
import 'liquid_glass_back_button.dart';
import 'liquid_glass_search_field.dart';
import 'medication_artwork.dart';
import 'text_formatting.dart';

/// A medication that can be added to the user's schedule.
@immutable
class MedicationOption {
  const MedicationOption({
    required this.id,
    required this.name,
    required this.genericName,
    required this.strength,
    required this.form,
    this.route = '',
    this.synonym = '',
    this.catalogVersion = '',
  });

  final String id;
  final String name;
  final String genericName;
  final String strength;
  final String form;
  final String route;
  final String synonym;
  final String catalogVersion;

  String get doseDescription => [
    if (strength.isNotEmpty) strength,
    if (form.isNotEmpty) form,
    if (route.isNotEmpty) route,
  ].join(' · ');

  MedicationCatalogRecord toCatalogRecord() => MedicationCatalogRecord(
    rxcui: id,
    name: name,
    genericName: genericName,
    strength: strength,
    form: form,
    route: route,
    synonym: synonym,
    sourceVersion: catalogVersion,
  );

  factory MedicationOption.fromCatalog(MedicationCatalogRecord record) {
    return MedicationOption(
      id: record.rxcui,
      name: record.name,
      genericName: record.genericName,
      strength: record.strength,
      form: record.form,
      route: record.route,
      synonym: record.synonym,
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
  var _hasSearchQuery = false;
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
    final hasQuery = query.isNotEmpty;
    final isSearching = query.length >= 2;
    final shouldRefreshResults =
        _hasSearchQuery != hasQuery ||
        _isSearching != isSearching ||
        _results.isNotEmpty ||
        _searchError != null;
    _hasSearchQuery = hasQuery;
    if (shouldRefreshResults) {
      setState(() {
        _searchError = null;
        _results = const [];
        _isSearching = isSearching;
      });
    }
    if (query.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 180), () async {
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
      if (_selectedIds.remove(medication.id)) {
        _selectedMedications.remove(medication.id);
      } else {
        _selectedIds.add(medication.id);
        _selectedMedications[medication.id] = medication;
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
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
        ? responsiveContentWidth(context, nativeMaxWidth: 1120)
        : 560.0;
    final actionWidth = viewportWidth >= 900
        ? responsiveContentWidth(context, nativeMaxWidth: 1088)
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
        title: const Text('Add Medication', style: AppTextStyles.sectionTitle),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                return KeyedSubtree(
                  key: const Key('medicationOptionsList'),
                  child: CustomScrollView(
                    key: const Key('addMedicationScrollView'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.pageGutterOf(context),
                                AppSpacing.sm,
                                AppSpacing.pageGutterOf(context),
                                AppSpacing.lg,
                              ),
                              child: LiquidGlassSearchField(
                                controller: _searchController,
                                textFieldKey: const Key(
                                  'medicationSearchField',
                                ),
                                onChanged: _onSearchChanged,
                                hintText: 'Search Medications',
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.pageGutterOf(context),
                                0,
                                AppSpacing.pageGutterOf(context),
                                AppSpacing.sm,
                              ),
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
                                  Flexible(
                                    child: Text(
                                      selectionCount == 0
                                          ? 'Select Items'
                                          : '$selectionCount Selected',
                                      key: const Key('selectionCount'),
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: selectionCount == 0
                                            ? colors.onSurfaceVariant
                                            : colors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectionCount > 0)
                              _SelectedMedicationSummary(
                                // Keep catalog results available as selections grow.
                                maxHeight: math.max(
                                  constraints.maxHeight * .4,
                                  160 * textScale,
                                ),
                                medications: [
                                  for (final id in _selectedIds)
                                    if (_selectedMedications[id] != null)
                                      _selectedMedications[id]!,
                                ],
                                onRemove: (medication) =>
                                    _toggleMedication(medication),
                                onClear: () => setState(() {
                                  _selectedIds.clear();
                                  _selectedMedications.clear();
                                }),
                              )
                            else
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  AppSpacing.pageGutterOf(context),
                                  0,
                                  AppSpacing.pageGutterOf(context),
                                  AppSpacing.md,
                                ),
                                child: Text(
                                  _usesLiveCatalog
                                      ? 'Search at least 2 characters, then tap a result to select it.'
                                      : 'Tap a medication to select it. You can choose more than one.',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!_isSearching &&
                          _searchError == null &&
                          medications.isNotEmpty)
                        SliverPadding(
                          padding: EdgeInsets.only(bottom: 96 * textScale),
                          sliver: SliverList.separated(
                            itemCount: medications.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              indent: 96,
                              endIndent: 16,
                              color: colors.outlineVariant.withValues(
                                alpha: .7,
                              ),
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
                        )
                      else
                        SliverLayoutBuilder(
                          builder: (context, sliverConstraints) {
                            // Recovery content grows with the text size and
                            // remains in the same scroll view as the header.
                            final minimumHeight = math.max(
                              180 * textScale,
                              sliverConstraints.viewportMainAxisExtent -
                                  sliverConstraints.precedingScrollExtent,
                            );
                            return SliverToBoxAdapter(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: minimumHeight,
                                ),
                                child: _isSearching
                                    ? const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 12),
                                            Text(
                                              'Searching the live medication catalog…',
                                            ),
                                          ],
                                        ),
                                      )
                                    : _searchError != null
                                    ? _CatalogError(
                                        message: _searchError!,
                                        onRetry: () => _onSearchChanged(
                                          _searchController.text,
                                        ),
                                        onClear: _clearSearch,
                                      )
                                    : _EmptyMedicationSearch(
                                        onClear: _clearSearch,
                                        prompt:
                                            _usesLiveCatalog &&
                                            _searchController.text
                                                .trim()
                                                .isEmpty,
                                      ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(
          AppSpacing.pageGutterOf(context),
          AppSpacing.md,
          AppSpacing.pageGutterOf(context),
          AppSpacing.md,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: actionWidth),
            child: AppButton(
              key: const Key('addSelectedMedicationsButton'),
              onPressed: selectionCount == 0 ? null : _completeSelection,
              label: selectionCount == 0
                  ? 'Add Selected'
                  : 'Add Selected ($selectionCount)',
              icon: CupertinoIcons.add,
              expand: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedMedicationSummary extends StatelessWidget {
  const _SelectedMedicationSummary({
    required this.maxHeight,
    required this.medications,
    required this.onRemove,
    required this.onClear,
  });

  final double maxHeight;
  final List<MedicationOption> medications;
  final ValueChanged<MedicationOption> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageGutterOf(context),
        0,
        AppSpacing.pageGutterOf(context),
        AppSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: .42),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.primary.withValues(alpha: .22)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Selected Medications: ${medications.length}',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppButton(
                      key: const Key('clearMedicationSelectionButton'),
                      onPressed: onClear,
                      label: 'Clear',
                      variant: AppButtonVariant.tertiary,
                      compact: true,
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('selectedMedicationSummaryScrollView'),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final medication in medications)
                          InputChip(
                            key: Key('selectedMedicationChip_${medication.id}'),
                            avatar: MedicationArtwork(
                              key: Key(
                                'selectedMedicationArtwork_${medication.id}',
                              ),
                              seed: medication.id,
                              label: titleCaseDisplay(medication.name),
                              size: 24,
                            ),
                            label: Text(
                              titleCaseDisplay(medication.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => onRemove(medication),
                            deleteIcon: const Icon(Icons.close, size: 15),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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
        semanticLabel:
            '${titleCaseDisplay(medication.name)}, '
            '${titleCaseDisplay(medication.doseDescription)}',
        borderRadius: BorderRadius.zero,
        hoverScale: 1,
        hoverOffset: Offset.zero,
        pressedScale: .99,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: .055)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.pageGutterOf(context),
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  MedicationArtwork(
                    key: Key('medicationArtwork_${medication.id}'),
                    seed: medication.id,
                    label: titleCaseDisplay(medication.name),
                    size: 50,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleCaseDisplay(medication.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          medication.genericName == medication.name ||
                                  medication.genericName.isEmpty
                              ? titleCaseDisplay(medication.doseDescription)
                              : titleCaseDisplay(
                                  '${medication.genericName} · ${medication.doseDescription}',
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
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

class _EmptyMedicationSearch extends StatelessWidget {
  const _EmptyMedicationSearch({required this.onClear, this.prompt = false});

  final VoidCallback onClear;
  final bool prompt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
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
                prompt
                    ? 'Search the medication catalog'
                    : 'No Medications Found',
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                prompt
                    ? 'Search by medication name, strength, or form.'
                    : 'Try a different name or strength.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (!prompt) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  onPressed: onClear,
                  label: 'Clear Search',
                  variant: AppButtonVariant.secondary,
                  compact: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({
    required this.message,
    required this.onRetry,
    required this.onClear,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rateLimited = message.toLowerCase().contains('rate');
    return Center(
      child: SingleChildScrollView(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
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
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                rateLimited
                    ? 'Please wait a moment and try again.'
                    : 'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  AppButton(
                    key: const Key('retryMedicationSearchButton'),
                    onPressed: onRetry,
                    label: 'Try Again',
                    compact: true,
                  ),
                  AppButton(
                    onPressed: onClear,
                    label: 'Clear Search',
                    variant: AppButtonVariant.tertiary,
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
