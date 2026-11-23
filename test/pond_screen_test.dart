import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_fish_tank/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('plays the first mobile turn and restores a saved pond', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FishTankApp());
    await tester.pump();
    expect(find.text('Bể Neon'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);

    await tester.tap(find.text('Rải mồi'));
    await tester.pump();
    expect(find.text('92%'), findsOneWidget);

    final keep = find.text('Giữ giống và bán phần còn lại');
    await tester.scrollUntilVisible(keep, 100);
    await tester.pump();
    await tester.tap(keep.hitTestable());
    await tester.pump();
    await tester.scrollUntilVisible(find.text('0 cá sẵn sàng bán'), -100);
    expect(find.text('Chưa có cá để bán'), findsOneWidget);

    final skip = find.text('Tua 30 ngày');
    await tester.scrollUntilVisible(skip, -130);
    await tester.tap(skip);
    await tester.pump();
    await tester.scrollUntilVisible(find.text('30 ngày trong hồ'), -120);
    expect(find.textContaining('cá con chào đời'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const FishTankApp());
    await tester.pump();
    expect(find.text('Ngày 31 trong hồ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
