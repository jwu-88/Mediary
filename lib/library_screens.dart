import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'liquid_glass_back_button.dart';
import 'liquid_glass_search_field.dart';

class MedicationLibraryScreen extends StatefulWidget {
  const MedicationLibraryScreen({
    super.key,
    this.onOpenMedication,
    this.bottomPadding = 128,
  });

  final VoidCallback? onOpenMedication;
  final double bottomPadding;

  @override
  State<MedicationLibraryScreen> createState() =>
      _MedicationLibraryScreenState();
}

class _MedicationLibraryScreenState extends State<MedicationLibraryScreen> {
  static const _categories = [
    'Popular',
    'Allergy',
    'Pain',
    'Heart',
    'Vitamins',
  ];
  static const _medications = [
    _Medication(
      name: 'Amoxicillin',
      description: 'Antibiotic · Capsule',
      category: 'Popular',
      imageUrl: 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?auto=format&fit=crop&w=180&q=85',
      fallbackColor: Color(0xFFF5DDE6),
      fallbackIcon: CupertinoIcons.capsule,
    ),
    _Medication(
      name: 'Ibuprofen',
      description: 'Pain relief · Tablet',
      category: 'Pain',
      imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=180&q=85',
      fallbackColor: Color(0xFFDDEBF5),
      fallbackIcon: CupertinoIcons.bandage,
    ),
    _Medication(
      name: 'Cetirizine',
      description: 'Allergy relief · Tablet',
      category: 'Allergy',
      imageUrl: 'https://images.unsplash.com/photo-1550572017-edd951b55104?auto=format&fit=crop&w=180&q=85',
      fallbackColor: Color(0xFFE4E8E0),
      fallbackIcon: CupertinoIcons.drop,
    ),
  ];

