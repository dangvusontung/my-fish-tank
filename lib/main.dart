import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'src/aquarium.dart';
import 'src/pond.dart';
import 'src/pond_controller.dart';

const _base = Color(0xff091419);
const _panel = Color(0xff112025);
const _border = Color(0xff294044);
const _mint = Color(0xff93f9d0);
const _gold = Color(0xffffc77e);
const _subtle = Color(0xffa9beba);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FishTankApp());
}

class FishTankApp extends StatelessWidget {
  const FishTankApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: _mint,
      brightness: Brightness.dark,
      surface: _base,
    );
    return MaterialApp(
      title: 'Bể Neon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: colors, scaffoldBackgroundColor: _base),
      home: const PondScreen(),
    );
  }
}

class PondScreen extends StatefulWidget {
  const PondScreen({super.key});

  @override
  State<PondScreen> createState() => _PondScreenState();
}

class _PondScreenState extends State<PondScreen> with WidgetsBindingObserver {
  final _aquarium = GlobalKey<AquariumState>();
  PondController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    final controller = await PondController.load();
    if (!mounted) {
      controller.dispose();
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      controller.pause();
    }
    setState(() => _controller = controller);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller?.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _feed(PondController controller) {
    if (controller.pond.fish.isEmpty) return;
    if (controller.act((pond) => pond.feed())) {
      _toast('Mồi dư làm nước xấu đi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      body: SafeArea(
        child: controller == null
            ? const Center(child: CircularProgressIndicator())
            : ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final pond = controller.pond;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 660),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                        children: [
                          _Header(pond),
                          if (controller.saveFailed)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Chưa lưu được hồ. Game sẽ thử lại.',
                                style: TextStyle(color: _gold),
                              ),
                            ),
                          if (controller.report case final report?)
                            _ReportPanel(
                              title: controller.reportTitle,
                              report: report,
                              onDismiss: controller.dismissReport,
                            ),
                          _Card(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                Aquarium(
                                  key: _aquarium,
                                  pond: pond,
                                  onFeed: () => _feed(controller),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    13,
                                    10,
                                    11,
                                  ),
                                  child: Row(
                                    children: [
                                      _Stat('Cá lớn', '${pond.adultCount}'),
                                      _Stat('Cá non', '${pond.juvenileCount}'),
                                      _Stat(
                                        'No bụng',
                                        '${pond.satiety.round()}%',
                                      ),
                                      _Stat(
                                        'Xu/phút',
                                        pond.income.toStringAsFixed(1),
                                        color: _gold,
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, color: _border),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          icon: const Icon(
                                            Icons.bubble_chart_outlined,
                                            size: 19,
                                          ),
                                          onPressed: pond.fish.isEmpty
                                              ? null
                                              : () => _aquarium.currentState
                                                    ?.feed(),
                                          label: const Text('Rải mồi'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: controller.testThirtyDays,
                                          child: const Text('Tua 30 ngày'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Market(
                            pond: pond,
                            onPreference: (tail) => controller.act(
                              (pond) => pond.preference = tail,
                            ),
                            onPair: () =>
                                controller.act((pond) => pond.repairBreeders()),
                            onSell: (keep) {
                              final (count, coins) = controller.act(
                                (pond) => pond.sell(keepCandidate: keep),
                              );
                              if (count > 0) {
                                _toast(
                                  keep
                                      ? 'Đã giữ giống · +$coins xu'
                                      : 'Đã bán $count cá · +$coins xu',
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _Care(pond: pond, controller: controller),
                          const SizedBox(height: 16),
                          const Text(
                            'Nâng cấp',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _Card(
                            child: Column(
                              children: [
                                for (final equipment in Equipment.values)
                                  _Upgrade(
                                    equipment: equipment,
                                    pond: pond,
                                    onPressed: () => controller.act(
                                      (pond) => pond.upgrade(equipment),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '5 phút ngoài đời ≈ 1 ngày trong hồ · Offline tối đa 8 giờ',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: _subtle),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(13)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.pond);
  final Pond pond;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xff183c33),
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: const Text(
            '»',
            style: TextStyle(
              color: _mint,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bể Neon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                'Ngày ${pond.day} trong hồ',
                style: const TextStyle(color: _subtle, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xff30241a),
            border: Border.all(color: const Color(0xff56402c)),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              const Icon(Icons.diamond_outlined, color: _gold, size: 16),
              const SizedBox(width: 5),
              Text(
                '${pond.coins.floor()} xu',
                style: const TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: _subtle, fontSize: 12)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Market extends StatelessWidget {
  const _Market({
    required this.pond,
    required this.onPreference,
    required this.onPair,
    required this.onSell,
  });
  final Pond pond;
  final ValueChanged<Tail> onPreference;
  final VoidCallback onPair;
  final ValueChanged<bool> onSell;

  @override
  Widget build(BuildContext context) {
    final candidate = pond.candidate;
    final ready = pond.forSale.length;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Chợ cá',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$ready cá sẵn sàng bán',
                style: const TextStyle(color: _subtle),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Mục tiêu giữ giống',
                  style: TextStyle(color: _subtle),
                ),
              ),
              DropdownButton<Tail>(
                value: pond.preference,
                underline: const SizedBox.shrink(),
                onChanged: (tail) {
                  if (tail != null) onPreference(tail);
                },
                items: [
                  for (final tail in Tail.values)
                    DropdownMenuItem(value: tail, child: Text(tail.label)),
                ],
              ),
            ],
          ),
          if (candidate != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff252538),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xff524269)),
              ),
              child: Row(
                children: [
                  Text(
                    '⟫((•›',
                    style: TextStyle(
                      fontSize: 21,
                      color: tailColor(candidate.tail),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Đề cử · ${candidate.sex == Sex.male ? 'Trống' : 'Mái'} ${candidate.tail.label}\n${candidate.age(pond.time).floor()} ngày tuổi',
                      style: const TextStyle(
                        color: Color(0xffe4ccfb),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            FilledButton.tonal(
              onPressed: () => onSell(true),
              child: const Text('Giữ giống và bán phần còn lại'),
            ),
          ],
          OutlinedButton(
            onPressed: ready == 0 ? null : () => onSell(false),
            child: Text(
              ready == 0
                  ? 'Chưa có cá để bán'
                  : 'Bán $ready cá · +${pond.saleValue} xu',
            ),
          ),
          if (pond.breeders.length < 2)
            TextButton(
              onPressed: onPair,
              child: const Text('Thả thêm cá giống'),
            ),
        ],
      ),
    );
  }
}

class _Care extends StatelessWidget {
  const _Care({required this.pond, required this.controller});

  final Pond pond;
  final PondController controller;

  @override
  Widget build(BuildContext context) {
    final feeder = pond.levels[Equipment.feeder]! > 0;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chăm hồ',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            '${pond.sheltered} chỗ trú · ${feeder ? '${pond.stock} phần mồi' : 'Máy chưa lắp'}'
            '\n${pond.breeders.length == 2 ? 'Lứa sau dự kiến sau ${pond.daysToLitter} ngày.' : 'Ghép một cặp cá giống để có lứa mới.'}',
            style: const TextStyle(color: _subtle, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            children: [
              OutlinedButton(
                onPressed: pond.water >= 99 || pond.coins < Pond.waterChangeCost
                    ? null
                    : () => controller.act((pond) => pond.changeWater()),
                child: const Text('Thay nước · 12 xu'),
              ),
              OutlinedButton(
                onPressed: !feeder || pond.coins < Pond.refillCost
                    ? null
                    : () => controller.act((pond) => pond.refill()),
                child: const Text('Nạp mồi · 20 xu'),
              ),
              if (pond.dead > 0)
                OutlinedButton(
                  onPressed: () => controller.act((pond) => pond.dead = 0),
                  child: Text('Vớt ${pond.dead} cá chết'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Upgrade extends StatelessWidget {
  const _Upgrade({
    required this.equipment,
    required this.pond,
    required this.onPressed,
  });

  final Equipment equipment;
  final Pond pond;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final level = pond.levels[equipment]!;
    final cost = pond.upgradeCost(equipment);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${equipment.label}${level > 0 ? ' · $level' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  equipment.detail,
                  style: const TextStyle(color: _subtle, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: pond.coins < cost ? null : onPressed,
            child: Text('${level == 0 ? 'Mua' : 'Nâng'} · $cost xu'),
          ),
        ],
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({
    required this.title,
    required this.report,
    required this.onDismiss,
  });

  final String title;
  final PondReport report;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final events = <String>[
      if (report.coins > 0) '+${report.coins} xu',
      if (report.born > 0) '${report.born} cá con chào đời',
      if (report.grown > 0) '${report.grown} cá trưởng thành',
      if (report.eaten > 0) '${report.eaten} cá con bị ăn',
      if (report.died > 0) '${report.died} cá chết',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _mint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    events.isEmpty
                        ? 'Hồ không có thay đổi đáng kể.'
                        : events.join(' · '),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              tooltip: 'Đóng nhật ký',
            ),
          ],
        ),
      ),
    );
  }
}
