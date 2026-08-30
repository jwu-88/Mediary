import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/web_navigation_sidebar.dart';

void main() {
  testWidgets('final web destination is Settings', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebNavigationSidebar(currentIndex: 4, onTap: (_) {}),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'\bSettings\b')),
      findsAtLeastNWidgets(1),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('webNavItem-4')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      CupertinoIcons.gear_solid,
    );
    semantics.dispose();
  });
}
