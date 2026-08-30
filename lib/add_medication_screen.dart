import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    required this.imageUrl,
    required this.fallbackColor,
    this.fallbackIcon = CupertinoIcons.capsule_fill,
  });

  final String id;
  final String name;
  final String genericName;
  final String strength;
  final String form;
  final String imageUrl;
  final Color fallbackColor;
  final IconData fallbackIcon;

  String get doseDescription => '$strength · $form';
}

/// Realistic sample data used until the medication catalog is connected.
const defaultMedicationOptions = <MedicationOption>[
  MedicationOption(
    id: 'amoxicillin-500-capsule',
    name: 'Amoxicillin',
    genericName: 'Amoxicillin',
    strength: '500 mg',
    form: 'Capsule',
    imageUrl: 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?auto=format&fit=crop&w=180&q=85',
    fallbackColor: Color(0xFFF5DDE6),
  ),
  MedicationOption(
    id: 'ibuprofen-200-tablet',
    name: 'Ibuprofen',
    genericName: 'Ibuprofen',
    strength: '200 mg',
    form: 'Tablet',
    imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=180&q=85',
    fallbackColor: Color(0xFFDDEBF5),
    fallbackIcon: CupertinoIcons.bandage_fill,
  ),
  MedicationOption(
    id: 'cetirizine-10-tablet',
    name: 'Cetirizine',
    genericName: 'Cetirizine Hydrochloride',
    strength: '10 mg',
    form: 'Tablet',
    imageUrl: 'https://images.unsplash.com/photo-1550572017-edd951b55104?auto=format&fit=crop&w=180&q=85',
    fallbackColor: Color(0xFFE2E9DF),
    fallbackIcon: CupertinoIcons.drop_fill,
  ),
  MedicationOption(
    id: 'vitamin-d3-1000-softgel',
    name: 'Vitamin D3',
    genericName: 'Cholecalciferol',
    strength: '1000 IU',
    form: 'Softgel',
    imageUrl: 'https://images.unsplash.com/photo-1559757175-0eb30cd8c063?auto=format&fit=crop&w=180&q=85',
    fallbackColor: Color(0xFFFFE8C2),
    fallbackIcon: CupertinoIcons.sun_max_fill,
  ),
  MedicationOption(
    id: 'atorvastatin-20-tablet',
    name: 'Atorvastatin',
    genericName: 'Atorvastatin Calcium',
    strength: '20 mg',
    form: 'Tablet',
    imageUrl: 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?auto=format&fit=crop&w=180&q=85',
    fallbackColor: Color(0xFFE1E5F4),
    fallbackIcon: CupertinoIcons.heart_fill,
  ),
  MedicationOption(
    id: 'metformin-500-tablet',
    name: 'Metformin',
    genericName: 'Metformin Hydrochloride',
    strength: '500 mg',
    form: 'Tablet',
    imageUrl: 'https://images.unsplash.com/photo-1607619056574-7b8d3ee536b2?auto=format&fit=crop&w=180&q=85',
    fallbackColor: Color(0xFFDCEDEA),
    fallbackIcon: CupertinoIcons.circle_grid_hex_fill,
  ),
];

