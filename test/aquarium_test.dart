import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_fish_tank/src/aquarium.dart';
import 'package:my_fish_tank/src/pond.dart';

void main() {
  testWidgets('draws the two tail trails only while effects are enabled', (
    tester,
  ) async {
    final pond = Pond.starter();
    pond.fish[0] = Fish.fromJson({
      ...pond.fish.first.toJson(),
      'isComet': true,
    });
    const size = Size(362, 308);

    Widget scene({required bool disableAnimations}) => MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox.fromSize(
            size: size,
            child: Aquarium(pond: pond, onFeed: () {}),
          ),
        ),
      ),
    );

    await tester.pumpWidget(scene(disableAnimations: false));
    for (var frame = 0; frame < 18; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final tank = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(Aquarium),
        matching: find.byType(CustomPaint),
      ),
    );
    void draw(Canvas canvas) => tank.painter!.paint(canvas, size);
    expect(
      draw,
      paints
        ..line()
        ..line(),
    );

    await tester.pumpWidget(scene(disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 16));
    expect(draw, paintsExactlyCountTimes(#drawLine, 0));
  });

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
            height: 308,
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
  });
}
