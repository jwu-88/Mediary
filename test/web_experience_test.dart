import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/app_legal.dart';
import 'package:mediary/app_layout.dart';
import 'package:mediary/web_page_metadata.dart';
import 'package:mediary/web_floating_notice_card.dart';

void main() {
  testWidgets('legal pages expose their required content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('What Mediary stores'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: TermsPage()));
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('No medical advice'), findsOneWidget);
  });

  testWidgets('thank-you page provides a clear completion state', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(home: ThankYouPage(onDone: () => continued = true)),
    );

    expect(find.byKey(const Key('thankYouPage')), findsOneWidget);
    expect(find.text('Thank you for joining Mediary'), findsOneWidget);
    await tester.tap(find.byKey(const Key('thankYouDoneButton')));
    expect(continued, isTrue);
  });

  testWidgets('cookie banner can be dismissed and links to privacy', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CookieBanner(onDismiss: () => dismissed = true)),
      ),
    );

    expect(
      find.text(
        'Mediary uses essential browser storage. Optional analytics is currently off.',
      ),
      findsOneWidget,
    );
    expect(find.text('Privacy & terms'), findsOneWidget);
    expect(find.byKey(const Key('cookieTermsButton')), findsOneWidget);
    expect(find.byKey(const Key('cookieBanner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cookieDismissButton')));
    expect(dismissed, isTrue);
  });

  testWidgets(
    'cookie notice uses the same compact floating width as web notices',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CookieBanner(onDismiss: () {})),
        ),
      );

      final bannerSize = tester.getSize(find.byKey(const Key('cookieBanner')));
      expect(bannerSize.width, lessThanOrEqualTo(webFloatingNoticeMaxWidth));
      expect(bannerSize.width, greaterThan(300));

      final bannerRect = tester.getRect(find.byKey(const Key('cookieBanner')));
      expect(bannerRect.right, closeTo(1280 - webFloatingNoticeInset, 1));
      expect(bannerRect.bottom, closeTo(800 - webFloatingNoticeInset, 1));
    },
  );

  testWidgets('web metadata wrapper keeps its child available on native', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WebPageMetadata(
          title: 'Test page',
          description: 'Test description',
          child: Text('Metadata child'),
        ),
      ),
    );
    expect(find.text('Metadata child'), findsOneWidget);
  });

  testWidgets('responsive breakpoints distinguish phone and desktop widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(390, 844)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      ),
    );
    final phoneContext = tester.element(find.byType(SizedBox));
    expect(AppBreakpoints.isMobile(phoneContext), isTrue);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(1200, 800)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      ),
    );
    final desktopContext = tester.element(find.byType(SizedBox));
    expect(AppBreakpoints.isDesktop(desktopContext), isTrue);
  });
}