/// Pushes the medication picker and returns its selected medications.
///
/// A `null` result means that the person cancelled the picker.
Future<List<MedicationOption>?> showAddMedicationScreen(
  BuildContext context, {
  List<MedicationOption> medications = defaultMedicationOptions,
  Set<String> initiallySelectedIds = const {},
}) {
  return Navigator.of(context).push<List<MedicationOption>>(
    CupertinoPageRoute(
      builder: (_) => AddMedicationScreen(
        medications: medications,
        initiallySelectedIds: initiallySelectedIds,
      ),
    ),
  );
}

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({
    super.key,
    this.medications = defaultMedicationOptions,
    this.initiallySelectedIds = const {},
  });

  final List<MedicationOption> medications;
  final Set<String> initiallySelectedIds;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _searchController = TextEditingController();
  late final Set<String> _selectedIds = {
    for (final id in widget.initiallySelectedIds)
      if (widget.medications.any((medication) => medication.id == id)) id,
  };

  List<MedicationOption> get _visibleMedications {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.medications;
    return widget.medications.where((medication) {
      return medication.name.toLowerCase().contains(query) ||
          medication.genericName.toLowerCase().contains(query) ||
          medication.strength.toLowerCase().contains(query) ||
          medication.form.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleMedication(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _completeSelection() {
    final result = [
      for (final medication in widget.medications)
        if (_selectedIds.contains(medication.id)) medication,
    ];
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final medications = _visibleMedications;
    final selectionCount = _selectedIds.length;

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
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: LiquidGlassSearchField(
                    controller: _searchController,
                    textFieldKey: const Key('medicationSearchField'),
                    onChanged: (_) => setState(() {}),
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
                  child: medications.isEmpty
                      ? _EmptyMedicationSearch(
                          onClear: () {
                            _searchController.clear();
                            setState(() {});
                          },
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
                              onPressed: () => _toggleMedication(medication.id),
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
            constraints: const BoxConstraints(maxWidth: 528),
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
    final gradientColors = enabled
        ? dark
              ? [
                  Color.lerp(
                    enabledAccent,
                    Colors.white,
                    .18,
                  )!.withValues(alpha: highContrast ? .94 : .76),
                  enabledAccent.withValues(alpha: highContrast ? .98 : .88),
                  Color.lerp(
                    enabledAccent,
                    Colors.black,
                    .20,
                  )!.withValues(alpha: highContrast ? .96 : .84),
                ]
              : [
                  Color.lerp(
                    enabledAccent,
                    Colors.white,
                    .12,
                  )!.withValues(alpha: highContrast ? .98 : .84),
                  enabledAccent.withValues(alpha: highContrast ? .98 : .94),
                  Color.lerp(
                    enabledAccent,
                    Colors.black,
                    .16,
                  )!.withValues(alpha: highContrast ? .96 : .90),
                ]
        : dark
        ? [
            Colors.white.withValues(alpha: .10),
            colors.onSurface.withValues(alpha: .08),
            colors.onSurface.withValues(alpha: .05),
          ]
        : [
            Colors.white.withValues(alpha: .38),
            colors.onSurface.withValues(alpha: .08),
            colors.onSurface.withValues(alpha: .05),
          ];

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: enabledAccent.withValues(
                          alpha: dark ? .25 : .20,
                        ),
                        blurRadius: 22,
                        spreadRadius: -7,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                      stops: const [0, .46, 1],
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-.82, -1),
                            radius: 1.25,
                            colors: [
                              Colors.white.withValues(
                                alpha: enabled
                                    ? (dark ? .14 : .22)
                                    : (dark ? .08 : .20),
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(
                                alpha: enabled ? .08 : .02,
                              ),
                            ],
                            stops: const [0, .58, 1],
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onPressed,
                          borderRadius: BorderRadius.circular(25),
                          splashColor: Colors.white.withValues(alpha: .14),
                          highlightColor: Colors.white.withValues(alpha: .08),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: enabled
                                    ? colors.onPrimary
                                    : colors.onSurfaceVariant.withValues(
                                        alpha: .68,
                                      ),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
      button: true,
      selected: selected,
      label: '${medication.name}, ${medication.doseDescription}',
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .055)
            : Colors.transparent,
        child: InkWell(
          key: Key('medicationOption_${medication.id}'),
          onTap: onPressed,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox.square(
        dimension: 54,
        child: Image.network(
          medication.imageUrl,
          fit: BoxFit.cover,
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
  const _EmptyMedicationSearch({required this.onClear});

  final VoidCallback onClear;

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
              'No Medications Found',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different name or strength.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onClear, child: const Text('Clear Search')),
          ],
        ),
      ),
    );
  }
}
