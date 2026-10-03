import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'in_app_page.dart';
import 'web_floating_notice_card.dart';

/// Supply this at build time with `--dart-define=MEDIARY_SUPPORT_EMAIL=...`.
/// Keeping it configurable avoids publishing an unverified personal address.
const mediarySupportEmail = String.fromEnvironment('MEDIARY_SUPPORT_EMAIL');

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const InAppPageScaffold(
      title: 'Privacy Policy',
      child: _LegalContent(
        sections: [
          (
            'What Mediary stores',
            'Mediary stores account details, medication schedules, dose activity, and profile information needed to provide the app. Camera images are used for the scan flow and are not presented as medical advice.',
          ),
          (
            'How information is used',
            'Information is used to show your dashboard, schedule reminders, save your library, and provide medication reference results. Mediary does not sell personal information.',
          ),
          (
            'Your choices',
            'You can manage camera access in device settings, export the information available to the app, and delete or update profile information from the account screens.',
          ),
          (
            'Important limitation',
            'Mediary is a development prototype and is not a medical device or a substitute for a pharmacist or clinician.',
          ),
        ],
      ),
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const InAppPageScaffold(
      title: 'Terms of Use',
      child: _LegalContent(
        sections: [
          (
            'Use of the app',
            'Use Mediary only for personal organization and medication reference. Review every scan result with the original label and a qualified professional before making health decisions.',
          ),
          (
            'No medical advice',
            'Scan results, catalog details, reminders, and reports may be incomplete or incorrect. They do not diagnose, prescribe, or replace professional care.',
          ),
          (
            'Accounts and security',
            'Keep your account credentials private and notify the app owner if you believe your account has been accessed without permission.',
          ),
          (
            'Availability',
            'Mediary is provided as a development prototype. Features and reference data may change or be unavailable without notice.',
          ),
        ],
      ),
    );
  }
}

class ThankYouPage extends StatelessWidget {
  const ThankYouPage({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('thankYouPage'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Thank you for joining Mediary',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your account is ready. Check your inbox if email verification is required, then return to continue.',
                    textAlign: TextAlign.center,
                  ),
                  if (onDone != null) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('thankYouDoneButton'),
                      onPressed: onDone,
                      child: const Text('Continue'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContactSupportPage extends StatelessWidget {
  const ContactSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hasAddress = mediarySupportEmail.trim().isNotEmpty;
    return InAppPageScaffold(
      title: 'Contact Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'For account or app questions, contact the Mediary team using the support address configured for this build.',
          ),
          const SizedBox(height: 20),
          if (hasAddress)
            FilledButton.icon(
              icon: const Icon(Icons.mail_outline),
              label: Text(mediarySupportEmail),
              onPressed: () =>
                  launchUrl(Uri(scheme: 'mailto', path: mediarySupportEmail)),
            )
          else
            Text(
              'Support contact is not configured yet.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  const _LegalContent({required this.sections});

  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      children: [
        for (final section in sections) ...[
          Text(section.$1, style: text.titleMedium),
          const SizedBox(height: 8),
          Text(section.$2, style: text.bodyMedium?.copyWith(height: 1.45)),
          const SizedBox(height: 22),
        ],
        Text(
          'Last updated: September 2026',
          style: text.bodySmall?.copyWith(color: AppColors.lightMutedText),
        ),
      ],
    );
  }
}

class CookieBanner extends StatelessWidget {
  const CookieBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        minimum: const EdgeInsets.all(webFloatingNoticeInset),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: webFloatingNoticeMaxWidth,
          ),
          child: WebFloatingNoticeCard(
            key: const Key('cookieBanner'),
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & terms',
            body: 'Mediary uses essential browser storage. Optional analytics is currently off.',
            actions: [
              TextButton(
                key: const Key('cookiePrivacyButton'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyPage(),
                  ),
                ),
                child: const Text('Privacy'),
              ),
              TextButton(
                key: const Key('cookieTermsButton'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const TermsPage()),
                ),
                child: const Text('Terms'),
              ),
              FilledButton(
                key: const Key('cookieDismissButton'),
                onPressed: onDismiss,
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
