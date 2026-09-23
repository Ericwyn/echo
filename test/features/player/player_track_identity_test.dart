import 'package:echoes/features/player/widgets/player_track_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const titleStyle = TextStyle(fontSize: 20);
  const subtitleStyle = TextStyle(fontSize: 14);

  testWidgets('renders shared identity with title and subtitle heroes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerTrackIdentity(
            title: 'Track title',
            subtitle: 'Track artist',
            titleStyle: titleStyle,
            subtitleStyle: subtitleStyle,
          ),
        ),
      ),
    );

    expect(find.text('Track title'), findsOneWidget);
    expect(find.text('Track artist'), findsOneWidget);
    expect(find.byType(Hero), findsNWidgets(2));
  });

  testWidgets('can omit subtitle and hero wrappers for mini-player neighbors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerTrackIdentity(
            title: 'Track title',
            subtitle: '',
            titleStyle: titleStyle,
            subtitleStyle: subtitleStyle,
            useHero: false,
            scrollable: false,
          ),
        ),
      ),
    );

    expect(find.text('Track title'), findsOneWidget);
    expect(find.byType(Hero), findsNothing);
  });
}
