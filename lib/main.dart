import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import 'src/aquarium.dart';
import 'src/catalog_download.dart';
import 'src/pond.dart';
import 'src/pond_controller.dart';

const _base = Color(0xff091419);
const _panel = Color(0xff112025);
const _border = Color(0xff294044);
const _mint = Color(0xff93f9d0);
const _gold = Color(0xffffc77e);
const _subtle = Color(0xffa9beba);

/// Coins with Vietnamese thousands separators: 10445 → "10.445".
String _xu(num value) {
  final digits = value.floor().abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return value < 0 ? '-$grouped' : grouped;
}

/// Light text with a soft shadow, readable over bright water.
const _onWater = [Shadow(color: Color(0xcc04111c), blurRadius: 6)];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FishTankApp(catalogLoader: fetchFishCatalog));
}

class FishTankApp extends StatelessWidget {
  const FishTankApp({super.key, this.catalogLoader});

  final CatalogLoader? catalogLoader;

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
      home: PondScreen(catalogLoader: catalogLoader),
    );
  }
}

class PondScreen extends StatefulWidget {
  const PondScreen({super.key, this.catalogLoader});

  final CatalogLoader? catalogLoader;

  @override
  State<PondScreen> createState() => _PondScreenState();
}

class _PondScreenState extends State<PondScreen> with WidgetsBindingObserver {
  final _aquarium = GlobalKey<AquariumState>();
  PondController? _controller;
  int? _selectedFish;
  bool _zoomed = false;
  Zone _zone = Zone.main;

