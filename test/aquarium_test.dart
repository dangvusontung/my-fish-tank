import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_fish_tank/src/aquarium.dart';
import 'package:my_fish_tank/src/pond.dart';

void main() {
  testWidgets('paints every fish in a crowded aquarium', (tester) async {
    final pond = Pond.starter();
    pond.advance(const Duration(seconds: Pond.daySeconds * 30));
    expect(pond.fish.length, greaterThan(24));
    expect(pond.juvenileCount, greaterThan(4));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 362,
            child: Aquarium(pond: pond, onFeed: () {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    final tank = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(Aquarium),
        matching: find.byType(CustomPaint),
      ),
    );
    // Each sprite saves the canvas before applying its own transform.
    expect(
      (Canvas canvas) => tank.painter!.paint(canvas, const Size(362, 308)),
      paintsExactlyCountTimes(#save, pond.fish.length),
    );
    expect(find.text('Hồ bảy màu · ${pond.fish.length} cá'), findsOneWidget);
  });
}
