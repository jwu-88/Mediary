import 'package:flutter/material.dart';

const webFloatingNoticeInset = 16.0;
const webFloatingNoticeMaxWidth = 360.0;

/// Shared visual treatment for transient web notices and consent prompts.
///
/// Keeping this surface in one place prevents privacy/terms prompts from
/// drifting away from the medication notification treatment as either UI
/// evolves.
class WebFloatingNoticeCard extends StatelessWidget {
  const WebFloatingNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(body),
                    ],
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
