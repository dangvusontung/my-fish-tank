import 'dart:convert';

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

  testWidgets('pinches to zoom and picks fish for a closer look', (
    tester,
  ) async {
    final pond = Pond.starter();
    final key = GlobalKey<AquariumState>();
    const size = Size(360, 640);
    final zooms = <double>[];
    final picked = <Fish>[];
    var fed = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: Aquarium(
              key: key,
              pond: pond,
              onFeed: () => fed++,
              onSelect: picked.add,
              onZoom: zooms.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final aquarium = key.currentState!;

    // A long press picks a fish even at full view.
    final first = pond.fish.first;
    await tester.longPressAt(aquarium.fishPosition(first.id, size)!);
    expect(picked.single.id, first.id);

    // Spread two fingers apart around the middle of the tank.
    final left = await tester.startGesture(const Offset(150, 320));
    final right = await tester.startGesture(const Offset(210, 320), pointer: 2);
    await tester.pump();
    for (var step = 1; step <= 6; step++) {
      await left.moveTo(Offset(150 - step * 20, 320));
      await right.moveTo(Offset(210 + step * 20, 320));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await left.up();
    await right.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(aquarium.zoom, greaterThan(2));
    expect(zooms.last, aquarium.zoom);

    // Zoomed in, a tap on a fish picks it instead of feeding.
    final visible = pond.fish.firstWhere((fish) {
      final at = aquarium.fishPosition(fish.id, size)!;
      return (Offset.zero & size).deflate(30).contains(at);
    });
    await tester.tapAt(aquarium.fishPosition(visible.id, size)!);
    expect(picked.last.id, visible.id);
    expect(fed, 0);

    aquarium.resetView();
    await tester.pump(const Duration(milliseconds: 16));
    expect(aquarium.zoom, 1);
    expect(zooms.last, 1);
  });
}
