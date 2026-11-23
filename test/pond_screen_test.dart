import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_fish_tank/main.dart';
import 'package:my_fish_tank/src/aquarium.dart';
import 'package:my_fish_tank/src/pond.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets(
    'fills both orientations and keeps all pond actions in management',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      const portrait = Size(390, 844);
      const landscape = Size(844, 390);
      await tester.binding.setSurfaceSize(portrait);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const FishTankApp());
      await tester.pump();
      final aquarium = find.byType(Aquarium);
      expect(tester.getSize(aquarium), portrait);
      expect(find.text('Ngày 1 · 11 cá'), findsOneWidget);
      expect(find.text('Chợ cá'), findsNothing);

      await tester.binding.setSurfaceSize(landscape);
      await tester.pump();
      expect(tester.getSize(aquarium), landscape);
      await tester.tapAt(const Offset(400, 180));
      await tester.pump();

      await tester.tap(find.text('Quản lý'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Quản lý hồ'), findsOneWidget);

      await tester.tap(find.text('Chăm hồ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('Thay nước · 12 xu'), findsOneWidget);

      await tester.tap(find.text('Nâng cấp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Máy cho ăn'), findsOneWidget);

      await tester.tap(find.text('Chợ cá'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final keep = find.text('Giữ giống và bán phần còn lại');
      await tester.ensureVisible(keep);
      await tester.pump();
      await tester.tap(keep);
      await tester.pump();
      expect(find.text('0 cá sẵn sàng bán'), findsOneWidget);

      await tester.binding.setSurfaceSize(portrait);
      await tester.pump();
      final handbook = find.text('Sổ tay');
      await tester.ensureVisible(handbook);
      await tester.tap(handbook);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Paracheirodon innesi'), findsOneWidget);
      expect(find.text('Mua cặp giống · 140 xu'), findsOneWidget);

      final journal = find.text('Nhật ký');
      await tester.ensureVisible(journal);
      await tester.tap(journal);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Tua 30 ngày'));
      await tester.pump();
      expect(find.text('30 ngày trong hồ'), findsOneWidget);
      expect(find.textContaining('cá con chào đời'), findsOneWidget);

      await tester.tap(find.byTooltip('Đóng quản lý'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Quản lý hồ'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(const FishTankApp());
      await tester.pump();
      expect(find.textContaining('Ngày 31 ·'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('buys and displays a new species from the handbook', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FishTankApp());
    await tester.pump();
    await tester.tap(find.text('Quản lý'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Sổ tay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final handbook = find.byKey(const PageStorageKey('handbook'));
    final scrollable = find.descendant(
      of: handbook,
      matching: find.byType(Scrollable),
    );
    final buy = find.text('Mua cặp giống · 105 xu');
    await tester.scrollUntilVisible(buy, 220, scrollable: scrollable);
    await tester.pump();
    expect(buy.hitTestable(), findsOneWidget);
    await tester.tap(buy);
    await tester.pump();

    await tester.tap(find.byTooltip('Đóng quản lý'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final pond = tester.widget<Aquarium>(find.byType(Aquarium)).pond;
    expect(pond.count(Species.platy), 2);
    expect(find.text('Ngày 1 · 13 cá'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('updates the open handbook and caches the new catalog offline', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final response = Completer<String>();

    await tester.pumpWidget(FishTankApp(catalogLoader: () => response.future));
    await tester.pump();
    await tester.tap(find.text('Quản lý'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Sổ tay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Bảy màu'), findsOneWidget);

    response.complete('''
      {
        "schemaVersion": 1,
        "revision": 2,
        "species": [{
          "id": "bluePlaty",
          "style": "platy",
          "label": "Mún lam",
          "latin": "Xiphophorus maculatus",
          "habit": "Một dòng cá mún xanh.",
          "color": "#70aaff",
          "pairCost": 30
        }]
      }
    ''');
    await tester.pump();
    await tester.pump();
    expect(find.text('Bảy màu'), findsNothing);
    expect(find.text('Mún lam'), findsOneWidget);
    await tester.tap(find.text('Mua cặp giống · 30 xu').hitTestable());
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      FishTankApp(catalogLoader: () => Future.error(StateError('Offline'))),
    );
    await tester.pump();
    await tester.pump();
    final pond = tester.widget<Aquarium>(find.byType(Aquarium)).pond;
    final species = pond.catalog.listings.single;
    expect(species.name, 'bluePlaty');
    expect(fishColor(species, Tail.amber), const Color(0xff70aaff));
    expect(pond.count(species), 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps zone labels and fish glyphs on one line when narrow', (
    tester,
  ) async {
    final pond = Pond.starter()
      ..coins = 5000
      ..levels[Equipment.nursery] = 1
      ..levels[Equipment.bettaCups] = 1
      ..autoNursery = false;
    pond.buyPair(Species.neon);
    pond.advance(const Duration(seconds: 15 * Pond.daySeconds));
    expect(
      pond.litterLots
          .map(pond.litterById)
          .any((litter) => litter?.species == Species.neon),
      isTrue,
    );
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'pond-v1': jsonEncode({
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'pond': pond.toJson(),
          }),
        });
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FishTankApp());
    await tester.pump();
    await tester.pump();

    double lines(Finder text) {
      final style = tester.widget<Text>(text).style;
      final height = tester.getSize(text).height;
      return height / ((style?.fontSize ?? 14) * 1.6);
    }

    final cups = find.textContaining('Ngăn betta');
    expect(cups, findsOneWidget);
    expect(lines(cups), lessThan(1.5));

    await tester.tap(find.text('Quản lý'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final neon = find.text(Species.neon.glyph);
    expect(neon, findsWidgets);
    for (final element in neon.evaluate()) {
      expect(
        tester.getSize(find.byWidget(element.widget)).height,
        lessThan(30),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
