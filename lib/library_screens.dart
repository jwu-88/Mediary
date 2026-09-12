import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_interactions.dart';
import 'app_layout.dart';
import 'app_theme.dart';
import 'data/medication_catalog_client.dart';
import 'in_app_page.dart';
import 'liquid_glass_back_button.dart';
import 'liquid_glass_search_field.dart';

class MedicationLibraryScreen extends StatefulWidget {
  const MedicationLibraryScreen({
    super.key,
    this.catalogClient,
    this.onSavedChanged,
    this.initialSavedMedicationIds = const {},
    this.bottomPadding = 128,
  });

  final MedicationCatalogClient? catalogClient;
  final Future<void> Function(
    String medicationId,
    bool saved, {
    String? catalogVersion,
  })?
  onSavedChanged;
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
    setState(() {
      _searchError = null;
      _results = const [];
      _isSearching = query.length >= 2;
    });
    if (query.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
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
        ? responsiveContentWidth(context, nativeMaxWidth: 760)
        : 520.0;
    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: CustomScrollView(
              key: const Key('medicationLibraryScrollView'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      _LibraryHeader(
                        ink: _ink,
                        muted: _muted,
                        savedOnly: _savedOnly,
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
                      Text(
                        'Catalog data from RxNorm (U.S. National Library of Medicine). Label details may come from openFDA. Verify with your pharmacist or care team.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    20,
                    16,
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
                        _LibraryError(message: _searchError ?? _savedError!)
                      else if (medications.isEmpty)
                        _EmptyResults(
                          ink: _ink,
                          muted: _muted,
                          savedOnly: _savedOnly,
                          hasQuery: _searchController.text.trim().isNotEmpty,
                          onReset: () {
                            _searchController.clear();
                            setState(() => _savedOnly = false);
                          },
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
    required this.onSavedPressed,
  });

  final Color ink;
  final Color muted;
  final bool savedOnly;
  final VoidCallback onSavedPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
                style: TextStyle(
                  color: ink,
                  fontSize: 28,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          selected: savedOnly,
          label: savedOnly ? 'Show all medications' : 'Show saved medications',
          child: ResponsiveCupertinoButton(
            buttonKey: const Key('savedMedicationsButton'),
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            onPressed: onSavedPressed,
            semanticLabel: savedOnly
                ? 'Show all medications'
                : 'Show saved medications',
            child: Icon(
              savedOnly
                  ? CupertinoIcons.bookmark_fill
                  : CupertinoIcons.bookmark,
              color: primary,
              size: 21,
            ),
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
    final primary = Theme.of(context).colorScheme.primary;
    return LiquidGlassSearchField(
      controller: controller,
      textFieldKey: const Key('medicationSearchField'),
      hintText: 'Search medication or condition',
      onChanged: onChanged,
      trailing: Semantics(
        button: true,
        label: 'Filter medications',
        child: ResponsiveCupertinoButton(
          buttonKey: const Key('medicationFilterButton'),
          minimumSize: const Size(44, 52),
          padding: EdgeInsets.zero,
          onPressed: onFilterPressed,
          semanticLabel: 'Filter medications',
          child: Icon(
            CupertinoIcons.slider_horizontal_3,
            color: primary,
            size: 20,
          ),
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
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.25,
            ),
          ),
        ),
        ResponsiveCupertinoButton(
          minimumSize: const Size(44, 36),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          onPressed: onPressed,
          semanticLabel: action,
          child: Text(
            action,
            style: TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
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
      child: Column(
        children: [
          for (var index = 0; index < medications.length; index++) ...[
            _MedicationRow(
              medication: medications[index],
              ink: ink,
              muted: muted,
              onTap: () => onOpenMedication(medications[index]),
            ),
            if (index != medications.length - 1)
              Divider(height: 1, indent: 77, color: line, thickness: .7),
          ],
        ],
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
      semanticLabel: 'Open ${medication.name} details',
      borderRadius: BorderRadius.zero,
      hoverScale: 1,
      hoverOffset: Offset.zero,
      pressedScale: .99,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 54,
              child: _MedicationArtwork(
                assetPath: '',
                cacheWidth: 216,
                fallbackColor: const Color(0xFFDDE4EB),
                fallbackIcon: CupertinoIcons.capsule_fill,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    medication.description,
                    style: TextStyle(color: muted, fontSize: 11),
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            savedOnly
                ? 'Save a medication to find it here.'
                : hasQuery
                ? 'Try another medication name or strength.'
                : 'Search by name, strength, or dosage form.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          ResponsiveCupertinoButton(
            onPressed: onReset,
            semanticLabel: 'Show all medications',
            child: Text(savedOnly ? 'Show All Medications' : 'Clear Search'),
          ),
        ],
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message});

  final String message;

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
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rateLimited
                ? 'Please wait a moment and try again.'
                : 'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
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
    this.initialBookmarked = false,
    this.onBookmarkChanged,
  });

  final MedicationCatalogRecord medication;
  final MedicationCatalogClient? catalogClient;
  final VoidCallback? onBack;
  final VoidCallback? onAdded;
  final bool initialBookmarked;
  final Future<void> Function(bool saved)? onBookmarkChanged;

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  late bool _isBookmarked = widget.initialBookmarked;
  bool _isAdded = false;
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

  void _toggleAdded() {
    setState(() => _isAdded = !_isAdded);
    if (_isAdded) widget.onAdded?.call();
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
    final heroHeight = (media.size.height * .332).clamp(250.0, 290.0);
    final contentWidth = media.size.width >= 900
        ? responsiveContentWidth(context, nativeMaxWidth: 760)
        : 520.0;
    return ColoredBox(
      color: _background,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: _DetailHero(
              topPadding: media.padding.top,
              bookmarked: _isBookmarked,
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
                        16,
                        20,
                        16,
                        118 + media.padding.bottom,
                      ),
                      child: _DetailContent(
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
              onPressed: _toggleAdded,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    final next = !_isBookmarked;
    setState(() => _isBookmarked = next);
    try {
      await widget.onBookmarkChanged?.call(next);
    } catch (_) {
      if (mounted) setState(() => _isBookmarked = !next);
    }
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.topPadding,
    required this.bookmarked,
    required this.onBack,
    required this.onBookmark,
  });

  final double topPadding;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _MedicationArtwork(
          assetPath: '',
          fallbackColor: const Color(0xFFDDE4EB),
          fallbackIcon: CupertinoIcons.capsule_fill,
          borderRadius: BorderRadius.zero,
        ),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0x3D0A0F19))),
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
                overImage: true,
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
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ResponsiveCupertinoButton(
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x33000000),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x55FFFFFF), width: .7),
          ),
          child: SizedBox.square(
            dimension: 38,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.medication,
    required this.ink,
    required this.muted,
    required this.line,
    required this.onViewAllSideEffects,
    required this.loading,
  });

  final MedicationCatalogRecord medication;
  final Color ink;
  final Color muted;
  final Color line;
  final VoidCallback onViewAllSideEffects;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: TextStyle(
                      color: ink,
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      medication.genericName,
                      medication.doseDescription,
                      medication.route,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
        const SizedBox(height: 17),
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
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(medication.labelUrl!),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(CupertinoIcons.link, size: 13),
            label: const Text('Open the current label'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 32),
              alignment: Alignment.centerLeft,
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
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
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Common Side Effects',
                style: TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.25,
                ),
              ),
            ),
            ResponsiveCupertinoButton(
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              onPressed: onViewAllSideEffects,
              semanticLabel: 'View all side effects',
              child: Text(
                'View All',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                      style: TextStyle(color: muted, fontSize: 9),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      facts[index].$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: 11,
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
          Text(
            title,
            style: TextStyle(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: TextStyle(color: muted, fontSize: 11, height: 1.55),
          ),
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
    final visibleWarnings = warnings.isEmpty
        ? const ['Verify the current label with your pharmacist or care team.']
        : warnings.take(3).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Important Safety',
            style: TextStyle(
              color: Color(0xFF7F4B1D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          for (final warning in visibleWarnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      CupertinoIcons.exclamationmark_circle_fill,
                      color: Color(0xFFA8641E),
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        color: Color(0xFF7F4B1D),
                        fontSize: 11,
                        height: 1.25,
                      ),
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
  });

  final bool added;
  final double bottomPadding;
  final bool dark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRect(
      child: WebAwareBlur(
        sigma: 20,
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding + 10),
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
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                key: const Key('addMedicationButton'),
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: added
                      ? const Color(0xFF278E49)
                      : colors.primary,
                  foregroundColor: added ? Colors.white : colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  elevation: 0,
                ),
                icon: Icon(
                  added
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.calendar_badge_plus,
                  size: 18,
                ),
                label: Text(
                  added ? 'Added to My Schedule' : 'Add to My Schedule',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MedicationArtwork extends StatelessWidget {
  const _MedicationArtwork({
    required this.assetPath,
    required this.fallbackColor,
    required this.fallbackIcon,
    required this.borderRadius,
    this.cacheWidth = 1200,
  });

  final String assetPath;
  final Color fallbackColor;
  final IconData fallbackIcon;
  final BorderRadius borderRadius;
  final int cacheWidth;

  Widget _fallback() {
    return ColoredBox(
      color: fallbackColor,
      child: Center(
        child: Icon(fallbackIcon, color: const Color(0xAA6E4A52), size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (assetPath.isEmpty) {
      return ClipRRect(borderRadius: borderRadius, child: _fallback());
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _fallback();
        },
        errorBuilder: (context, error, stackTrace) => _fallback(),
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
