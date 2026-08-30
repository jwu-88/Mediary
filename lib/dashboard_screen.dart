import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.now,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? now;

  static const _background = Color(0xFFF2F2F7);
  static const _surface = Color(0xFFFFFFFF);
  static const _label = Color(0xFF515157);
  static const _secondaryLabel = Color(0xFF6E6E73);
  static const _separator = Color(0xFFD9D9DE);
  static const _action = Color(0xFF0A62D0);
  static const _taken = Color(0xFF279F49);
  static const _orange = Color(0xFFE77B00);

  String get _name {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final emailName = email.split('@').first.trim();
    return emailName.isEmpty ? 'there' : emailName;
  }

  String get _initial {
    final parts = _name.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return _name[0].toUpperCase();
  }

  String get _greetingName => _name.split(RegExp(r'\s+')).first;

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              key: const Key('dashboardScrollView'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(today),
                            key: const Key('dashboardDate'),
                            style: const TextStyle(
                              color: _secondaryLabel,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .35,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Good morning, $_greetingName',
                            key: const Key('dashboardGreeting'),
                            style: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontSize: 27,
                              height: 1.12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ProfileAvatar(photoUrl: photoUrl, initials: _initial),
                  ],
                ),
                const SizedBox(height: 28),
                const _SectionHeader(
                  title: 'Weekly progress',
                  actionLabel: 'View report',
                ),
                const SizedBox(height: 6),
                const _AdherenceSummary(),
                const SizedBox(height: 22),
                const _SectionHeader(
                  title: 'Today’s schedule',
                  actionLabel: 'Add',
                  actionIcon: CupertinoIcons.add,
                ),
                const SizedBox(height: 8),
                const _ScheduleList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, required this.initials});

  final String? photoUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFDCE8FA),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: DashboardScreen._action,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return ClipOval(
      child: SizedBox.square(
        dimension: 42,
        child: photoUrl == null || photoUrl!.isEmpty
            ? fallback
            : Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.actionIcon,
  });

  final String title;
  final String actionLabel;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.25,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () {},
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            foregroundColor: DashboardScreen._action,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: actionIcon == null
              ? const SizedBox.shrink()
              : Icon(actionIcon, size: 15),
          label: Text(
            actionLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AdherenceSummary extends StatelessWidget {
  const _AdherenceSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DashboardScreen._separator)),
      ),
      child: const Row(
        children: [
          _ProgressRing(value: .92),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You’re right on track',
                  style: TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '11 of 12 doses taken this week',
                  style: TextStyle(
                    color: DashboardScreen._secondaryLabel,
                    fontSize: 12,
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

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 58,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: const Color(0xFFE1E1E6),
              color: DashboardScreen._taken,
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: const ColoredBox(
        color: DashboardScreen._surface,
        child: Column(
          children: [
            _DoseRow(
              name: 'Vitamin D3',
              details: '1000 IU · 8:00 AM',
              status: 'Taken',
              iconColor: DashboardScreen._taken,
              statusColor: DashboardScreen._taken,
            ),
            Divider(height: 1, indent: 68, color: DashboardScreen._separator),
            _DoseRow(
              name: 'Amoxicillin',
              details: '500 mg · 10:30 AM',
              status: 'Up next',
              iconColor: DashboardScreen._action,
            ),
            Divider(height: 1, indent: 68, color: DashboardScreen._separator),
            _DoseRow(
              name: 'Cetirizine',
              details: '10 mg · 8:00 PM',
              status: 'Tonight',
              iconColor: DashboardScreen._orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.name,
    required this.details,
    required this.status,
    required this.iconColor,
    this.statusColor = DashboardScreen._label,
  });

  final String name;
  final String details;
  final String status;
  final Color iconColor;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$name, $details, $status',
      child: InkWell(
        onTap: () {},
        child: SizedBox(
          height: 71,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Icon(
                    Icons.medication_rounded,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF1C1C1E),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        details,
                        style: const TextStyle(
                          color: DashboardScreen._secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == 'Taken') ...[
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: statusColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
