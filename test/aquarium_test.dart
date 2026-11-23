import 'dart:convert';

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

  testWidgets('scoops a corpse when it is tapped instead of feeding', (
    tester,
  ) async {
    final source = Pond.starter()..levels[Equipment.snails] = 1;
    final json = source.toJson()
      ..['corpses'] = [
        Corpse(
          id: 77,
          species: Species.guppy,
          tail: Tail.amber,
          diedAt: 0,
        ).toJson(),
      ];
    final pond = Pond.fromJson(jsonDecode(jsonEncode(json)));
    final corpse = pond.corpses.single;
    Corpse? scooped;
    var fed = 0;
    const size = Size(362, 308);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: Aquarium(
              pond: pond,
              onFeed: () => fed++,
              onScoop: (value) => scooped = value,
            ),
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
    expect(
      (Canvas canvas) => tank.painter!.paint(canvas, size),
      paintsExactlyCountTimes(#save, pond.fish.length),
    );

    final spot = corpseSpot(corpse);
    await tester.tapAt(Offset(spot.dx * size.width, spot.dy * size.height));
    expect(scooped, same(corpse));
    expect(fed, 0);

    await tester.tapAt(const Offset(180, 80));
    expect(fed, 1);
  });
}
