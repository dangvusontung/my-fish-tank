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

  Future<void> _manage(PondController controller) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: _base,
      builder: (_) => FractionallySizedBox(
        heightFactor: .88,
        child: _ManagementSheet(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: controller,
              child: Aquarium(
                key: _aquarium,
                pond: controller.pond,
                onFeed: () => _feed(controller),
                onScoop: (corpse) {
                  controller.act((pond) => pond.scoop(corpse.id));
                  _toast('Đã vớt xác ${corpse.species.label.toLowerCase()}.');
                },
              ),
              builder: (context, aquarium) => Stack(
                fit: StackFit.expand,
                children: [
                  aquarium!,
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: SafeArea(
                        bottom: false,
                        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _TankHeader(controller),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: false,
                      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _manage(controller),
                              icon: Badge(
                                isLabelVisible: controller.report != null,
                                child: const Icon(Icons.tune, size: 19),
                              ),
                              label: const Text('Quản lý'),
                            ),
                            FilledButton.icon(
                              onPressed: controller.pond.fish.isEmpty
                                  ? null
                                  : () => _aquarium.currentState?.feed(),
                              icon: const Icon(
                                Icons.bubble_chart_outlined,
                                size: 19,
                              ),
                              label: const Text('Rải mồi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TankHeader extends StatelessWidget {
  const _TankHeader(this.controller);

  final PondController controller;

  @override
  Widget build(BuildContext context) {
    final pond = controller.pond;
    final water = pond.water.round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bể Neon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.10,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Ngày ${pond.day} · ${pond.fish.length} cá',
                style: const TextStyle(color: _subtle, fontSize: 13),
              ),
              if (pond.dead > 0)
                Text(
                  '${pond.dead} xác cá · chạm để vớt',
                  style: const TextStyle(color: _gold, fontSize: 12),
                ),
              if (controller.saveFailed)
                const Text(
                  'Chưa lưu được hồ',
                  style: TextStyle(color: _gold, fontSize: 12),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Align(
            alignment: Alignment.topRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 5,
              children: [
                _TankBadge('Nước $water%', water >= 65 ? _mint : _gold),
                _TankBadge('${pond.coins.floor()} xu', _gold),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TankBadge extends StatelessWidget {
  const _TankBadge(this.label, this.tint);

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xe50b2228),
      border: Border.all(color: tint.withValues(alpha: .34)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          color: tint,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _ManagementSheet extends StatefulWidget {
  const _ManagementSheet({required this.controller});

  final PondController controller;

  @override
  State<_ManagementSheet> createState() => _ManagementSheetState();
}

class _ManagementSheetState extends State<_ManagementSheet> {
  String? _saleMessage;
  Map<Equipment, (double, double)> _forecast = {};
  String? _forecastKey;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return DefaultTabController(
      length: 5,
      initialIndex: controller.report == null ? 0 : 4,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Quản lý hồ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Đóng quản lý',
                  ),
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Chợ cá'),
                Tab(text: 'Chăm hồ'),
                Tab(text: 'Nâng cấp'),
                Tab(text: 'Sổ tay'),
                Tab(text: 'Nhật ký'),
              ],
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final pond = controller.pond;
                  return TabBarView(
                    children: [
                      _page('market', [
                        _Market(
                          pond: pond,
                          saleMessage: _saleMessage,
                          onPreference: (tail) =>
                              controller.act((pond) => pond.preference = tail),
                          onPair: () =>
                              controller.act((pond) => pond.repairBreeders()),
                          onSell: _sell,
                        ),
                      ]),
                      _page('care', [
                        _Card(
                          child: Row(
                            children: [
                              _Stat('Cá lớn', '${pond.adultCount}'),
                              _Stat('Cá non', '${pond.juvenileCount}'),
                              _Stat('No bụng', '${pond.satiety.round()}%'),
                              _Stat(
                                'Xu/phút',
                                pond.income.toStringAsFixed(1),
                                color: _gold,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Care(pond: pond, controller: controller),
                      ]),
                      _page('upgrades', [
                        _Card(
                          child: Column(
                            children: [
                              for (final equipment in Equipment.values)
                                _Upgrade(
                                  equipment: equipment,
                                  pond: pond,
                                  forecast: _forecastFor(pond)[equipment],
                                  onPressed: () => controller.act(
                                    (pond) => pond.upgrade(equipment),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Dự báo chạy thử 30 phút tới với cùng luật của hồ.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _subtle, fontSize: 12),
                          ),
                        ),
                      ]),
                      _page('handbook', [
                        for (final species in Species.values)
                          _HandbookEntry(
                            species: species,
                            pond: pond,
                            onBuy: () => _buy(species),
                          ),
                      ]),
                      _page('journal', [
                        if (controller.report case final report?)
                          _ReportPanel(
                            title: controller.reportTitle,
                            report: report,
                            onDismiss: controller.dismissReport,
                          ),
                        OutlinedButton.icon(
                          onPressed: controller.testThirtyDays,
                          icon: const Icon(
                            Icons.fast_forward_outlined,
                            size: 20,
                          ),
                          label: const Text('Tua 30 ngày'),
                        ),
                        const Text(
                          '${Pond.daySeconds ~/ 60} phút ngoài đời ≈ 1 ngày trong hồ · Offline tối đa 8 giờ',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _subtle, fontSize: 12),
                        ),
                      ]),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Forecasts are simulated, so refresh them only when the pond changes
  /// enough to matter: new equipment, fish count, or a few in-game hours.
  Map<Equipment, (double, double)> _forecastFor(Pond pond) {
    final key = [
      for (final level in pond.levels.values) level,
      pond.fish.length,
      pond.dead,
      (pond.time / (Pond.daySeconds / 4)).floor(),
    ].join(',');
    if (key != _forecastKey) {
      _forecastKey = key;
      _forecast = {
        for (final equipment in Equipment.values)
          equipment: pond.forecast(equipment),
      };
    }
    return _forecast;
  }

  ListView _page(String name, List<Widget> children) => ListView(
    key: PageStorageKey(name),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
    children: children,
  );

  void _sell(bool keep) {
    final (count, coins) = widget.controller.act(
      (pond) => pond.sell(keepCandidate: keep),
    );
    if (count == 0) return;
    setState(() {
      _saleMessage = keep
          ? 'Đã giữ giống · +$coins xu'
          : 'Đã bán $count cá · +$coins xu';
    });
  }

  void _buy(Species species) {
    if (!widget.controller.act((pond) => pond.buyPair(species))) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã thả một cặp ${species.label.toLowerCase()}.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(padding: const EdgeInsets.all(13), child: child),
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

class _Glyph extends StatelessWidget {
  const _Glyph(this.species, {this.tail = Tail.amber, this.size = 21});

  final Species species;
  final Tail tail;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    species.glyph,
    style: TextStyle(
      fontSize: size,
      color: fishColor(species, tail),
      fontWeight: FontWeight.w800,
    ),
  );
}

class _Market extends StatelessWidget {
  const _Market({
    required this.pond,
    required this.onPreference,
    required this.onPair,
    required this.onSell,
    required this.saleMessage,
  });
  final Pond pond;
  final ValueChanged<Tail> onPreference;
  final VoidCallback onPair;
  final ValueChanged<bool> onSell;
  final String? saleMessage;

  @override
  Widget build(BuildContext context) {
    final candidate = pond.candidate;
    final sale = pond.forSale;
    final ready = sale.length;
    final comets = sale.where((fish) => fish.isComet).length;
    final bySpecies = <Species, int>{};
    for (final item in sale) {
      bySpecies[item.species] = (bySpecies[item.species] ?? 0) + 1;
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$ready cá sẵn sàng bán',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (comets > 0)
            Text(
              '$comets Legendary trong lô',
              style: const TextStyle(color: Color(0xffe4ccfb)),
            ),
          if (bySpecies.length > 1)
            Text(
              [
                for (final entry in bySpecies.entries)
                  '${entry.value} ${entry.key.label.toLowerCase()}',
              ].join(' · '),
              style: const TextStyle(color: _subtle, fontSize: 12),
            ),
          if (pond.count(Species.guppy) > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Mục tiêu giữ giống bảy màu',
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
                  if (candidate.isComet)
                    const Text(
                      '⋏((•›',
                      style: TextStyle(
                        fontSize: 21,
                        color: Color(0xffe4b8ff),
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    _Glyph(candidate.species, tail: candidate.tail),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      candidate.isComet
                          ? 'Legendary · Đuôi sao chổi\n'
                                '${candidate.sex == Sex.male ? 'Trống' : 'Mái'} · ${candidate.age(pond.time).floor()} ngày · ${candidate.price} xu'
                          : 'Đề cử · ${candidate.sex == Sex.male ? 'Trống' : 'Mái'} ${candidate.tail.label}\n'
                                '${candidate.age(pond.time).floor()} ngày tuổi',
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
          if (saleMessage case final message?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Semantics(
                liveRegion: true,
                child: Text(message, style: const TextStyle(color: _mint)),
              ),
            ),
          if (pond.canRepairBreeders)
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
    final litters = [
      for (final species in Species.values)
        if (pond.daysToLitter(species) case final days?)
          '${species.label} $days ngày',
    ];
    final eggs = pond.eggCount;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            [
              '${pond.sheltered} chỗ trú · ${feeder ? 'Kho ${pond.stock}/${pond.capacity} phần mồi' : 'Máy chưa lắp'}',
              litters.isEmpty
                  ? 'Ghép một cặp cá giống để có lứa mới.'
                  : 'Lứa sau dự kiến: ${litters.join(' · ')}.',
              if (eggs > 0) '$eggs trứng đang ấp.',
              if (pond.snails > 0)
                '${pond.snails} ốc ramshorn ${pond.dead > 0 ? 'đang rỉa xác' : 'đang dạo kính'}.',
              if (pond.rivalBettas > 0)
                '${pond.rivalBettas + 1} betta trống đang tranh lãnh thổ.',
            ].join('\n'),
            style: const TextStyle(color: _subtle, fontSize: 13, height: 1.45),
          ),
          if (feeder) ...[
            const SizedBox(height: 9),
            const Text(
              'Mức rải của máy',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SegmentedButton<FeederMode>(
              segments: [
                for (final mode in FeederMode.values)
                  ButtonSegment(value: mode, label: Text(mode.label)),
              ],
              selected: {pond.feederMode},
              showSelectedIcon: false,
              onSelectionChanged: (modes) =>
                  controller.act((pond) => pond.feederMode = modes.single),
            ),
            const SizedBox(height: 3),
            Text(
              'Máy rải khi cá no dưới ${pond.feederMode.threshold.round()}%. '
              'Rải dày cá no hơn nhưng mồi dư làm bẩn nước.',
              style: const TextStyle(color: _subtle, fontSize: 12),
            ),
          ],
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
              if (feeder)
                OutlinedButton(
                  onPressed:
                      pond.stock >= pond.capacity ||
                          pond.coins < pond.refillCost
                      ? null
                      : () => controller.act((pond) => pond.refill()),
                  child: Text(
                    pond.stock >= pond.capacity
                        ? 'Kho mồi đầy'
                        : 'Nạp đầy kho · ${pond.refillCost} xu',
                  ),
                ),
              if (pond.dead > 0)
                OutlinedButton(
                  onPressed: () => controller.act((pond) => pond.scoopAll()),
                  child: Text('Vớt tất cả ${pond.dead} xác'),
                ),
            ],
          ),
          if (pond.dead > 0)
            const Text(
              'Xác cá làm nước xấu đi. Chạm từng xác trong hồ để vớt.',
              style: TextStyle(color: _gold, fontSize: 12),
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
    required this.forecast,
    required this.onPressed,
  });

  final Equipment equipment;
  final Pond pond;
  final (double, double)? forecast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final level = pond.levels[equipment]!;
    final cost = pond.upgradeCost(equipment);
    final needsFeeder =
        equipment == Equipment.storage && pond.levels[Equipment.feeder] == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                  needsFeeder ? 'Cần lắp máy cho ăn trước.' : equipment.detail,
                  style: const TextStyle(color: _subtle, fontSize: 12),
                ),
                if (forecast case (final now, final next) when !needsFeeder)
                  Text(
                    _describe(now, next, cost),
                    style: TextStyle(
                      color: next - now > .05 ? _gold : _subtle,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: pond.canUpgrade(equipment) ? onPressed : null,
            child: Text('${level == 0 ? 'Mua' : 'Nâng'} · $cost xu'),
          ),
        ],
      ),
    );
  }

  static String _describe(double now, double next, int cost) {
    final change = next - now;
    final rates =
        '${now.toStringAsFixed(1)} → ${next.toStringAsFixed(1)} xu/phút';
    if (change.abs() <= .05) return '$rates · không đổi trong 30 phút tới';
    if (change < 0) return '$rates · giảm ${(-change).toStringAsFixed(1)}';
    final payback = (cost / change).ceil();
    return '$rates · +${change.toStringAsFixed(1)} · hoàn vốn ~$payback phút';
  }
}

class _HandbookEntry extends StatelessWidget {
  const _HandbookEntry({
    required this.species,
    required this.pond,
    required this.onBuy,
  });

  final Species species;
  final Pond pond;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final owned = pond.count(species);
    final adults = pond.adults(species);
    final (clutchLow, clutchHigh) = species.clutch;
    final brood = species.brood == Brood.live
        ? 'Đẻ con · $clutchLow–${clutchHigh - 1} con/lứa'
        : 'Đẻ trứng · $clutchLow–${clutchHigh - 1} trứng/đợt · ấp '
              '${species.incubation} ngày · nở ~${(species.hatchRate * 100).round()}%';
    final status = [
      owned == 0 ? 'Chưa có trong hồ' : '$owned con · $adults trưởng thành',
      if (species == Species.neon && owned > 0)
        adults >= Species.neonSchool
            ? 'Đủ đàn, kiếm xu nhiều hơn'
            : 'Đàn $adults/${Species.neonSchool}, cá còn stress',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Glyph(species, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        species.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        species.latin,
                        style: const TextStyle(
                          color: _subtle,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(species.habit, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              '$brood\nTrưởng thành ~${species.adultDays.$1} ngày · '
              'giá bán ~${species.basePrice + 60 ~/ species.vividDivisor} xu · '
              '${species.adultIncome.toStringAsFixed(1)} xu/phút mỗi con lớn',
              style: const TextStyle(color: _subtle, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(status, style: const TextStyle(color: _mint, fontSize: 12)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: pond.coins < species.pairCost ? null : onBuy,
                child: Text('Mua cặp giống · ${species.pairCost} xu'),
              ),
            ),
          ],
        ),
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
      if (report.cometsBorn > 0) '${report.cometsBorn} Đuôi sao chổi chào đời',
      if (report.laid > 0) '${report.laid} trứng được đẻ',
      if (report.hatched > 0) '${report.hatched} cá bột nở',
      if (report.clutchesLost > 0)
        '${report.clutchesLost} ổ trứng bị cặp thần tiên non ăn',
      if (report.grown > 0) '${report.grown} cá trưởng thành',
      if (report.eaten > 0) '${report.eaten} cá con bị ăn',
      if (report.died > 0) '${report.died} cá chết',
      if (report.fryLost > 0) '${report.fryLost} cá bột hao hụt',
      if (report.fought > 0) '${report.fought} betta trống chết vì đánh nhau',
      if (report.scavenged > 0) 'Ốc rỉa hết ${report.scavenged} xác',
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
