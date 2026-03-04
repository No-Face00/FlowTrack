import 'package:flow_track/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FlowTrack app launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FlowTrack(seenOnboarding: false));
    expect(find.byType(FlowTrack), findsOneWidget);
  });
}