  /// Heights of the header and the bottom buttons, so the tank can keep its
  /// surface and floor clear of them.
  double _headerHeight = 0;
  double _buttonsHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    final controller = await PondController.load(
      loadCatalog: widget.catalogLoader,
    );
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
    final zone = _zone == Zone.nursery ? Zone.nursery : Zone.main;
    if (controller.act((pond) => pond.feed(zone))) {
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

  /// Zones worth switching between: the main tank, plus any built or
  /// still holding fish.
  List<Zone> _zones(Pond pond) => [
    for (final zone in Zone.values)
      if (zone == Zone.main ||
          pond.inZone(zone) > 0 ||
          (zone == Zone.nursery ? pond.hasNursery : pond.cups > 0))
        zone,
  ];

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
                selectedId: _selectedFish,
                zone: _zone,
                overlay: EdgeInsets.only(
                  top: _headerHeight,
                  bottom:
                      _buttonsHeight +
                      14 +
                      MediaQuery.paddingOf(context).bottom,
                ),
                onSelect: (fish) => setState(() => _selectedFish = fish.id),
                onZoom: (zoom) {
                  if ((zoom > 1.01) != _zoomed) {
                    setState(() => _zoomed = zoom > 1.01);
                  }
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
                    child: _MeasureSize(
                      onChange: (size) {
                        if (!mounted) return;
                        setState(() => _headerHeight = size.height);
                      },
                      child: SafeArea(
                        bottom: false,
                        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IgnorePointer(
                              child: _TankHeader(controller, _zone),
                            ),
                            if (_zones(controller.pond) case final zones
                                when zones.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: SegmentedButton<Zone>(
                                  showSelectedIcon: false,
                                  style: SegmentedButton.styleFrom(
                                    backgroundColor: const Color(0xe50b2228),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  segments: [
                                    for (final zone in zones)
                                      ButtonSegment(
                                        value: zone,
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '${zone.label} ${controller.pond.inZone(zone)}',
                                            maxLines: 1,
                                            softWrap: false,
                                          ),
                                        ),
                                      ),
                                  ],
                                  selected: {_zone},
                                  onSelectionChanged: (value) => setState(() {
                                    _zone = value.single;
                                    _selectedFish = null;
                                  }),
                                ),
                              ),
                          ],
                        ),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (controller.pond.fish
                                  .where((fish) => fish.id == _selectedFish)
                                  .firstOrNull
                              case final fish?)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FishCard(
                                fish: fish,
                                pond: controller.pond,
                                onClose: () =>
                                    setState(() => _selectedFish = null),
                                onMove: (zone) {
                                  if (controller.act(
                                    (pond) => pond.moveFish(fish.id, zone),
                                  )) {
                                    _toast(
                                      'Đã chuyển sang ${zone.label.toLowerCase()}.',
                                    );
                                  }
                                },
                              ),
                            )
                          else if (_zoomed)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: _TankBadge(
                                'Chạm vào cá để xem chi tiết',
                                _mint,
                              ),
                            ),
                          _MeasureSize(
                            onChange: (size) {
                              if (!mounted) return;
                              setState(() => _buttonsHeight = size.height);
                            },
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
                                if (_zoomed)
                                  IconButton.filledTonal(
                                    onPressed: () {
                                      _aquarium.currentState?.resetView();
                                      setState(() => _selectedFish = null);
                                    },
                                    icon: const Icon(Icons.zoom_out_map),
                                    tooltip: 'Thu nhỏ',
                                  ),
                                FilledButton.icon(
                                  onPressed: controller.pond.inZone(_zone) == 0
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
                        ],
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
  const _TankHeader(this.controller, this.zone);

  final PondController controller;
  final Zone zone;

  @override
  Widget build(BuildContext context) {
    final pond = controller.pond;
    final water = pond.waterOf(zone).round();
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
                  shadows: _onWater,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                zone == Zone.main
                    ? 'Ngày ${pond.day} · ${pond.fish.length} cá'
                    : '${zone.label} · ${pond.inZone(zone)}'
                          '${zone == Zone.nursery ? '/${pond.nurseryCapacity}' : '/${pond.cups}'} cá',
                style: const TextStyle(
                  color: Color(0xffe3f1f4),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: _onWater,
                ),
              ),
              if (pond.dead > 0)
                Text(
                  '${pond.dead} xác cá · chạm để vớt',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 12,
                    shadows: _onWater,
                  ),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TankBadge('Nước $water%', water >= 65 ? _mint : _gold),
            const SizedBox(width: 6),
            _TankBadge('${_xu(pond.coins)} xu', _gold),
          ],
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
              labelPadding: EdgeInsets.symmetric(horizontal: 2),
              labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                        const SizedBox(height: 10),
                        _LitterLots(
                          pond: pond,
                          onSell: (litter) {
                            final (count, coins) = controller.act(
                              (pond) => pond.sellLitter(litter),
                            );
                            if (count == 0) return;
                            setState(
                              () => _saleMessage =
                                  'Đã bán $count cá · +$coins xu',
                            );
                          },
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
                        if (pond.hasNursery || pond.cups > 0) ...[
                          const SizedBox(height: 10),
                          _Zones(pond: pond, controller: controller),
                        ],
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
                        if (pond.catalog.listings.isEmpty)
                          const _Card(
                            child: Text('Chưa có cặp giống đang bán.'),
                          ),
                        for (final species in pond.catalog.listings)
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
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            '${Pond.daySeconds ~/ 60} phút ngoài đời ≈ 1 ngày trong hồ · Offline tối đa 8 giờ',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _subtle, fontSize: 12),
                          ),
                        ),
                        if (pond.litters.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _BreedingHistory(pond: pond),
                        ],
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
      pond.catalog.revision,
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
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      species.glyph,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: size,
        color: fishColor(species, tail),
        fontWeight: FontWeight.w800,
      ),
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
                  : 'Bán $ready cá · +${_xu(pond.saleValue)} xu',
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
      for (final species in pond.scheduledSpecies)
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
            runSpacing: 6,
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
                        : 'Nạp đầy kho · ${_xu(pond.refillCost)} xu',
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
    final maxed = pond.isMaxed(equipment);
    final needsFeeder =
        equipment == Equipment.storage && pond.levels[Equipment.feeder] == 0;
    final effect = maxed
        ? 'Tối đa: ${pond.effectAt(equipment, level)}'
        : _change(
            pond.effectAt(equipment, level),
            pond.effectAt(equipment, level + 1),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${equipment.label}${level > 0 ? ' · cấp $level' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton(
                onPressed: pond.canUpgrade(equipment) ? onPressed : null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  maxed
                      ? 'Tối đa'
                      : '${level == 0 ? 'Mua' : 'Nâng'} · ${_xu(cost)} xu',
                ),
              ),
            ],
          ),
          Text(effect, style: const TextStyle(color: _mint, fontSize: 13)),
          Text(
            needsFeeder ? 'Cần lắp máy cho ăn trước.' : equipment.detail,
            style: const TextStyle(color: _subtle, fontSize: 12),
          ),
          if (forecast case (final now, final next) when !needsFeeder && !maxed)
            Text(
              _describe(now, next, cost, pond.flatReason(equipment)),
              style: TextStyle(
                color: next - now > .05 ? _gold : _subtle,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  /// "106 phần mồi → 126 phần mồi" reads as "106 → 126 phần mồi".
  static String _change(String now, String next) {
    final nowParts = now.split(' ');
    final nextParts = next.split(' ');
    final unit = nowParts.skip(1).join(' ');
    if (nowParts.length > 1 &&
        unit == nextParts.skip(1).join(' ') &&
        num.tryParse(nowParts.first.replaceAll(',', '.')) != null) {
      return '${nowParts.first} → ${nextParts.first} $unit';
    }
    return '$now → $next';
  }

  static String _describe(double now, double next, int cost, String? reason) {
    final change = next - now;
    final rates =
        'Xu/phút ${now.toStringAsFixed(1)} → ${next.toStringAsFixed(1)}';
    if (change.abs() <= .05) {
      return '$rates · ${reason ?? 'không đổi trong 30 phút tới'}';
    }
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
    final school = species.schoolSize;
    final schoolAdults = school > 0 ? pond.adults(species, zone: Zone.main) : 0;
    final (clutchLow, clutchHigh) = species.clutch;
    final brood = species.brood == Brood.live
        ? 'Đẻ con · $clutchLow–${clutchHigh - 1} con/lứa'
        : 'Đẻ trứng · $clutchLow–${clutchHigh - 1} trứng/đợt · ấp '
              '${species.incubation} ngày · nở ~${(species.hatchRate * 100).round()}%';
    final status = [
      owned == 0 ? 'Chưa có trong hồ' : '$owned con · $adults trưởng thành',
      if (school > 0 && owned > 0)
        schoolAdults >= school
            ? 'Đủ đàn, kiếm xu nhiều hơn'
            : 'Đàn $schoolAdults/$school ở hồ chính, cá còn stress',
      if (species.spawnWater > 50 &&
          owned > 0 &&
          pond.water < species.spawnWater)
        'Nước dưới ${species.spawnWater}%, chưa đẻ',
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
                child: Text('Mua cặp giống · ${_xu(species.pairCost)} xu'),
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
      if (report.graduated > 0) '${report.graduated} cá từ khu ươm về bể chính',
      if (report.housed > 0)
        '${report.housed} betta trống được chuyển sang ngăn riêng',
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

class _FishCard extends StatelessWidget {
  const _FishCard({
    required this.fish,
    required this.pond,
    required this.onClose,
    required this.onMove,
  });

  final Fish fish;
  final Pond pond;
  final VoidCallback onClose;
  final ValueChanged<Zone> onMove;

  @override
  Widget build(BuildContext context) {
    final species = fish.species;
    final age = fish.age(pond.time);
    final adult = fish.isAdult(pond.time);
    final breeder = pond.breeders.contains(fish.id);
    final stage = adult
        ? 'Trưởng thành · ${age.floor()} ngày tuổi'
        : age < Pond.fryDays
        ? 'Cá bột · ${age.floor()} ngày tuổi'
        : 'Cá non · ${age.floor()} ngày · lớn sau ${(fish.adultDay - age).ceil()} ngày';
    final lifeLeft = math.max(0, fish.lifeDays - age).floor();
    final price = breeder
        ? 'Cá giống · giữ lại cho lứa sau'
        : adult
        ? 'Bán được ${_xu(fish.price)} xu'
        : pond.priceOf(fish) > 0
        ? 'Bán ngay ${_xu(pond.priceOf(fish))} xu · khi lớn ${_xu(fish.price)} xu'
        : 'Giá khi lớn ~${_xu(fish.price)} xu';
    final litter = pond.litterById(fish.litter);
    final moves = pond.movesFor(fish);
    final income = adult ? species.adultIncome : species.youngIncome;
    final colored = species.usesTailColor;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xf0112025),
          border: Border.all(
            color: fish.isComet ? const Color(0xff9d6fd8) : _border,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (fish.isComet)
                    const Text(
                      '⋏((•›',
                      style: TextStyle(
                        fontSize: 22,
                        color: Color(0xffe4b8ff),
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    _Glyph(species, tail: fish.tail, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${species.label} ${fish.sex == Sex.male ? 'trống' : 'mái'}'
                          '${colored ? ' · ${fish.tail.label}' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          [
                            if (fish.isComet) 'Legendary · Đuôi sao chổi',
                            if (breeder) 'Cá giống',
                            species.latin,
                          ].join(' · '),
                          style: TextStyle(
                            color: fish.isComet
                                ? const Color(0xffe4ccfb)
                                : _subtle,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    tooltip: 'Đóng thông tin cá',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Meter('Lớn', fish.growth(pond.time), stage, _mint),
                    const SizedBox(height: 6),
                    _Meter(
                      'Màu',
                      fish.vividness / 100,
                      'Độ đậm màu ${fish.vividness}/100',
                      fish.isComet
                          ? const Color(0xffe4b8ff)
                          : fishColor(species, fish.tail),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$price\n'
                      'Kiếm ${income.toStringAsFixed(1)} xu/phút khi no và nước sạch\n'
                      'Còn sống khoảng $lifeLeft ngày · ${fish.zone.label}'
                      '${litter == null ? '' : ' · lứa #${litter.id}'}',
                      style: const TextStyle(
                        color: _subtle,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (moves.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final zone in moves)
                            TextButton.icon(
                              onPressed: () => onMove(zone),
                              icon: const Icon(Icons.swap_horiz, size: 18),
                              label: Text('Sang ${zone.label.toLowerCase()}'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter(this.label, this.value, this.detail, this.color);

  final String label;
  final double value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 36,
        child: Text(
          label,
          style: const TextStyle(color: _subtle, fontSize: 12),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0, 1).toDouble(),
                minHeight: 5,
                color: color,
                backgroundColor: const Color(0xff294044),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LitterLots extends StatelessWidget {
  const _LitterLots({required this.pond, required this.onSell});

  final Pond pond;
  final ValueChanged<int?> onSell;

  @override
  Widget build(BuildContext context) {
    final lots = pond.litterLots;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bán theo lứa',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Text(
            'Cá non bán được giá thấp hơn, tăng dần khi lớn. Cá bột và cá giống giữ lại.',
            style: TextStyle(color: _subtle, fontSize: 12),
          ),
          if (lots.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Chưa có lứa nào bán được.'),
            ),
          for (final id in lots) _lot(id),
        ],
      ),
    );
  }

  Widget _lot(int? id) {
    final sale = pond.sellableIn(id);
    final adults = sale.where((fish) => fish.isAdult(pond.time)).length;
    final comets = sale.where((fish) => fish.isComet).length;
    final value = sale.fold(0, (sum, fish) => sum + pond.priceOf(fish));
    final litter = pond.litterById(id);
    final species = litter?.species ?? sale.first.species;
    final title = litter == null
        ? (id == null ? 'Cá không rõ lứa' : 'Lứa cũ #$id')
        : 'Lứa #${litter.id} · ${species.label} · ngày ${litter.bornAt ~/ Pond.daySeconds + 1}';
    final bySpecies = <Species, int>{};
    for (final fish in sale) {
      bySpecies[fish.species] = (bySpecies[fish.species] ?? 0) + 1;
    }
    final parts = [
      if (litter == null && bySpecies.length > 1)
        for (final entry in bySpecies.entries)
          '${entry.value} ${entry.key.label.toLowerCase()}',
      if (adults > 0) '$adults lớn',
      if (sale.length > adults) '${sale.length - adults} non',
      if (comets > 0) '$comets Legendary',
      if (litter != null) ?_parents(litter),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: litter == null
                    ? const Icon(
                        Icons.inventory_2_outlined,
                        color: _subtle,
                        size: 20,
                      )
                    : _Glyph(species, tail: sale.first.tail, size: 15),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13)),
                    Text(
                      parts.join(' · '),
                      style: const TextStyle(color: _subtle, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => onSell(id),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text('Bán ${sale.length} cá · +${_xu(value)} xu'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "đuôi cam × đuôi tím" for species whose tail colour matters.
String? _parents(Litter litter) {
  if (litter.tails.length != 2) return null;
  if (!litter.species.usesTailColor) {
    return null;
  }
  return litter.tails.map((tail) => tail.label).join(' × ');
}

class _BreedingHistory extends StatelessWidget {
  const _BreedingHistory({required this.pond});

  final Pond pond;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Lịch sử gây giống',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final litter in pond.litters.reversed.take(15))
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Glyph(litter.species, tail: litter.tails.first, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        'Ngày ${litter.bornAt ~/ Pond.daySeconds + 1} · '
                            '${litter.species.label} #${litter.id}',
                        if (litter.lost)
                          '${litter.eggs} trứng bị bố mẹ ăn'
                        else if (litter.eggs case final eggs?)
                          '$eggs trứng → ${litter.born} nở'
                        else
                          '${litter.born} con',
                        if (litter.comets > 0) '${litter.comets} Legendary',
                        if (!litter.lost) 'còn ${pond.alive(litter.id)}',
                        ?_parents(litter),
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Zones extends StatelessWidget {
  const _Zones({required this.pond, required this.controller});

  final Pond pond;
  final PondController controller;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pond.hasNursery) ...[
            const Text(
              'Khu ươm',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${pond.inZone(Zone.nursery)}/${pond.nurseryCapacity} cá · '
              'nước ${pond.nurseryWater.round()}% · no ${pond.nurserySatiety.round()}%\n'
              'Cá lớn không săn được cá con ở đây. Cá lớn lên tự về bể chính.',
              style: const TextStyle(color: _subtle, fontSize: 12, height: 1.4),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Cá mới nở vào khu ươm'),
              value: pond.autoNursery,
              onChanged: (value) =>
                  controller.act((pond) => pond.autoNursery = value),
            ),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed:
                      pond.nurseryWater >= 99 ||
                          pond.coins < Pond.waterChangeCost
                      ? null
                      : () => controller.act(
                          (pond) => pond.changeWater(Zone.nursery),
                        ),
                  child: const Text('Thay nước khu ươm · 12 xu'),
                ),
                OutlinedButton(
                  onPressed: pond.inZone(Zone.nursery) == 0
                      ? null
                      : () => controller.act((pond) => pond.feed(Zone.nursery)),
                  child: const Text('Rải mồi khu ươm'),
                ),
              ],
            ),
          ],
          if (pond.cups > 0) ...[
            if (pond.hasNursery) const SizedBox(height: 10),
            const Text(
              'Ngăn betta',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${pond.inZone(Zone.cups)}/${pond.cups} ngăn có cá. '
              'Betta trống thừa tự vào ngăn trống, không đánh nhau và vẫn kiếm xu.',
              style: const TextStyle(color: _subtle, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reports its child's laid-out size whenever it changes.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) => renderObject.onChange = onChange;
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reported) return;
    final current = _reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(current));
  }
}
