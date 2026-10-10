import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_controls.dart';
import 'app_interactions.dart';
import 'app_layout.dart';
import 'app_theme.dart';
import 'data/medication_catalog_client.dart';
import 'in_app_page.dart';
import 'liquid_glass_back_button.dart';
import 'liquid_glass_search_field.dart';
import 'medication_artwork.dart';
import 'text_formatting.dart';

class MedicationLibraryScreen extends StatefulWidget {
  const MedicationLibraryScreen({
    super.key,
    this.catalogClient,
    this.initialQuery = '',
    this.onBack,
    this.onSavedChanged,
    this.onAddToSchedule,
    this.initialSavedMedicationIds = const {},
    this.bottomPadding = 128,
  });

  final MedicationCatalogClient? catalogClient;
  final String initialQuery;
  final VoidCallback? onBack;
  final Future<void> Function(
    String medicationId,
    bool saved, {
    String? catalogVersion,
  })?
  onSavedChanged;
  final Future<bool> Function(
    BuildContext context,
    MedicationCatalogRecord medication,
  )?
  onAddToSchedule;
  final Set<String> initialSavedMedicationIds;
  final double bottomPadding;

  @override
  State<MedicationLibraryScreen> createState() =>
      _MedicationLibraryScreenState();
}

class _MedicationLibraryScreenState extends State<MedicationLibraryScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  var _searchRequest = 0;
  var _isSearching = false;
  var _hasSearchQuery = false;
  String? _searchError;
  List<MedicationCatalogRecord> _results = const [];
  bool _savedOnly = false;
  bool _isLoadingSaved = false;
  String? _savedError;
  var _savedRequest = 0;
  final Map<String, MedicationCatalogRecord> _savedResults = {};
  late final Set<String> _savedMedicationIds = {
    ...widget.initialSavedMedicationIds,
  };

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery.trim();
    if (initialQuery.isEmpty) return;
    _searchController.text = initialQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onSearchChanged(initialQuery);
    });
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _isDark ? AppColors.darkBackground : const Color(0xFFF2F2F7);
  Color get _surface => _isDark ? AppColors.darkSurface : Colors.white;
  Color get _ink => _isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
  Color get _muted =>
      _isDark ? const Color(0xFFB8B8BE) : const Color(0xFF6E6E73);
  Color get _line =>
      _isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD9D9DE);
  List<MedicationCatalogRecord> get _visibleCatalogResults {
    final source = _savedOnly && _searchController.text.trim().isEmpty
        ? _savedResults.values
        : _results;
    return [
      for (final medication in source)
        if (!_savedOnly || _savedMedicationIds.contains(medication.rxcui))
          medication,
    ];
  }

  List<_Medication> get _visibleMedications => [
    for (final medication in _visibleCatalogResults)
      if (!_savedOnly || _savedMedicationIds.contains(medication.rxcui))
        _Medication.fromCatalog(medication),
  ];

  @override
  void didUpdateWidget(covariant MedicationLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSavedMedicationIds !=
        widget.initialSavedMedicationIds) {
      _savedMedicationIds
        ..clear()
        ..addAll(widget.initialSavedMedicationIds);
      _savedResults.removeWhere((id, _) => !_savedMedicationIds.contains(id));
      if (_savedOnly && _searchController.text.trim().isEmpty) {
        unawaited(_loadSavedMedications());
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSavedOnly() {
    final next = !_savedOnly;
    setState(() {
      _savedOnly = next;
      _savedError = null;
    });
    if (next && _searchController.text.trim().isEmpty) {
      unawaited(_loadSavedMedications());
    }
  }

  Future<void> _loadSavedMedications() async {
    final client = widget.catalogClient;
    if (client == null || _savedMedicationIds.isEmpty) return;
    final request = ++_savedRequest;
    if (mounted) {
      setState(() {
        _isLoadingSaved = true;
        _savedError = null;
      });
    }
    final loaded = <String, MedicationCatalogRecord>{};
    Object? firstError;
    for (final id in _savedMedicationIds) {
      if (!mounted || request != _savedRequest) return;
      final cached = _savedResults[id];
      if (cached != null) {
        loaded[id] = cached;
        continue;
      }
      try {
        loaded[id] = await client.getDetails(id);
      } catch (error) {
        firstError ??= error;
      }
    }
    if (!mounted || request != _savedRequest) return;
    setState(() {
      _savedResults
        ..clear()
        ..addAll(loaded);
      _savedError = loaded.isEmpty && firstError != null
          ? firstError.toString()
          : null;
      _isLoadingSaved = false;
    });
  }

  void _onSearchChanged(String value) {
    final client = widget.catalogClient;
    if (client == null) {
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
        final page = await client.search(query);
        if (!mounted || request != _searchRequest) return;
        setState(() {
          _results = page.items;
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

  void _resetSearchAndFilters() {
    _searchController.clear();
    // An abandoned saved-list request must not restore an error after clearing.
    _savedRequest++;
    setState(() {
      _savedOnly = false;
      _savedError = null;
      _isLoadingSaved = false;
    });
    _onSearchChanged('');
  }

  Future<void> _openMedication(_Medication medication) async {
    var record = medication.catalogRecord;
    if (record != null && widget.catalogClient != null) {
      try {
        record = await widget.catalogClient!.getDetails(record.rxcui);
      } catch (_) {
        // The RxNorm search result remains usable if openFDA enrichment fails.
      }
    }
    if (!mounted || record == null) return;
    final resolvedRecord = record;
    final saved = _savedMedicationIds.contains(medication.id);
    await pushInAppPage<void>(
      context,
      builder: (context) => MedicationDetailScreen(
        medication: resolvedRecord,
        initialBookmarked: saved,
        onAddToSchedule: widget.onAddToSchedule,
        onBookmarkChanged: (next) async {
          await widget.onSavedChanged?.call(
            medication.id,
            next,
            catalogVersion: resolvedRecord.sourceVersion,
          );
          if (!mounted) return;
          setState(() {
            if (next) {
              _savedMedicationIds.add(medication.id);
            } else {
              _savedMedicationIds.remove(medication.id);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medications = _visibleMedications;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = viewportWidth >= 900
        ? responsiveContentWidth(context, nativeMaxWidth: 1120)
        : 520.0;
    // This screen is also pushed directly from scan review, where the previous
    // route's Scaffold cannot provide Material ancestry or keyboard resizing.
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: CustomScrollView(
              key: const Key('medicationLibraryScrollView'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageGutterOf(context),
                    AppSpacing.sm,
                    AppSpacing.pageGutterOf(context),
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _LibraryHeader(
                        ink: _ink,
                        muted: _muted,
                        savedOnly: _savedOnly,
                        onBack: widget.onBack,
                        onSavedPressed: _toggleSavedOnly,
                      ),
                      const SizedBox(height: 16),
                      _SearchField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onFilterPressed: () {
                          FocusScope.of(context).unfocus();
                          _toggleSavedOnly();
                        },
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        key: const Key('catalogAttribution'),
                        decoration: BoxDecoration(
                          color: _surface.withValues(alpha: .58),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _line.withValues(alpha: .72),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            'Catalog data from RxNorm (U.S. National Library of Medicine). Label details may come from openFDA. Verify with your pharmacist or care team.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageGutterOf(context),
                    AppSpacing.xl,
                    AppSpacing.pageGutterOf(context),
                    widget.bottomPadding,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _SectionHeading(
                        title: 'RxNorm results',
                        action: _savedOnly ? 'All results' : 'Saved only',
                        ink: _ink,
                        onPressed: _toggleSavedOnly,
                      ),
                      const SizedBox(height: 10),
                      if (_isSearching || (_savedOnly && _isLoadingSaved))
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_searchError != null || _savedError != null)
                        _LibraryError(
                          message: _searchError ?? _savedError!,
                          onRetry: () {
                            if (_savedOnly &&
                                _searchController.text.trim().isEmpty) {
                              unawaited(_loadSavedMedications());
                            } else {
                              _onSearchChanged(_searchController.text);
                            }
                          },
                          onClear: _resetSearchAndFilters,
                        )
                      else if (medications.isEmpty)
                        _EmptyResults(
                          ink: _ink,
                          muted: _muted,
                          savedOnly: _savedOnly,
                          hasQuery: _searchController.text.trim().isNotEmpty,
                          onReset: _resetSearchAndFilters,
                        )
                      else
                        _MedicationList(
                          medications: medications,
                          surface: _surface,
                          ink: _ink,
                          muted: _muted,
                          line: _line,
                          onOpenMedication: _openMedication,
                        ),
                    ],
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

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.ink,
    required this.muted,
    required this.savedOnly,
    this.onBack,
    required this.onSavedPressed,
  });

  final Color ink;
  final Color muted;
  final bool savedOnly;
  final VoidCallback? onBack;
  final VoidCallback onSavedPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (onBack != null) ...[
          LiquidGlassBackButton(
            key: const Key('medicationLibraryBackButton'),
            semanticLabel: 'Back to scan review',
            onPressed: onBack!,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXPLORE SAFELY',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .48,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Medication Library',
                style: AppTextStyles.pageTitle.copyWith(color: ink),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          selected: savedOnly,
          label: savedOnly ? 'Show all medications' : 'Show saved medications',
          child: AppIconButton(
            key: const Key('savedMedicationsButton'),
            icon: savedOnly
                ? CupertinoIcons.bookmark_fill
                : CupertinoIcons.bookmark,
            tooltip: savedOnly
                ? 'Show all medications'
                : 'Show saved medications',
            selected: savedOnly,
            onPressed: onSavedPressed,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onFilterPressed,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSearchField(
      controller: controller,
      textFieldKey: const Key('medicationSearchField'),
      hintText: 'Search medication or condition',
      onChanged: onChanged,
      trailing: Semantics(
        button: true,
        label: 'Filter medications',
        child: AppIconButton(
          key: const Key('medicationFilterButton'),
          icon: CupertinoIcons.slider_horizontal_3,
          tooltip: 'Filter medications',
          onPressed: onFilterPressed,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    required this.ink,
    required this.onPressed,
  });

  final String title;
  final String action;
  final Color ink;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(color: ink),
          ),
        ),
        AppButton(
          label: action,
          onPressed: onPressed,
          variant: AppButtonVariant.tertiary,
          compact: true,
        ),
      ],
    );
  }
}

class _MedicationList extends StatelessWidget {
  const _MedicationList({
    required this.medications,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.onOpenMedication,
  });

  final List<_Medication> medications;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final ValueChanged<_Medication> onOpenMedication;

  @override
  Widget build(BuildContext context) {
    return _LibraryGlassSurface(
      baseColor: surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth >= 760;
          Widget rowFor(int index) => _MedicationRow(
            medication: medications[index],
            ink: ink,
            muted: muted,
            onTap: () => onOpenMedication(medications[index]),
          );

          if (landscape) {
            final columnWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              key: const Key('medicationLibraryLandscapeGrid'),
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var index = 0; index < medications.length; index++)
                  SizedBox(width: columnWidth, child: rowFor(index)),
              ],
            );
          }

          return Column(
            children: [
              for (var index = 0; index < medications.length; index++) ...[
                rowFor(index),
                if (index != medications.length - 1)
                  Divider(height: 1, indent: 11, color: line, thickness: .7),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LibraryGlassSurface extends StatelessWidget {
  const _LibraryGlassSurface({required this.baseColor, required this.child});

  final Color baseColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final glassBase = baseColor.withValues(alpha: dark ? .78 : .72);
    final glassTint = primary.withValues(alpha: dark ? .045 : .025);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: WebAwareBlur(
        sigma: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.alphaBlend(glassTint, glassBase),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? .10 : .50),
              width: .7,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  const _MedicationRow({
    required this.medication,
    required this.ink,
    required this.muted,
    this.onTap,
  });

  final _Medication medication;
  final Color ink;
  final Color muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: Key('medication${medication.name}'),
      onPressed: onTap,
      autoManageBusy: false,
      enabled: onTap != null,
      semanticLabel: 'Open ${titleCaseDisplay(medication.name)} details',
      borderRadius: BorderRadius.zero,
      hoverScale: 1,
      hoverOffset: Offset.zero,
      pressedScale: .99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            MedicationArtwork(
              key: Key('libraryMedicationArtwork_${medication.id}'),
              seed: medication.id,
              label: titleCaseDisplay(medication.name),
              size: 50,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleCaseDisplay(medication.name),
                    style: TextStyle(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    titleCaseDisplay(medication.description),
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Color(0xFFB5B5BA),
              size: 15,
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.ink,
    required this.muted,
    required this.savedOnly,
    required this.hasQuery,
    required this.onReset,
  });

  final Color ink;
  final Color muted;
  final bool savedOnly;
  final bool hasQuery;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(CupertinoIcons.search, color: muted, size: 28),
          const SizedBox(height: 10),
          Text(
            savedOnly
                ? 'No Saved Medications Yet'
                : hasQuery
                ? 'No Medications Found'
                : 'Search the medication catalog',
            style: TextStyle(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            savedOnly
                ? 'Save a medication to find it here.'
                : hasQuery
                ? 'Try another medication name or strength.'
                : 'Search by name, strength, or dosage form.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: savedOnly ? 'Show All Medications' : 'Clear Search',
            onPressed: onReset,
            variant: AppButtonVariant.secondary,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            rateLimited
                ? CupertinoIcons.timer
                : CupertinoIcons.wifi_exclamationmark,
            color: colors.error,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            rateLimited ? 'Catalog limit reached' : 'Catalog unavailable',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rateLimited
                ? 'Please wait a moment and try again.'
                : 'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                key: const Key('retryLibrarySearchButton'),
                label: 'Try Again',
                compact: true,
                onPressed: onRetry,
              ),
              AppButton(
                key: const Key('clearLibrarySearchButton'),
                label: 'Clear Search',
                compact: true,
                variant: AppButtonVariant.tertiary,
                onPressed: onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MedicationDetailScreen extends StatefulWidget {
  const MedicationDetailScreen({
    super.key,
    required this.medication,
    this.catalogClient,
    this.onBack,
    this.onAdded,
    this.onAddToSchedule,
    this.initialBookmarked = false,
    this.onBookmarkChanged,
  });

  final MedicationCatalogRecord medication;
  final MedicationCatalogClient? catalogClient;
  final VoidCallback? onBack;
  final VoidCallback? onAdded;
  final Future<bool> Function(
    BuildContext context,
    MedicationCatalogRecord medication,
  )?
  onAddToSchedule;
  final bool initialBookmarked;
  final Future<void> Function(bool saved)? onBookmarkChanged;

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  late bool _isBookmarked = widget.initialBookmarked;
  bool _isAdded = false;
  bool _isAdding = false;
  String? _addError;
  bool _isSavingBookmark = false;
  String? _bookmarkError;
  late MedicationCatalogRecord _medication = widget.medication;
  var _isLoadingDetails = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _isDark ? AppColors.darkBackground : const Color(0xFFF2F2F7);
  Color get _ink => _isDark ? AppColors.darkText : const Color(0xFF1C1C1E);
  Color get _muted =>
      _isDark ? AppColors.darkMutedText : const Color(0xFF6E6E73);
  Color get _line => _isDark ? AppColors.darkOutline : const Color(0xFFD9D9DE);

  void _goBack() {
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _addToSchedule() async {
    if (_isAdding || _isAdded) return;
    setState(() {
      _isAdding = true;
      _addError = null;
    });
    try {
      final add = widget.onAddToSchedule;
      if (add == null) {
        throw StateError('Scheduling is unavailable.');
      }
      final added = await add(context, _medication);
      if (!mounted || !added) return;
      setState(() => _isAdded = true);
      widget.onAdded?.call();
    } catch (_) {
      if (mounted) {
        setState(() => _addError = 'Could not add to Calendar. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final client = widget.catalogClient;
    if (client == null) return;
    setState(() => _isLoadingDetails = true);
    try {
      final details = await client.getDetails(widget.medication.rxcui);
      if (mounted) setState(() => _medication = details);
    } catch (_) {
      // The RxNorm result is still useful when label enrichment is offline.
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _showSideEffects() async {
    final body = _medication.warnings.isEmpty
        ? 'No structured warning information was returned for this label. Review the current label and ask your pharmacist or care team about side effects.'
        : _medication.warnings.join('\n\n');
    await pushInAppPage<void>(
      context,
      builder: (context) =>
          _InformationPage(title: 'Common Side Effects', body: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroHeight = (media.size.height * .17).clamp(142.0, 172.0);
    final contentWidth = media.size.width >= 900
        ? responsiveContentWidth(context, nativeMaxWidth: 1120)
        : 520.0;
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: _DetailHero(
              topPadding: media.padding.top,
              bookmarked: _isBookmarked,
              bookmarkBusy: _isSavingBookmark,
              onBack: _goBack,
              onBookmark: _toggleBookmark,
            ),
          ),
          Positioned.fill(
            top: heroHeight - 22,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: ColoredBox(
                color: _background,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: SingleChildScrollView(
                      key: const Key('medicationDetailScrollView'),
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.pageGutterOf(context),
                        AppSpacing.xl,
                        AppSpacing.pageGutterOf(context),
                        96 * media.textScaler.scale(1) + media.padding.bottom,
                      ),
                      child: _DetailContent(
                        bookmarkFeedback: _bookmarkError == null
                            ? null
                            : Semantics(
                                key: const Key('medicationDetailBookmarkError'),
                                liveRegion: true,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _bookmarkError!,
                                      style: AppTextStyles.body.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    AppButton(
                                      key: const Key(
                                        'retryMedicationBookmarkButton',
                                      ),
                                      label: 'Retry',
                                      loadingLabel: 'Saving',
                                      busy: _isSavingBookmark,
                                      onPressed: _isSavingBookmark
                                          ? null
                                          : _toggleBookmark,
                                      variant: AppButtonVariant.secondary,
                                      compact: true,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],
                                ),
                              ),
                        medication: _medication,
                        ink: _ink,
                        muted: _muted,
                        line: _line,
                        onViewAllSideEffects: _showSideEffects,
                        loading: _isLoadingDetails,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyAddAction(
              added: _isAdded,
              bottomPadding: media.padding.bottom,
              dark: _isDark,
              busy: _isAdding,
              error: _addError,
              onPressed: _isAdded ? null : _addToSchedule,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    if (_isSavingBookmark) return;
    final next = !_isBookmarked;
    setState(() {
      _isBookmarked = next;
      _isSavingBookmark = true;
    });
    try {
      await widget.onBookmarkChanged?.call(next);
      if (mounted) setState(() => _bookmarkError = null);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isBookmarked = !next;
          _bookmarkError = 'Could not update saved medications. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSavingBookmark = false);
    }
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.topPadding,
    required this.bookmarked,
    required this.bookmarkBusy,
    required this.onBack,
    required this.onBookmark,
  });

  final double topPadding;
  final bool bookmarked;
  final bool bookmarkBusy;
  final VoidCallback onBack;
  final Future<void> Function() onBookmark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.surfaceContainerHighest),
        Positioned(
          left: 10,
          right: 10,
          top: topPadding + 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LiquidGlassBackButton(
                key: const Key('medicationDetailBackButton'),
                semanticLabel: 'Back to Library',
                onPressed: onBack,
              ),
              _HeroButton(
                key: const Key('medicationDetailBookmarkButton'),
                semanticLabel: bookmarked
                    ? 'Remove saved medication'
                    : 'Save medication',
                icon: bookmarked
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                onPressed: onBookmark,
                busy: bookmarkBusy,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String semanticLabel;
  final IconData icon;
  final FutureOr<void> Function() onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => AppIconButton(
    icon: icon,
    tooltip: semanticLabel,
    onPressed: onPressed,
    busy: busy,
    selected: icon == CupertinoIcons.bookmark_fill,
  );
}

class _CurrentLabelButton extends StatefulWidget {
  const _CurrentLabelButton({required this.url});
  final String url;
  @override
  State<_CurrentLabelButton> createState() => _CurrentLabelButtonState();
}

class _CurrentLabelButtonState extends State<_CurrentLabelButton> {
  String? _error;
  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final opened = await launchUrl(
        Uri.parse(widget.url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Label unavailable');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to open the label. Check your connection and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppButton(
        key: const Key('openMedicationLabelButton'),
        label: 'Open the current label',
        icon: CupertinoIcons.link,
        variant: AppButtonVariant.tertiary,
        compact: true,
        onPressed: _open,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const Key('medicationLabelError'),
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ),
    ],
  );
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.medication,
    required this.ink,
    required this.muted,
    required this.line,
    required this.onViewAllSideEffects,
    required this.loading,
    this.bookmarkFeedback,
  });

  final MedicationCatalogRecord medication;
  final Color ink;
  final Color muted;
  final Color line;
  final VoidCallback onViewAllSideEffects;
  final bool loading;
  final Widget? bookmarkFeedback;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?bookmarkFeedback,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleCaseDisplay(medication.name),
                      style: AppTextStyles.pageTitle.copyWith(color: ink),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      titleCaseDisplay(
                        [
                          medication.genericName,
                          medication.doseDescription,
                          medication.route,
                        ].where((value) => value.isNotEmpty).join(' · '),
                      ),
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Rx',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          _MedicationFacts(
            medication: medication,
            ink: ink,
            muted: muted,
            line: line,
          ),
          const SizedBox(height: 10),
          Text(
            'Source: RxNorm ${medication.sourceVersion.isEmpty ? 'current' : medication.sourceVersion}',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          if (medication.warnings.isNotEmpty ||
              medication.indications.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Label enrichment: openFDA',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
          if (medication.labelUrl != null) ...[
            const SizedBox(height: 4),
            _CurrentLabelButton(url: medication.labelUrl!),
          ],
          _CopySection(
            title: 'What It Treats',
            body: medication.indications.isEmpty
                ? 'Review the current label for indications and usage.'
                : medication.indications.join('\n\n'),
            ink: ink,
            muted: muted,
            line: line,
          ),
          const SizedBox(height: 16),
          _SafetyCallout(warnings: medication.warnings),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              Text(
                'Common Side Effects',
                style: AppTextStyles.sectionTitle.copyWith(color: ink),
              ),
              AppButton(
                label: 'View All',
                semanticLabel: 'View all side effects',
                onPressed: onViewAllSideEffects,
                variant: AppButtonVariant.tertiary,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final effect
                  in medication.warnings.isEmpty
                      ? ['See label for side effects']
                      : medication.warnings.take(3))
                Text(
                  effect,
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicationFacts extends StatelessWidget {
  const _MedicationFacts({
    required this.medication,
    required this.ink,
    required this.muted,
    required this.line,
  });

  final MedicationCatalogRecord medication;
  final Color ink;
  final Color muted;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final facts = [
      (CupertinoIcons.capsule, 'Dosage form', medication.form),
      (CupertinoIcons.gauge, 'Strength', medication.strength),
      (CupertinoIcons.location, 'Route', medication.route),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: line, width: .7),
          bottom: BorderSide(color: line, width: .7),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < facts.length; index++) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Column(
                  children: [
                    Icon(facts[index].$1, color: primary, size: 18),
                    const SizedBox(height: 6),
                    Text(
                      facts[index].$2,
                      style: AppTextStyles.caption.copyWith(color: muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      facts[index].$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (index < facts.length - 1)
              SizedBox(
                height: 54,
                child: VerticalDivider(width: 1, color: line),
              ),
          ],
        ],
      ),
    );
  }
}

class _CopySection extends StatelessWidget {
  const _CopySection({
    required this.title,
    required this.body,
    required this.ink,
    required this.muted,
    required this.line,
  });

  final String title;
  final String body;
  final Color ink;
  final Color muted;
  final Color line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line, width: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.sectionTitle.copyWith(color: ink)),
          const SizedBox(height: 7),
          Text(body, style: AppTextStyles.body.copyWith(color: muted)),
        ],
      ),
    );
  }
}

class _SafetyCallout extends StatelessWidget {
  const _SafetyCallout({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final visibleWarnings = warnings.isEmpty
        ? const ['Verify the current label with your pharmacist or care team.']
        : warnings.take(3).toList(growable: false);
    final panelColor = dark ? const Color(0xFF2B251D) : const Color(0xFFFFF6E8);
    final titleColor = dark ? const Color(0xFFFFC56B) : const Color(0xFF7F4B1D);
    final bodyColor = dark ? const Color(0xFFE8DCCB) : const Color(0xFF7F4B1D);
    final iconColor = dark ? const Color(0xFFFFB340) : const Color(0xFFA8641E);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? const Color(0xFF5A4528) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Important Safety',
            style: AppTextStyles.sectionTitle.copyWith(color: titleColor),
          ),
          const SizedBox(height: 9),
          for (final warning in visibleWarnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      CupertinoIcons.exclamationmark_circle_fill,
                      color: iconColor,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: AppTextStyles.body.copyWith(color: bodyColor),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StickyAddAction extends StatelessWidget {
  const _StickyAddAction({
    required this.added,
    required this.bottomPadding,
    required this.dark,
    required this.onPressed,
    required this.busy,
    this.error,
  });

  final bool added;
  final double bottomPadding;
  final bool dark;
  final Future<void> Function()? onPressed;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: WebAwareBlur(
        sigma: 20,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageGutterOf(context),
            AppSpacing.md,
            AppSpacing.pageGutterOf(context),
            bottomPadding + AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: dark
                ? AppColors.darkSurface.withValues(alpha: .90)
                : const Color(0xE6F9F9F9),
            border: const Border(
              top: BorderSide(color: Color(0x333C3C43), width: .5),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      key: const Key('medicationDetailAddError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppButton(
                  key: const Key('addMedicationButton'),
                  label: added ? 'Added to My Schedule' : 'Add to My Schedule',
                  loadingLabel: 'Adding to Calendar',
                  busy: busy,
                  icon: added
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.calendar_badge_plus,
                  onPressed: onPressed,
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InAppPageScaffold(
      title: title,
      child: ListView(
        key: Key('informationPage$title'),
        padding: EdgeInsets.zero,
        children: [
          Text(
            body,
            style: AppTextStyles.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Done',
              onPressed: () => Navigator.pop(context),
              expand: true,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Medication {
  const _Medication({
    required this.id,
    required this.name,
    required this.description,
    this.catalogRecord,
  });

  factory _Medication.fromCatalog(MedicationCatalogRecord record) {
    return _Medication(
      id: record.rxcui,
      name: record.name,
      description: record.description,
      catalogRecord: record,
    );
  }

  final String id;
  final String name;
  final String description;
  final MedicationCatalogRecord? catalogRecord;
}