  final _searchController = TextEditingController();
  String _selectedCategory = 'Popular';
  bool _savedOnly = false;
  bool _sortAlphabetically = false;
  final Set<String> _savedMedicationNames = {};

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _isDark ? const Color(0xFF101418) : const Color(0xFFF2F2F7);
  Color get _surface => _isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get _ink => _isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
  Color get _muted =>
      _isDark ? const Color(0xFFB8B8BE) : const Color(0xFF6E6E73);
  Color get _line =>
      _isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD9D9DE);
  List<_Medication> get _visibleMedications {
    final query = _searchController.text.trim().toLowerCase();
    final medications = _medications.where((medication) {
      final matchesCategory =
          _selectedCategory == 'Popular' ||
          medication.category == _selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          medication.name.toLowerCase().contains(query) ||
          medication.description.toLowerCase().contains(query);
      final matchesSaved =
          !_savedOnly || _savedMedicationNames.contains(medication.name);
      return matchesCategory && matchesQuery && matchesSaved;
    }).toList();
    if (_sortAlphabetically) {
      medications.sort((first, second) => first.name.compareTo(second.name));
    }
    return medications;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
  }

  void _toggleSavedOnly() {
    setState(() => _savedOnly = !_savedOnly);
  }

  void _toggleSort() {
    setState(() => _sortAlphabetically = !_sortAlphabetically);
  }

  Future<void> _showArticle() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => const _InformationSheet(
        title: 'Antibiotics 101',
        body: 'Take antibiotics exactly as prescribed and finish the full course. Skipping doses can make treatment less effective. Contact your care team if you have a reaction or questions.',
      ),
    );
  }

  Future<void> _openMedication(_Medication medication) async {
    if (medication.name == 'Amoxicillin' && widget.onOpenMedication != null) {
      widget.onOpenMedication!();
      return;
    }

    final saved = _savedMedicationNames.contains(medication.name);
    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) =>
          _MedicationPreviewSheet(medication: medication, saved: saved),
    );
    if (shouldSave == null || !mounted) return;
    setState(() {
      if (shouldSave) {
        _savedMedicationNames.add(medication.name);
      } else {
        _savedMedicationNames.remove(medication.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final medications = _visibleMedications;
    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
                        onChanged: (_) => setState(() {}),
                        onFilterPressed: () {
                          FocusScope.of(context).unfocus();
                          _toggleSavedOnly();
                        },
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoryTabs(
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    ink: _ink,
                    muted: _muted,
                    line: _line,
                    onSelected: _selectCategory,
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
                        title: 'Learn Today',
                        action: 'See All',
                        ink: _ink,
                        onPressed: _showArticle,
                      ),
                      const SizedBox(height: 10),
                      _FeaturedArticle(
                        surface: _surface,
                        ink: _ink,
                        muted: _muted,
                        line: _line,
                        onTap: _showArticle,
                      ),
                      const SizedBox(height: 24),
                      _SectionHeading(
                        title: _selectedCategory == 'Popular'
                            ? 'Popular Medications'
                            : '$_selectedCategory Medications',
                        action: _sortAlphabetically ? 'Featured' : 'A–Z',
                        ink: _ink,
                        onPressed: _toggleSort,
                      ),
                      const SizedBox(height: 10),
                      if (medications.isEmpty)
                        _EmptyResults(
                          ink: _ink,
                          muted: _muted,
                          savedOnly: _savedOnly,
                          onReset: () {
                            _searchController.clear();
                            setState(() {
                              _selectedCategory = 'Popular';
                              _savedOnly = false;
                            });
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
          child: CupertinoButton(
            key: const Key('savedMedicationsButton'),
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            onPressed: onSavedPressed,
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
        child: CupertinoButton(
          key: const Key('medicationFilterButton'),
          minimumSize: const Size(44, 52),
          padding: EdgeInsets.zero,
          onPressed: onFilterPressed,
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

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selectedCategory,
    required this.ink,
    required this.muted,
    required this.line,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final Color ink;
  final Color muted;
  final Color line;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 51,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line, width: .7)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 22),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return Semantics(
            button: true,
            selected: selected,
            child: InkWell(
              key: Key('medicationCategory$category'),
              onTap: () => onSelected(category),
              child: Container(
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: selected ? primary : muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
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
        CupertinoButton(
          minimumSize: const Size(44, 36),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          onPressed: onPressed,
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

class _FeaturedArticle extends StatelessWidget {
  const _FeaturedArticle({
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.onTap,
  });

  static const _imageUrl =
      'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?auto=format&fit=crop&w=500&q=88';

  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        key: const Key('featuredAntibioticsCard'),
        color: surface,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 150,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Antibiotics 101',
                          style: TextStyle(
                            color: ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Why completing your full course matters.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              'Read 3 min',
                              style: TextStyle(
                                color: primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.arrow_right,
                              color: primary,
                              size: 12,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 138,
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: line, width: .7)),
                  ),
                  child: _NetworkMedicationImage(
                    url: _imageUrl,
                    fallbackColor: const Color(0xFFF7C781),
                    fallbackIcon: CupertinoIcons.capsule_fill,
                    borderRadius: BorderRadius.zero,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: surface,
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
    return Semantics(
      button: onTap != null,
      label: 'Open ${medication.name} details',
      child: InkWell(
        key: Key('medication${medication.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 54,
                child: _NetworkMedicationImage(
                  url: medication.imageUrl,
                  fallbackColor: medication.fallbackColor,
                  fallbackIcon: medication.fallbackIcon,
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
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.ink,
    required this.muted,
    required this.savedOnly,
    required this.onReset,
  });

  final Color ink;
  final Color muted;
  final bool savedOnly;
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
            savedOnly ? 'No Saved Medications Yet' : 'No Medications Found',
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
                : 'Try another name or category.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          CupertinoButton(
            onPressed: onReset,
            child: const Text('Show All Medications'),
          ),
        ],
      ),
    );
  }
}

class MedicationDetailScreen extends StatefulWidget {
  const MedicationDetailScreen({super.key, this.onBack, this.onAdded});

  final VoidCallback? onBack;
  final VoidCallback? onAdded;

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  static const _heroImage =
      'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?auto=format&fit=crop&w=900&q=90';

  bool _isBookmarked = false;
  bool _isAdded = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _isDark ? const Color(0xFF101418) : const Color(0xFFF2F2F7);
  Color get _ink => _isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
  Color get _muted =>
      _isDark ? const Color(0xFFB8B8BE) : const Color(0xFF6E6E73);
  Color get _line =>
      _isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD9D9DE);

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

  Future<void> _showSideEffects() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => const _InformationSheet(
        title: 'Common Side Effects',
        body: 'Nausea\nDiarrhea\nRash\nHeadache\nChanges in taste\n\nSeek urgent care for swelling, trouble breathing, or a severe rash.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroHeight = (media.size.height * .332).clamp(250.0, 290.0);
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
              imageUrl: _heroImage,
              topPadding: media.padding.top,
              bookmarked: _isBookmarked,
              onBack: _goBack,
              onBookmark: () {
                setState(() => _isBookmarked = !_isBookmarked);
              },
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
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      key: const Key('medicationDetailScrollView'),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        20,
                        16,
                        118 + media.padding.bottom,
                      ),
                      child: _DetailContent(
                        ink: _ink,
                        muted: _muted,
                        line: _line,
                        onViewAllSideEffects: _showSideEffects,
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
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.imageUrl,
    required this.topPadding,
    required this.bookmarked,
    required this.onBack,
    required this.onBookmark,
  });

  final String imageUrl;
  final double topPadding;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _NetworkMedicationImage(
          url: imageUrl,
          fallbackColor: const Color(0xFFDDE4EB),
          fallbackIcon: CupertinoIcons.capsule_fill,
          borderRadius: BorderRadius.zero,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x6B0A0F19), Color(0x000A0F19), Color(0x160A0F19)],
              stops: [0, .35, 1],
            ),
          ),
        ),
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
      child: CupertinoButton(
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
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
    required this.ink,
    required this.muted,
    required this.line,
    required this.onViewAllSideEffects,
  });

  final Color ink;
  final Color muted;
  final Color line;
  final VoidCallback onViewAllSideEffects;

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
                    'Amoxicillin',
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
                    'Penicillin antibiotic · Prescription only',
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
        _MedicationFacts(ink: ink, muted: muted, line: line),
        _CopySection(
          title: 'What It Treats',
          body: 'Treats bacterial infections of the ear, nose, throat, urinary tract, and skin.',
          ink: ink,
          muted: muted,
          line: line,
        ),
        const SizedBox(height: 16),
        const _SafetyCallout(),
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
            CupertinoButton(
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              onPressed: onViewAllSideEffects,
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
            for (final effect in ['Nausea', 'Diarrhea', 'Rash'])
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
    required this.ink,
    required this.muted,
    required this.line,
  });

  final Color ink;
  final Color muted;
  final Color line;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const facts = [
      (CupertinoIcons.capsule, 'Common Form', 'Capsule'),
      (CupertinoIcons.gauge, 'Strengths', '250–500 mg'),
      (CupertinoIcons.clock, 'Typical Use', '5–14 days'),
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
  const _SafetyCallout();

  @override
  Widget build(BuildContext context) {
    const warnings = [
      'Do not use with a penicillin allergy',
      'Finish the full prescribed course',
      'Seek help for swelling or breathing trouble',
    ];
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
          for (final warning in warnings)
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding + 10),
          decoration: BoxDecoration(
            color: dark ? const Color(0xE61C1C1E) : const Color(0xE6F9F9F9),
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

class _MedicationPreviewSheet extends StatelessWidget {
  const _MedicationPreviewSheet({
    required this.medication,
    required this.saved,
  });

  final _Medication medication;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 64,
                child: _NetworkMedicationImage(
                  url: medication.imageUrl,
                  fallbackColor: medication.fallbackColor,
                  fallbackIcon: medication.fallbackIcon,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      medication.description,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Check the label and follow advice from your pharmacist or care team.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: Key('save${medication.name}Button'),
              onPressed: () => Navigator.pop(context, !saved),
              icon: Icon(
                saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
              ),
              label: Text(saved ? 'Remove From Saved' : 'Save Medication'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationSheet extends StatelessWidget {
  const _InformationSheet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkMedicationImage extends StatelessWidget {
  const _NetworkMedicationImage({
    required this.url,
    required this.fallbackColor,
    required this.fallbackIcon,
    required this.borderRadius,
  });

  final String url;
  final Color fallbackColor;
  final IconData fallbackIcon;
  final BorderRadius borderRadius;

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
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        fit: BoxFit.cover,
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
    required this.name,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.fallbackColor,
    required this.fallbackIcon,
  });

  final String name;
  final String description;
  final String category;
  final String imageUrl;
  final Color fallbackColor;
  final IconData fallbackIcon;
}
