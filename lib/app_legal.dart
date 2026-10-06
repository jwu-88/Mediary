import 'app_controls.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'in_app_page.dart';

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
            'You can manage camera access in device settings, copy an account summary, update your profile, and remove medication regimens and their records from the app. Account deletion and a full data export are not currently available.',
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
            child: SingleChildScrollView(
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
                    AppButton(
                      key: const Key('thankYouDoneButton'),
                      label: 'Continue',
                      onPressed: onDone,
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

class ContactSupportPage extends StatefulWidget {
  const ContactSupportPage({
    super.key,
    this.supportEmail = mediarySupportEmail,
    this.onOpenEmail,
  });
  final String supportEmail;
  final Future<bool> Function(Uri)? onOpenEmail;

  @override
  State<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends State<ContactSupportPage> {
  String? _status;
  bool _isError = false;

  void _setStatus(String? message, {bool error = false}) {
    if (mounted) {
      setState(() {
        _status = message;
        _isError = error;
      });
    }
  }

  Future<void> _openEmail() async {
    _setStatus(null);
    try {
      final uri = Uri(scheme: 'mailto', path: widget.supportEmail.trim());
      final opened = await (widget.onOpenEmail?.call(uri) ?? launchUrl(uri));
      if (!opened) {
        _setStatus(
          'Unable to open your email app. Copy the address below or try again.',
          error: true,
        );
      }
    } catch (_) {
      _setStatus(
        'Unable to open your email app. Copy the address below or try again.',
        error: true,
      );
    }
  }

  Future<void> _copyEmail() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.supportEmail.trim()));
      _setStatus('Support address copied.');
    } catch (_) {
      _setStatus(
        'Unable to copy the address. Select the address below to copy it, or try again.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAddress = widget.supportEmail.trim().isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    return InAppPageScaffold(
      title: 'Contact Support',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const Text(
            'For account or app questions, contact the Mediary team using the support address configured for this build.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (hasAddress) ...[
            AppButton(
              key: const Key('openSupportEmailButton'),
              icon: Icons.mail_outline,
              label: 'Open Email App',
              onPressed: _openEmail,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              key: const Key('copySupportEmailButton'),
              icon: Icons.copy_outlined,
              label: 'Copy Email Address',
              variant: AppButtonVariant.secondary,
              onPressed: _copyEmail,
            ),
            const SizedBox(height: AppSpacing.lg),
            SelectableText(
              widget.supportEmail.trim(),
              style: AppTextStyles.body.copyWith(color: colors.onSurface),
            ),
            if (_status != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                liveRegion: true,
                child: Text(
                  _status!,
                  key: const Key('supportActionStatus'),
                  style: AppTextStyles.body.copyWith(
                    color: _isError ? colors.error : colors.primary,
                  ),
                ),
              ),
            ],
          ] else
            Text(
              'Support contact is not configured yet.',
              style: TextStyle(color: colors.error),
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
          style: text.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Shared styling for the login form and its separate legal navigation.
BoxDecoration authPanelDecoration(ThemeData theme) {
  return BoxDecoration(
    color: theme.scaffoldBackgroundColor.withValues(
      alpha: theme.brightness == Brightness.dark ? .93 : .95,
    ),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: .55),
      width: .7,
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0x38000000),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );
}

/// Legal navigation stays outside the credential form.
class LegalLinksFooter extends StatelessWidget {
  const LegalLinksFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('authLegalFooter'),
      decoration: authPanelDecoration(Theme.of(context)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Privacy & Terms',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  AppButton(
                    key: const Key('authPrivacyPolicyLink'),
                    label: 'Privacy Policy',
                    icon: Icons.privacy_tip_outlined,
                    variant: AppButtonVariant.tertiary,
                    compact: true,
                    onPressed: () => pushInAppPage<void>(
                      context,
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  ),
                  AppButton(
                    key: const Key('authTermsLink'),
                    label: 'Terms of Use',
                    icon: Icons.description_outlined,
                    variant: AppButtonVariant.tertiary,
                    compact: true,
                    onPressed: () => pushInAppPage<void>(
                      context,
                      builder: (_) => const TermsPage(),
                    ),
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
