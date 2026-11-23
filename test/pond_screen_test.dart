import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_fish_tank/main.dart';
import 'package:my_fish_tank/src/aquarium.dart';
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
}
