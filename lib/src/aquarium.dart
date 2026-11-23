import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'pond.dart';

Color tailColor(Tail tail) => switch (tail) {
  Tail.amber => const Color(0xffffa164),
  Tail.violet => const Color(0xffc8a4ff),
  Tail.rose => const Color(0xffff8db3),
};

const _neonBlue = Color(0xff4fd8ff);
const _neonRed = Color(0xffff4d6d);
const _bronze = Color(0xffd59a5a);
const _silver = Color(0xffe8f2f6);
const _platyRed = Color(0xffff735b);
const _swordGreen = Color(0xffb8ec71);
const _zebraSilver = Color(0xffb3b9ff);
const _honeyGold = Color(0xffffc769);
const _ramBlue = Color(0xff74ebdd);

/// The colour that best identifies a fish of [species] with [tail].
Color fishColor(Species species, Tail tail) {
  if (species.color case final rgb?) return Color(0xff000000 | rgb);
  return switch (species.style) {
    FishStyle.guppy || FishStyle.betta => tailColor(tail),
    FishStyle.neon => _neonBlue,
    FishStyle.corydoras => _bronze,
    FishStyle.angelfish => _silver,
    FishStyle.platy => _platyRed,
    FishStyle.swordtail => _swordGreen,
    FishStyle.zebrafish => _zebraSilver,
    FishStyle.honeyGourami => _honeyGold,
    FishStyle.ram => _ramBlue,
  };
}

/// Where a corpse rests, as fractions of the tank size.
///
/// [lift] raises the floor (negative values) when controls cover its foot.
Offset corpseSpot(Corpse corpse, [double lift = 0]) =>
    Offset(corpse.x, .8 + lift + (corpse.id * .2914 % 1) * .04);

/// Where the feeder and filter hang on the glass, across the tank's width.
const _feederX = .11;
const _filterX = .89;

/// Cup [index] of [count] in the betta cup view, as fractions of the tank.
Rect cupRect(int index, int count, {double top = .25, double bottom = .86}) {
  final columns = count <= 4 ? 2 : 3;
  final rows = (count / columns).ceil();
  final area = Rect.fromLTRB(.06, top, .94, bottom);
  final width = area.width / columns;
  final height = area.height / math.max(rows, 2);
  final column = index % columns;
  final row = index ~/ columns;
  return Rect.fromLTWH(
    area.left + column * width + width * .08,
    area.top + row * height + height * .08,
    width * .84,
    height * .84,
  );
}

class Aquarium extends StatefulWidget {
  const Aquarium({
    super.key,
    required this.pond,
    required this.onFeed,
    this.onScoop,
    this.onSelect,
    this.selectedId,
    this.onZoom,
    this.zone = Zone.main,
    this.overlay = EdgeInsets.zero,
  });

  final Pond pond;

  /// Space the screen's controls cover at the top and bottom. The water
  /// surface sits below the top controls and the floor rises above the
  /// bottom ones.
  final EdgeInsets overlay;

  /// Which part of the pond to show.
  final Zone zone;
  final VoidCallback onFeed;
  final ValueChanged<Corpse>? onScoop;

  /// Called when the player picks a fish: a long press at any zoom, or a
  /// tap while zoomed in.
  final ValueChanged<Fish>? onSelect;

  /// The fish to highlight and follow.
  final int? selectedId;
  final ValueChanged<double>? onZoom;

  @override
  State<Aquarium> createState() => AquariumState();
}

class AquariumState extends State<Aquarium>
    with SingleTickerProviderStateMixin {
  static const maxZoom = 5.0;

  /// Above this zoom a tap picks a fish instead of feeding.
  static const pickZoom = 1.3;

  late final _TankMotion _motion;
  late final Ticker _ticker;
  double _gestureZoom = 1;
  Offset _gestureAnchor = Offset.zero;

  double get zoom => _motion.zoom;

  @override
  void initState() {
    super.initState();
    _motion = _TankMotion(widget.pond, widget.zone)
      ..selected = widget.selectedId
      ..onZoom = widget.onZoom;
    _ticker = createTicker(_motion.tick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.reduced = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(Aquarium oldWidget) {
    super.didUpdateWidget(oldWidget);
    _motion.onZoom = widget.onZoom;
    if (widget.zone != oldWidget.zone) {
      _motion.showZone(widget.zone);
      resetView();
    }
    if (widget.selectedId != oldWidget.selectedId) {
      _motion.selected = widget.selectedId;
      _motion.follow = widget.selectedId != null;
      if (widget.selectedId != null && _motion.zoom < 2.5) {
        _motion.targetZoom = 2.5;
      }
    }
  }

  void feed([Offset target = const Offset(.51, .51)]) {
    if (widget.pond.fish.isEmpty) return;
    _motion.drop(target);
    widget.onFeed();
  }

  /// Zooms back out to the whole tank.
  void resetView() {
    _motion
      ..follow = false
      ..targetZoom = null
      ..setView(1, const Offset(.5, .5));
  }

  /// Where fish [id] is drawn, in local coordinates of a tank of [size].
  @visibleForTesting
  Offset? fishPosition(int id, Size size) {
    final pose = _motion.poses[id];
    if (pose == null) return null;
    return _motion.toScreen(Offset(pose.x, pose.y), size);
  }

  /// Where each snail is drawn, as fractions of the tank size.
  @visibleForTesting
  List<Offset> get snailSpots => [
    for (final (index, x) in _motion.snails.indexed)
      Offset(x, _motion.snailLane(index)),
  ];

  Fish? _fishAt(Offset point, Size size) {
    final scale = _motion.spriteScale(size) * _motion.zoom;
    Fish? best;
    var bestDistance = double.infinity;
    for (final pose in _motion.poses.values) {
      final distance =
          (_motion.toScreen(Offset(pose.x, pose.y), size) - point).distance;
      final reach = math.max(
        26.0,
        30 * scale * pose.fish.growth(widget.pond.time),
      );
      if (distance < reach && distance < bestDistance) {
        best = pose.fish;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _tap(Offset point, Size size) {
    final onScoop = widget.onScoop;
    if (onScoop != null) {
      for (final corpse in _motion.corpses.toList().reversed) {
        final spot = _motion.toScreen(corpseSpot(corpse, _motion.lift), size);
        if ((spot - point).distance < 30) {
          onScoop(corpse);
          return;
        }
      }
    }
    final onSelect = widget.onSelect;
    if (onSelect != null && _motion.zoom > pickZoom) {
      if (_fishAt(point, size) case final fish?) {
        onSelect(fish);
        return;
      }
    }
    final tank = _motion.toTank(point, size);
    feed(tank);
  }

  void _longPress(Offset point, Size size) {
    final onSelect = widget.onSelect;
    if (onSelect == null) return;
    if (_fishAt(point, size) case final fish?) onSelect(fish);
  }

  void _scaleStart(ScaleStartDetails details, Size size) {
    _gestureZoom = _motion.zoom;
    _gestureAnchor = _motion.toTank(details.localFocalPoint, size);
  }

  void _scaleUpdate(ScaleUpdateDetails details, Size size) {
    final zoom = (_gestureZoom * details.scale).clamp(1.0, maxZoom);
    if (zoom == 1 && _motion.zoom == 1) return;
    final focal = details.localFocalPoint;
    // Keep the tank point under the fingers where it started.
    final center =
        _gestureAnchor -
        Offset(
          (focal.dx / size.width - .5) / zoom,
          (focal.dy / size.height - .5) / zoom,
        );
    _motion
      ..follow = false
      ..targetZoom = null
      ..setView(zoom, center);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _motion
          ..surface = (widget.overlay.top / size.height + .03).clamp(.18, .4)
          ..lift = (.03 - widget.overlay.bottom / size.height + 1 - .93).clamp(
            -.15,
            0.0,
          )
          ..laneGap = math.max(.02, 13 / size.height);
        return Semantics(
          button: true,
          label: 'Rải thức ăn vào hồ',
          onTap: () => feed(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: (event) => _tap(event.localPosition, size),
            onLongPressStart: (event) => _longPress(event.localPosition, size),
            onScaleStart: (details) => _scaleStart(details, size),
            onScaleUpdate: (details) => _scaleUpdate(details, size),
            child: SizedBox.expand(
              child: ClipRect(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _AquariumPainter(_motion)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pose {
  _Pose(this.fish, this.phase, this.x, this.y, this.yaw)
    : trail = fish.isComet ? [] : null;
  final Fish fish;
  final double phase;
  final List<_CometTrailSample>? trail;
  double x;
  double y;
  double yaw;
  double pitch = 0;

  double get facing => (yaw < 0 ? -1 : 1) * math.max(.13, yaw.abs());
}

const _trailLifetime = .65;

(Offset, Offset) _cometTips(double phase, double time) {
  final flap = time * 20 + phase;
  return (
    Offset(-71, -21 + 4.5 * math.sin(flap)),
    Offset(-70, 21 + 4.5 * math.sin(flap - 1.25)),
  );
}

class _CometTrailSample {
  _CometTrailSample(_Pose pose, this.time)
    : center = Offset(pose.x, pose.y),
      facing = pose.facing,
      pitch = pose.pitch,
      tips = _cometTips(pose.phase, time);

  final double time;
  final Offset center;
  final double facing;
  final double pitch;
  final (Offset, Offset) tips;

  Offset tipInTank(Size size, double scale, {required bool upper}) {
    final tip = upper ? tips.$1 : tips.$2;
    final x = tip.dx * facing;
    final cosine = math.cos(pitch);
    final sine = math.sin(pitch);
    return Offset(
      center.dx * size.width + (x * cosine - tip.dy * sine) * scale,
      center.dy * size.height + (x * sine + tip.dy * cosine) * scale,
    );
  }
}

class _TankMotion extends ChangeNotifier {
  _TankMotion(this.pond, this.zone);

  final Pond pond;
  Zone zone;

  /// Cup index of each betta shown in the cup view.
  final Map<int, int> cupSlots = {};
  double _seenAutoFeed = -1;

  Iterable<Corpse> get corpses => pond.corpses.where(
    (corpse) => (corpse.zone == Zone.nursery) == (zone == Zone.nursery),
  );

  void showZone(Zone value) {
    zone = value;
    poses.clear();
    target = null;
    _nextSync = 0;
    notifyListeners();
  }

  final Map<int, _Pose> poses = {};
  final List<double> snails = [];
  Duration _last = Duration.zero;
  double time = 0;
  double _nextSync = 0;
  bool reduced = false;
  Offset? target;
  double droppedAt = -10;

  /// The view: magnification, and the tank point (as fractions) at the
  /// centre of the screen.
  double zoom = 1;
  Offset center = const Offset(.5, .5);

  /// The water surface, and how far the floor is raised (negative), as
  /// fractions of the tank height. Fish positions are laid out for a surface
  /// at .18 and a floor at .93, then fitted between these.
  double surface = .18;
  double lift = 0;

  double fitY(double y) => surface + (y - .18) * (.93 + lift - surface) / .75;
  double? targetZoom;
  int? selected;
  bool follow = false;
  ValueChanged<double>? onZoom;

  double spriteScale(Size size) {
    final density = math.max(1, poses.length / _AquariumPainter.detailedFish);
    return (size.shortestSide / 420).clamp(.77, 1.24) *
        (1 / math.sqrt(density)).clamp(.42, 1);
  }

  Offset toTank(Offset local, Size size) => Offset(
    (local.dx / size.width - .5) / zoom + center.dx,
    (local.dy / size.height - .5) / zoom + center.dy,
  );

  Offset toScreen(Offset tank, Size size) => Offset(
    ((tank.dx - center.dx) * zoom + .5) * size.width,
    ((tank.dy - center.dy) * zoom + .5) * size.height,
  );

  /// Whether the tank point [tank] is on screen, with [margin] to spare.
  bool visible(Offset tank, [double margin = .06]) {
    final half = .5 / zoom + margin;
    return (tank.dx - center.dx).abs() < half &&
        (tank.dy - center.dy).abs() < half;
  }

  void setView(double newZoom, Offset newCenter) {
    final previous = zoom;
    zoom = newZoom.clamp(1.0, AquariumState.maxZoom);
    final half = .5 / zoom;
    center = Offset(
      newCenter.dx.clamp(half, 1 - half),
      newCenter.dy.clamp(half, 1 - half),
    );
    if ((previous - zoom).abs() > 1e-6) onZoom?.call(zoom);
    notifyListeners();
  }

  void drop(Offset point) {
    target = Offset(
      point.dx.clamp(.08, .92).toDouble(),
      // Food lands below the surface, so fish never chase it into the air.
      point.dy.clamp(surface + .1, .87 + lift).toDouble(),
    );
    droppedAt = time;
    notifyListeners();
  }

  void tick(Duration elapsed) {
    final delta = ((elapsed - _last).inMicroseconds / 1000000).clamp(0.0, .038);
    _last = elapsed;
    time += delta;
    if (time >= _nextSync) {
      _syncFish();
      _nextSync = time + .65;
    }

    // Show the feeder's own drops in the main tank.
    if (pond.lastAutoFeed != _seenAutoFeed) {
      if (_seenAutoFeed >= 0 && zone == Zone.main) {
        drop(Offset(_feederX + .02, surface + .22));
      }
      _seenAutoFeed = pond.lastAutoFeed;
    }
    final activeTarget = time - droppedAt < 2.9 ? target : null;
    final movingTime = time * (reduced ? .32 : 1);
    for (final pose in poses.values) {
      final natural = _position(pose, movingTime);
      final ahead = _position(pose, movingTime + .15);
      final phase = pose.phase;
      final bottom =
          pose.fish.species.style == FishStyle.corydoras ||
          pose.fish.species.style == FishStyle.ram;
      final destination = activeTarget == null
          ? natural
          : bottom
          ? Offset(activeTarget.dx + math.sin(phase) * .06, natural.dy)
          : Offset(
              activeTarget.dx + math.sin(phase) * .084,
              (activeTarget.dy + math.cos(phase) * .16).clamp(
                surface + .06,
                .9 + lift,
              ),
            );
      final dx = destination.dx - pose.x;
      final dy = destination.dy - pose.y;
      final attraction = activeTarget == null ? 1.85 : 2.4;
      pose.x += dx * delta * attraction;
      pose.y += dy * delta * attraction;
      final direction = activeTarget == null
          ? _heading(ahead.dx - natural.dx)
          : (dx * 10).clamp(-1, 1);
      pose.yaw += (direction - pose.yaw) * delta * 7;
      final pitch = (dy * 1.8).clamp(-.23, .23) * pose.yaw.sign;
      pose.pitch += (pitch - pose.pitch) * delta * 5;
      if (pose.trail case final trail?) {
        if (reduced) {
          trail.clear();
        } else {
          trail.removeWhere((sample) => time - sample.time >= _trailLifetime);
          if (trail.isEmpty || time - trail.last.time >= .042) {
            trail.add(_CometTrailSample(pose, time));
          }
        }
      }
    }

    // Snails crawl along the floor towards a corpse, fanning out around it
    // rather than piling onto one spot.
    final corpses = this.corpses.toList();
    for (var i = 0; i < snails.length; i++) {
      double goal;
      if (corpses.isEmpty) {
        goal = .5 + math.sin(movingTime * .05 + i * 2.1) * .42;
      } else {
        final rank = i ~/ corpses.length;
        final side = rank.isEven ? 1 : -1;
        goal = corpses[i % corpses.length].x + side * (rank + 1) ~/ 2 * .04;
      }
      final step = (goal.clamp(.04, .96) - snails[i]).clamp(
        -.012 * delta,
        .012 * delta,
      );
      snails[i] += step;
    }
    _spreadSnails();

    // Glide the camera towards the followed fish and any requested zoom.
    final ease = math.min(1.0, delta * 4);
    var nextZoom = zoom;
    if (targetZoom case final goal?) {
      nextZoom += (goal - zoom) * ease;
      if ((goal - nextZoom).abs() < .01) {
        nextZoom = goal;
        targetZoom = null;
      }
    }
    var nextCenter = center;
    if (poses[selected] case final pose? when follow) {
      nextCenter += (Offset(pose.x, pose.y) - center) * ease;
    }
    if (nextZoom != zoom || nextCenter != center) {
      setView(nextZoom, nextCenter);
    }
    notifyListeners();
  }

  /// Which way a fish faces, from how far it moves across .15 s. Slow
  /// swimmers such as angelfish still face fully sideways; only a fish that
  /// has nearly stopped to turn is drawn edge-on.
  static double _heading(double step) => (step * 600).clamp(-1.0, 1.0);

  static const snailLanes = 3;
  static const _snailGap = .045;

  /// The floor row snail [index] crawls along, as a fraction of the height.
  /// Gap between snail rows: 2% of the height, but never less than a shell.
  double laneGap = .02;

  double snailLane(int index) =>
      .885 + lift - (snailLanes - 1 - index % snailLanes) * laneGap;

  /// Keeps snails sharing a row at least [_snailGap] apart.
  void _spreadSnails() {
    for (var lane = 0; lane < snailLanes; lane++) {
      final order = [for (var i = lane; i < snails.length; i += snailLanes) i]
        ..sort((a, b) => snails[a].compareTo(snails[b]));
      for (var k = 1; k < order.length; k++) {
        final left = order[k - 1];
        final right = order[k];
        final overlap = _snailGap - (snails[right] - snails[left]);
        if (overlap <= 0) continue;
        snails[left] -= overlap / 2;
        snails[right] += overlap / 2;
      }
      for (final i in order) {
        snails[i] = snails[i].clamp(.03, .97);
      }
    }
  }

  Offset _position(_Pose pose, double movingTime) {
    final point = _layout(pose, movingTime);
    if (cupSlots.containsKey(pose.fish.id)) return point;
    return Offset(point.dx, fitY(point.dy));
  }

  Offset _layout(_Pose pose, double movingTime) {
    final fish = pose.fish;
    final phase = pose.phase;
    final depth = fish.id * .41421356 % 1;
    if (cupSlots[fish.id] case final slot?) {
      final cup = cupRect(
        slot,
        math.max(pond.cups, cupSlots.length),
        top: surface + .07,
        bottom: .86 + lift,
      );
      final cycle = movingTime * .3 + phase;
      return cup.center +
          Offset(
            math.sin(cycle) * cup.width * .22,
            math.cos(cycle * 1.3) * cup.height * .15,
          );
    }
    if (zone == Zone.nursery) {
      final cycle = movingTime * .4 + phase;
      return Offset(
        .5 + math.sin(cycle) * (.3 + (fish.id % 4) * .03),
        .3 + depth * .5 + math.cos(cycle * 1.1) * .03,
      );
    }
    if (fish.age(pond.time) < Pond.fryDays && pond.sheltered > 0) {
      final cycle = movingTime * .44 + phase;
      return Offset(
        (fish.id.isEven ? .19 : .84) + math.sin(cycle) * .07,
        .72 + depth * .13 + math.cos(cycle) * .03,
      );
    }
    switch (fish.species.style) {
      case FishStyle.neon:
        // The school follows one shared path; each fish keeps its slot.
        final centre = Offset(
          .5 + math.sin(movingTime * .21) * .27,
          .42 + math.cos(movingTime * .17) * .12,
        );
        return centre +
            Offset(
              math.sin(phase) * .075 + math.sin(movingTime * .9 + phase) * .01,
              math.cos(phase * 1.3) * .055,
            );
      case FishStyle.corydoras:
        return Offset(
          .5 + math.sin(movingTime * .18 + phase) * .38,
          .79 + depth * .05 + math.sin(movingTime * 1.7 + phase) * .006,
        );
      case FishStyle.betta:
        final cycle = movingTime * .22 + phase;
        return Offset(
          .5 + math.sin(cycle) * .3,
          .25 + depth * .35 + math.cos(cycle * 1.1) * .03,
        );
      case FishStyle.angelfish:
        final cycle = movingTime * .26 + phase;
        return Offset(
          .5 + math.sin(cycle) * .27,
          .35 + depth * .3 + math.cos(cycle * .9) * .04,
        );
      case FishStyle.guppy:
        final cycle = movingTime * .44 + phase;
        return Offset(
          .5 + math.sin(cycle) * (.29 + (fish.id % 3) * .047),
          .29 + depth * .50 + math.cos(cycle * 1.07) * .031,
        );
      case FishStyle.platy:
        final cycle = movingTime * .33 + phase;
        return Offset(
          (fish.id.isEven ? .27 : .73) + math.sin(cycle) * .18,
          .47 + depth * .2 + math.cos(cycle * 1.3) * .05,
        );
      case FishStyle.swordtail:
        final cycle = movingTime * .52 + phase;
        return Offset(
          .5 + math.sin(cycle) * .43,
          .34 + depth * .28 + math.cos(cycle * 1.2) * .05,
        );
      case FishStyle.zebrafish:
        final cycle = movingTime * .65;
        return Offset(
          .5 + math.sin(cycle) * .28 + math.sin(phase) * .1,
          .3 + math.cos(cycle * .8) * .07 + math.cos(phase * 1.3) * .06,
        );
      case FishStyle.honeyGourami:
        final cycle = movingTime * .19 + phase;
        return Offset(
          .5 + math.sin(cycle) * .27,
          .23 + depth * .19 + math.cos(cycle * 1.5) * .07,
        );
      case FishStyle.ram:
        final cycle = movingTime * .28 + phase;
        return Offset(
          (fish.id.isEven ? .32 : .68) + math.sin(cycle) * .18,
          .72 + depth * .09 + math.cos(cycle * 1.9) * .019,
        );
    }
  }

  void _syncFish() {
    final ids = <int>{};
    final movingTime = time * (reduced ? .32 : 1);
    final shown = pond.fish.where((fish) => fish.zone == zone).toList();
    cupSlots.clear();
    if (zone == Zone.cups) {
      for (final (index, fish) in shown.indexed) {
        cupSlots[fish.id] = index;
      }
    }
    for (final fish in shown) {
      ids.add(fish.id);
      poses.putIfAbsent(fish.id, () {
        final phase = fish.id * 2.39996;
        final pose = _Pose(fish, phase, .5, .5, 1);
        final point = _position(pose, movingTime);
        final ahead = _position(pose, movingTime + .15);
        return pose
          ..x = point.dx
          ..y = point.dy
          ..yaw = _heading(ahead.dx - point.dx);
      });
    }
    poses.removeWhere((id, pose) => !ids.contains(id));
    final snailCount = zone == Zone.main ? pond.snails : 0;
    if (snails.length > snailCount) snails.length = snailCount;
    while (snails.length < snailCount) {
      snails.add(.1 + snails.length * .618 % .8);
    }
  }
}

class _AquariumPainter extends CustomPainter {
  _AquariumPainter(this.motion) : super(repaint: motion);

  final _TankMotion motion;
  static const detailedFish = 24;
  static const _mint = Color(0xff8af9d6);
  static const _cometViolet = Color(0xffbd83ff);
  static final _cometTail = const LinearGradient(
    colors: [_cometViolet, Color(0xfff69eda), Color(0xffffab59)],
  ).createShader(const Rect.fromLTRB(-71, -25, -22, 25));
  // Sunlit blue water: bright under the surface, deepening towards the sand.
  static const _glass = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xff2f8fcf),
      Color(0xff1b6fae),
      Color(0xff0f4d82),
      Color(0xff083159),
    ],
    stops: [0, .2, .58, 1],
  );
  static const _ground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00062744), Color(0xff062744)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final zoomed = motion.zoom != 1;
    if (zoomed) {
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(motion.zoom);
      canvas.translate(
        -motion.center.dx * size.width,
        -motion.center.dy * size.height,
      );
    }
    _paintTank(canvas, size);
    if (zoomed) canvas.restore();
  }

  void _paintTank(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final time = motion.time * (motion.reduced ? .32 : 1);
    final paint = Paint()..shader = _glass.createShader(rect);
    canvas.drawRect(rect, paint);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var row = 0; row < 3; row++) {
      final ripple = Path();
      for (double x = 0; x < size.width + 8; x += 8) {
        final y =
            size.height * (motion.surface + row * .015) +
            math.sin(x * .023 + time * .7 + row * 1.4) * 1.9;
        if (x == 0) {
          ripple.moveTo(x, y);
        } else {
          ripple.lineTo(x, y);
        }
      }
      line
        ..color = const Color(0xff84c9c1).withValues(alpha: .26 - row * .056)
        ..strokeWidth = .85;
      canvas.drawPath(ripple, line);
    }

    final floor = Rect.fromLTWH(
      0,
      size.height * (.72 + motion.lift),
      size.width,
      size.height * (.28 - motion.lift),
    );
    canvas.drawRect(floor, paint..shader = _ground.createShader(floor));
    paint.shader = null;
    for (var i = 0; i < 52; i++) {
      final x = size.width * (i * .6137 % 1);
      final y = size.height * (.837 + motion.lift + (i * .79187 % 1) * .143);
      paint.color = i % 5 == 0
          ? const Color(0x665fb99a)
          : const Color(0x3066a790);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: i % 5 == 0 ? 4 : 2,
          height: 1.1,
        ),
        paint,
      );
    }

    for (var i = 0; i < 12; i++) {
      final opacityPhase = (time * (.062 + i % 4 * .011) + i * .143) % 1;
      final x =
          size.width * (.08 + i * .297 % .85) +
          math.sin(opacityPhase * 9 + i) * 4;
      final floor = .88 + motion.lift;
      final y = size.height * (floor - opacityPhase * (floor - motion.surface));
      line
        ..color = const Color(0xffa6eff0)
            .withValues(alpha: math.sin(opacityPhase * math.pi) * .27)
        ..strokeWidth = .85;
      canvas.drawCircle(Offset(x, y), 1 + i % 4 * .77, line);
    }

    switch (motion.zone) {
      case Zone.main:
        _drawPlants(canvas, size, line, time);
        _drawMoss(canvas, size, line, motion.pond.levels[Equipment.javaMoss]!);
        _drawFeeder(canvas, size, paint, line);
        _drawFilter(canvas, size, line, time);
        _drawClutches(canvas, size, paint, line, time);
      case Zone.nursery:
        _drawMoss(canvas, size, line, 5);
      case Zone.cups:
        _drawCups(canvas, size, paint, line);
    }
    _drawCorpses(canvas, size, line, time);
    _drawSnails(canvas, size, line);
    final spriteScale = motion.spriteScale(size);
    if (!motion.reduced) {
      for (final pose in motion.poses.values) {
        if (pose.trail case final trail?
            when trail.length > 1 && motion.visible(Offset(pose.x, pose.y))) {
          _drawCometTrail(canvas, size, pose, trail, spriteScale, line, paint);
        }
      }
    }
    var index = 0;
    // Zoomed in, fish on screen get full detail, and fish off screen are
    // skipped. Blur grows with the zoom, so only the picked fish keeps it.
    var closeUps = 0;
    final zoomed = motion.zoom > 1.01;
    for (final pose in motion.poses.values) {
      if (zoomed && !motion.visible(Offset(pose.x, pose.y))) {
        index++;
        continue;
      }
      final detailed =
          index < detailedFish ||
          pose.fish.isComet ||
          motion.pond.breeders.contains(pose.fish.id) ||
          (zoomed && closeUps++ < 60);
      _drawFish(
        canvas,
        size,
        pose,
        spriteScale,
        time,
        line,
        detailed: detailed,
        soft: !zoomed || pose.fish.id == motion.selected,
      );
      index++;
    }
    if (motion.poses[motion.selected] case final pose?) {
      final radius = 28 * _fishScale(pose.fish, spriteScale) + 6;
      line
        ..color = const Color(0xffffffff)
            .withValues(alpha: .55 + math.sin(motion.time * 4) * .2)
        ..strokeWidth = 1.6 / motion.zoom;
      canvas.drawCircle(
        Offset(pose.x * size.width, pose.y * size.height),
        radius,
        line,
      );
    }
    final point = motion.target;
    final sinceDrop = motion.time - motion.droppedAt;
    if (point != null && sinceDrop < 2.3) {
      for (var i = 0; i < 8; i++) {
        final x = (point.dx + math.sin(i * 4) * .052) * size.width;
        final y =
            (point.dy - .12 + sinceDrop * (.066 + i % 3 * .014)) * size.height;
        final remaining = (2.3 - sinceDrop - i * .065).clamp(0, 1).toDouble();
        paint.color = const Color(0xffffcf83).withValues(alpha: remaining);
        canvas.drawCircle(Offset(x, y - i % 4 * 4), 1 + i % 3 * .45, paint);
      }
    }
  }

  double _fishScale(Fish fish, double scale) =>
      scale *
      (.26 + fish.growth(motion.pond.time) * .70) *
      switch (fish.species.style) {
        FishStyle.neon => .75,
        FishStyle.corydoras => .85,
        FishStyle.angelfish => 1.15,
        FishStyle.platy => .94,
        FishStyle.swordtail => 1.05,
        FishStyle.zebrafish => .84,
        FishStyle.honeyGourami => .95,
        FishStyle.ram => 1.02,
        _ => 1.0,
      };

  void _drawCometTrail(
    Canvas canvas,
    Size size,
    _Pose pose,
    List<_CometTrailSample> trail,
    double scale,
    Paint line,
    Paint fill,
  ) {
    scale = _fishScale(pose.fish, scale);
    final now = _CometTrailSample(pose, motion.time);
    for (final upper in [true, false]) {
      var previous = now.tipInTank(size, scale, upper: upper);
      var samplesBack = 0;
      for (final sample in trail.reversed) {
        final tip = sample.tipInTank(size, scale, upper: upper);
        final freshness = 1 - (motion.time - sample.time) / _trailLifetime;
        final strength = freshness * freshness;
        line
          ..color = _cometViolet.withValues(alpha: strength * .50)
          ..strokeWidth = math.max(.6, scale * (1.0 + strength * 3.0));
        canvas.drawLine(previous, tip, line);
        samplesBack++;
        final mote = upper
            ? samplesBack == 4 || samplesBack == 12
            : samplesBack == 8;
        if (mote) {
          fill.color = _cometViolet.withValues(alpha: freshness * .78);
          canvas.drawCircle(
            tip + Offset(0, upper ? -2.5 : 2.5),
            1 + strength * 1.2,
            fill,
          );
        }
        previous = tip;
      }
    }
  }

  /// Java moss tufts on the sand; more levels, more tufts.
  void _drawMoss(Canvas canvas, Size size, Paint paint, int level) {
    final tufts = math.min(18, level * 3);
    paint.strokeWidth = 1.2;
    for (var i = 0; i < tufts; i++) {
      final side = i.isEven ? .2 : .8;
      final base = Offset(
        size.width * (side + (i * .137 % .16) - .08),
        size.height * (.86 + motion.lift + (i * .071 % .05)),
      );
      paint.color = i % 3 == 0
          ? const Color(0xff4fae7f)
          : const Color(0xff3a8f68);
      final tuft = Path();
      for (var j = 0; j < 6; j++) {
        final angle = -math.pi / 2 + (j - 2.5) * .32;
        final length = 7.0 + (i + j) % 3 * 2;
        final tip = base + Offset(math.cos(angle), math.sin(angle)) * length;
        tuft
          ..moveTo(base.dx, base.dy)
          ..lineTo(tip.dx, tip.dy);
      }
      canvas.drawPath(tuft, paint);
    }
  }

  /// The feeder clips to the glass above the water once it is bought.
  /// A hopper clipped over the rim. Its amber fill shows the food left in
  /// storage.
  void _drawFeeder(Canvas canvas, Size size, Paint fill, Paint line) {
    final pond = motion.pond;
    if (pond.levels[Equipment.feeder] == 0) return;
    final at = Offset(
      _feederX * size.width,
      (motion.surface + .02) * size.height,
    );
    final hopper = Path()
      ..moveTo(at.dx - 15, at.dy - 22)
      ..lineTo(at.dx + 15, at.dy - 22)
      ..lineTo(at.dx + 6, at.dy)
      ..lineTo(at.dx - 6, at.dy)
      ..close();
    fill.color = const Color(0xcc0d2a3c);
    canvas.drawPath(hopper, fill);
    final stored = (pond.stock / pond.capacity).clamp(0.0, 1.0);
    if (stored > 0) {
      canvas.save();
      canvas.clipPath(hopper);
      fill.color = const Color(0xccffb85c);
      canvas.drawRect(
        Rect.fromLTRB(at.dx - 15, at.dy - 22 * stored, at.dx + 15, at.dy),
        fill,
      );
      canvas.restore();
    }
    line
      ..color = const Color(0xffd8e4e8)
      ..strokeWidth = 1.4;
    canvas.drawPath(hopper, line);
    // Clip over the rim and a short chute into the water.
    canvas.drawPath(
      Path()
        ..moveTo(at.dx + 15, at.dy - 18)
        ..lineTo(at.dx + 21, at.dy - 18)
        ..lineTo(at.dx + 21, at.dy - 6)
        ..moveTo(at.dx, at.dy)
        ..lineTo(at.dx, at.dy + 9),
      line,
    );
  }

  /// A hang-on canister: an intake pipe reaches down into the tank and the
  /// spout pushes a stream of bubbles that grows with the filter's level.
  void _drawFilter(Canvas canvas, Size size, Paint line, double time) {
    final level = motion.pond.levels[Equipment.filter]!;
    if (level == 0) return;
    final at = Offset(
      _filterX * size.width,
      (motion.surface + .02) * size.height,
    );
    line
      ..color = const Color(0xffd8e4e8)
      ..strokeWidth = 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(at.dx - 6, at.dy - 26, at.dx + 14, at.dy + 4),
        const Radius.circular(3),
      ),
      line,
    );
    final intakeBottom = size.height * (motion.surface + .32);
    final spout = Offset(at.dx - 16, at.dy + 6);
    canvas.drawPath(
      Path()
        // Intake pipe with a slotted strainer at its foot.
        ..moveTo(at.dx + 4, at.dy + 4)
        ..lineTo(at.dx + 4, intakeBottom)
        ..moveTo(at.dx + 1, intakeBottom - 12)
        ..lineTo(at.dx + 1, intakeBottom)
        ..moveTo(at.dx + 7, intakeBottom - 12)
        ..lineTo(at.dx + 7, intakeBottom)
        // Spout lip over the water.
        ..moveTo(at.dx - 6, at.dy - 4)
        ..lineTo(spout.dx, spout.dy - 4)
        ..lineTo(spout.dx, spout.dy),
      line,
    );
    final bubbles = math.min(24, 3 + level * 3);
    final reach = size.width * (.12 + level * .035).clamp(0, .45);
    for (var i = 0; i < bubbles; i++) {
      final progress = (time * (.35 + level * .05) + i / bubbles) % 1;
      final point =
          spout +
          Offset(
            -progress * reach,
            progress * 26 + math.sin(progress * 9 + i) * 4,
          );
      line
        ..color = const Color(0xffcff4ff).withValues(alpha: (1 - progress) * .6)
        ..strokeWidth = .8;
      canvas.drawCircle(point, 1 + i % 3 * .6, line);
    }
  }

  void _drawCups(Canvas canvas, Size size, Paint fill, Paint line) {
    final count = math.max(motion.pond.cups, motion.cupSlots.length);
    for (var i = 0; i < count; i++) {
      final cup = cupRect(
        i,
        count,
        top: motion.surface + .07,
        bottom: .86 + motion.lift,
      );
      final rect = Rect.fromLTRB(
        cup.left * size.width,
        cup.top * size.height,
        cup.right * size.width,
        cup.bottom * size.height,
      );
      final glass = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(14),
        bottomRight: const Radius.circular(14),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      fill.color = const Color(0x2296d8ff);
      canvas.drawRRect(glass, fill);
      line
        ..color = const Color(0x88cdeeff)
        ..strokeWidth = 1.3;
      canvas.drawRRect(glass, line);
    }
  }

  void _drawPlants(Canvas canvas, Size size, Paint paint, double time) {
    final count = math.min(8, 2 + motion.pond.levels[Equipment.javaMoss]! * 2);
    for (var i = 0; i < count * 2; i++) {
      final x = size.width * ((i.isEven ? .14 : .86) + (i % 3 - 1) * .039);
      final y = size.height * (.93 + motion.lift);
      final height = size.height * (.11 + (i * .052 % .16));
      final sway = math.sin(time * .92 + i * 1.7) * height * .12;
      final stem = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x - height * .16,
          y - height * .50,
          x + sway,
          y - height,
        );
      paint
        ..color = i.isEven ? const Color(0xff399979) : const Color(0xff3e826c)
        ..strokeWidth = 1.35;
      canvas.drawPath(stem, paint);
      for (var j = 1; j <= 3; j++) {
        final portion = j * .22;
        final sx =
            x +
            sway * portion * portion -
            height * .32 * portion * (1 - portion);
        final sy = y - height * portion;
        final side = (i + j).isEven ? -1 : 1;
        final leaf = Path()
          ..moveTo(sx, sy)
          ..quadraticBezierTo(
            sx + side * height * .19,
            sy - height * .04,
            sx + side * height * .24,
            sy - height * .15,
          );
        canvas.drawPath(leaf, paint);
      }
    }
  }

  /// Eggs sit where each species lays them: bubble nests at the surface,
  /// clumps on plants, a cleaned stone, or scattered on the gravel.
  void _drawClutches(
    Canvas canvas,
    Size size,
    Paint fill,
    Paint line,
    double time,
  ) {
    for (final clutch in motion.pond.clutches) {
      final seed = clutch.id * .37 % 1;
      final dots = math.min(24, 4 + clutch.eggs ~/ 20);
      final bubbleNest =
          clutch.species.style == FishStyle.betta ||
          clutch.species.style == FishStyle.honeyGourami;
      final (anchor, spread, color) = switch (clutch.species.style) {
        FishStyle.betta || FishStyle.honeyGourami => (
          Offset(.3 + seed * .4, motion.surface + .015),
          const Offset(.05, .008),
          clutch.species.style == FishStyle.honeyGourami
              ? const Color(0xccffe6aa)
              : const Color(0xccf3f7ff),
        ),
        FishStyle.corydoras => (
          Offset(clutch.id.isEven ? .15 : .85, .76 + motion.lift + seed * .05),
          const Offset(.025, .03),
          const Color(0xddf1e3c0),
        ),
        FishStyle.angelfish || FishStyle.ram => (
          Offset(.25 + seed * .5, .84 + motion.lift),
          const Offset(.03, .012),
          const Color(0xddffd59a),
        ),
        _ => (
          Offset(.15 + seed * .7, .86 + motion.lift),
          const Offset(.12, .02),
          const Color(0x99d9f6ff),
        ),
      };
      if (clutch.species.style == FishStyle.ram) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(anchor.dx * size.width, anchor.dy * size.height + 3),
            width: size.width * .078,
            height: size.height * .033,
          ),
          fill..color = const Color(0xff334d50),
        );
      }
      for (var i = 0; i < dots; i++) {
        final offset = Offset(
          math.sin(i * 2.4 + clutch.id) * spread.dx,
          math.cos(i * 1.7 + clutch.id) * spread.dy,
        );
        final center = Offset(
          (anchor.dx + offset.dx) * size.width,
          (anchor.dy + offset.dy) * size.height,
        );
        if (bubbleNest) {
          line
            ..color = color.withValues(alpha: .5 + math.sin(time + i) * .2)
            ..strokeWidth = .8;
          canvas.drawCircle(center, 2 + i % 3, line);
        } else {
          fill.color = color;
          canvas.drawCircle(center, 1.3, fill);
        }
      }
    }
  }

  void _drawCorpses(Canvas canvas, Size size, Paint paint, double time) {
    final scale = (size.shortestSide / 420).clamp(.77, 1.24);
    for (final corpse in motion.corpses) {
      final spot = corpseSpot(corpse, motion.lift);
      final center = Offset(spot.dx * size.width, spot.dy * size.height);
      final length = 18 * scale * (.4 + corpse.remains * .6);
      final faded = fishColor(
        corpse.species,
        corpse.tail,
      ).withValues(alpha: .45 + corpse.remains * .25);
      paint
        ..color = faded
        ..strokeWidth = 2.8;
      // Lying on its side: a dim body line and a slack tail.
      canvas.drawLine(
        center - Offset(length * .5, 0),
        center + Offset(length * .5, 0),
        paint,
      );
      canvas.drawLine(
        center - Offset(length * .5, 0),
        center - Offset(length * .85, -length * .3),
        paint,
      );
      paint
        ..color = const Color(0xffffc77e)
            .withValues(alpha: .35 + math.sin(time * 3 + corpse.id) * .25)
        ..strokeWidth = 1.1;
      canvas.drawCircle(center - Offset(0, 16 * scale), 3.2 * scale, paint);
      canvas.drawLine(
        center - Offset(0, 12 * scale),
        center - Offset(0, 6 * scale),
        paint,
      );
    }
  }

  void _drawSnails(Canvas canvas, Size size, Paint paint) {
    for (var i = 0; i < motion.snails.length; i++) {
      final base = Offset(
        motion.snails[i] * size.width,
        size.height * motion.snailLane(i),
      );
      paint
        ..color = const Color(0xffd0664a)
        ..strokeWidth = 1.8;
      canvas.drawCircle(base - const Offset(0, 5), 5, paint);
      canvas.drawCircle(base - const Offset(-1, 5), 2.2, paint);
      paint
        ..color = const Color(0xffe8a58f)
        ..strokeWidth = 1.6;
      canvas.drawLine(
        base + const Offset(-6, 0),
        base + const Offset(7, 0),
        paint,
      );
    }
  }

  void _drawFish(
    Canvas canvas,
    Size size,
    _Pose pose,
    double scale,
    double time,
    Paint paint, {
    required bool detailed,
    bool soft = true,
  }) {
    final fish = pose.fish;
    scale = _fishScale(fish, scale);
    canvas.save();
    canvas.translate(pose.x * size.width, pose.y * size.height);
    canvas.rotate(pose.pitch);
    canvas.scale(scale * pose.facing, scale);
    final color = fishColor(fish.species, fish.tail);
    if (!detailed) {
      final flap = math.sin(time * 21 + pose.phase) * 2;
      paint
        ..color = color
        ..strokeWidth = 3.5;
      const tip = Offset(-9, 0);
      canvas.drawLine(Offset(-22, -9 + flap), tip, paint);
      canvas.drawLine(Offset(-22, 9 + flap), tip, paint);
      paint.color = fish.species.style == FishStyle.guppy ? _mint : color;
      canvas.drawLine(const Offset(-3, 0), const Offset(17, 0), paint);
      canvas.restore();
      return;
    }
    void glow(Path path, Color color, double width, {Shader? shader}) {
      if (soft) {
        paint
          ..strokeWidth = width + 1
          ..color = color.withValues(alpha: .57)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.8);
      } else {
        // A wide translucent stroke reads as glow without a blur pass.
        paint
          ..strokeWidth = width + 3.5
          ..color = color.withValues(alpha: .28);
      }
      canvas.drawPath(path, paint);
      paint
        ..strokeWidth = width
        ..color = color
        ..shader = shader
        ..maskFilter = null;
      canvas.drawPath(path, paint);
      paint.shader = null;
    }

    Path chevron(double x, double half) => Path()
      ..moveTo(x - half, -half)
      ..lineTo(x, 0)
      ..lineTo(x - half, half);

    void eye(Offset at, [double radius = 2.25]) =>
        canvas.drawCircle(at, radius, Paint()..color = const Color(0xffeafff5));

    final flap = math.sin(time * 21 + pose.phase);
    switch (fish.species.style) {
      case FishStyle.guppy:
        if (fish.isComet) {
          final (upper, lower) = _cometTips(pose.phase, time);
          final fork = Path()
            ..moveTo(upper.dx, upper.dy)
            ..quadraticBezierTo(-56, -20, -41, -7)
            ..quadraticBezierTo(-28, 0, -22, 0)
            ..quadraticBezierTo(-28, 0, -41, 7)
            ..quadraticBezierTo(-56, 20, lower.dx, lower.dy);
          glow(fork, _cometViolet, 3.7, shader: _cometTail);
        } else {
          final spread = fish.sex == Sex.male
              ? 10 + fish.vividness * .042
              : 10.0;
          for (final offset in fish.sex == Sex.male ? [0, 7] : [4]) {
            final tip = -20.0 + offset + flap * 2;
            final path = Path()
              ..moveTo(tip - 8 - flap * 2, -spread + flap)
              ..lineTo(tip, 0)
              ..lineTo(tip - 8 - flap * 2, spread + flap);
            glow(path, color, 3.0);
          }
        }
        for (final x in [-7.0, 2.0]) {
          final arc = Path()
            ..moveTo(x, -11)
            ..quadraticBezierTo(x - 12, 0, x, 11);
          glow(arc, _mint, 3.15);
        }
        glow(chevron(21, 4.5), _mint, 2.7);
        eye(const Offset(10, -1.7));
      case FishStyle.neon:
        // ›══•›
        glow(chevron(-15 + flap, 5), color, 2.4);
        glow(
          Path()
            ..moveTo(-11, -2.4)
            ..lineTo(12, -2.4),
          color,
          2.6,
        );
        glow(
          Path()
            ..moveTo(-11, 2.6)
            ..lineTo(9, 2.6),
          _neonRed,
          2.6,
        );
        glow(chevron(20, 3.5), color, 2.2);
        eye(const Offset(14.5, -.6), 1.8);
      case FishStyle.betta:
        // ≋≋(•› with a long, slow, flowing tail.
        final slow = time * 4 + pose.phase;
        for (var k = -1; k <= 1; k++) {
          final fin = Path()..moveTo(-4, k * 3.0);
          for (var s = 1; s <= 6; s++) {
            fin.lineTo(
              -4 - s * 5.0,
              k * (3 + s * 2.4) + math.sin(slow + s * .8) * 2.6,
            );
          }
          glow(fin, color, 2.4);
        }
        glow(
          Path()
            ..moveTo(4, -10)
            ..quadraticBezierTo(-8, 0, 4, 10),
          color,
          3.0,
        );
        glow(chevron(19, 4), color, 2.6);
        eye(const Offset(10, -1.5));
      case FishStyle.corydoras:
        // ›▰•⌟ armoured bronze body, barbels hooked down.
        glow(chevron(-14 + flap, 5.5), color, 2.4);
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -6, 24, 11),
          const Radius.circular(4),
        );
        canvas.drawRRect(body, Paint()..color = color.withValues(alpha: .35));
        glow(Path()..addRRect(body), color, 2.4);
        glow(
          Path()
            ..moveTo(14, -1)
            ..lineTo(16, 6)
            ..lineTo(11, 6),
          color,
          2.0,
        );
        eye(const Offset(7, -2), 1.9);
      case FishStyle.angelfish:
        // ›◇•› diamond body with tall trailing fins.
        glow(chevron(-15 + flap, 5), color, 2.4);
        final body = Path()
          ..moveTo(-14, 0)
          ..lineTo(1, -16)
          ..lineTo(16, 0)
          ..lineTo(1, 16)
          ..close();
        glow(body, color, 2.6);
        glow(
          Path()
            ..moveTo(1, -16)
            ..lineTo(-7, -26 + flap)
            ..moveTo(1, 16)
            ..lineTo(-7, 26 + flap),
          color,
          1.8,
        );
        paint
          ..color = const Color(0xff6f8a94)
          ..strokeWidth = 2;
        canvas.drawLine(const Offset(-5, -9), const Offset(-5, 9), paint);
        canvas.drawLine(const Offset(5, -10), const Offset(5, 10), paint);
        glow(chevron(21, 3.5), color, 2.2);
        eye(const Offset(11, -2));
      case FishStyle.platy:
        final tailX = -22.0 + flap * 2;
        glow(
          Path()
            ..moveTo(-9, 0)
            ..quadraticBezierTo(tailX - 1, -12, tailX, -6)
            ..quadraticBezierTo(tailX - 3, 0, tailX, 6)
            ..quadraticBezierTo(tailX - 1, 12, -9, 0),
          color,
          2.6,
        );
        final body = Path()
          ..moveTo(-12, 0)
          ..quadraticBezierTo(-6, -13, 6, -9)
          ..quadraticBezierTo(14, -8, 17, 0)
          ..quadraticBezierTo(11, 12, 0, 10)
          ..quadraticBezierTo(-9, 8, -12, 0);
        canvas.drawPath(body, Paint()..color = color.withValues(alpha: .27));
        glow(body, color, 2.7);
        eye(const Offset(10, -2));
      case FishStyle.swordtail:
        final tailX = -24.0 + flap * 2;
        final tail = Path()
          ..moveTo(tailX, -7)
          ..lineTo(-13, 0)
          ..lineTo(tailX, 7);
        if (fish.sex == Sex.male) {
          final sword = ((fish.growth(motion.pond.time) - .35) / .65).clamp(
            0.0,
            1.0,
          );
          tail.lineTo(tailX - sword * 16, 7 + sword * (6 + flap));
        }
        glow(tail, color, 2.5);
        glow(
          Path()
            ..moveTo(-13, 0)
            ..quadraticBezierTo(-3, -10, 9, -6)
            ..quadraticBezierTo(16, -4, 20, 0)
            ..quadraticBezierTo(9, 9, -13, 0),
          color,
          2.5,
        );
        glow(
          Path()
            ..moveTo(-10, 0)
            ..lineTo(12, 0),
          const Color(0xffff9f72),
          1.8,
        );
        eye(const Offset(13, -2));
      case FishStyle.zebrafish:
        glow(chevron(-17 + flap * 2, 5), color, 2.2);
        final stripes = Path();
        for (final y in [-4.5, 0.0, 4.5]) {
          stripes
            ..moveTo(-13, y * .72)
            ..quadraticBezierTo(-1, y * 1.15, y == 0 ? 17 : 10, y * .6);
        }
        glow(stripes, color, 2.0);
        glow(chevron(20, 3.3), color, 1.9);
        eye(const Offset(12, -2), 1.75);
      case FishStyle.honeyGourami:
        final sway = math.sin(time * 4 + pose.phase);
        glow(chevron(-16 + sway * 2, 5.5), color, 2.3);
        final body = Path()
          ..moveTo(-15, 0)
          ..quadraticBezierTo(-1, -16, 13, -8)
          ..quadraticBezierTo(17, -5, 20, -1)
          ..quadraticBezierTo(10, 13, -6, 7)
          ..quadraticBezierTo(-11, 4, -15, 0);
        canvas.drawPath(body, Paint()..color = color.withValues(alpha: .23));
        glow(body, color, 2.7);
        glow(
          Path()
            ..moveTo(6, 8)
            ..quadraticBezierTo(8 + sway * 5, 13, 4 + sway * 7, 23)
            ..moveTo(0, 8)
            ..quadraticBezierTo(-1 + sway * 4, 14, -5 + sway * 6, 20),
          color,
          1.6,
        );
        eye(const Offset(12, -3));
      case FishStyle.ram:
        glow(chevron(-16 + flap, 6), color, 2.4);
        final body = Path()
          ..moveTo(-14, 0)
          ..quadraticBezierTo(-7, -11, -2, -10)
          ..lineTo(0, -16)
          ..lineTo(4, -11)
          ..quadraticBezierTo(14, -10, 20, 0)
          ..quadraticBezierTo(12, 10, 2, 11)
          ..quadraticBezierTo(-8, 9, -14, 0);
        canvas.drawPath(body, Paint()..color = color.withValues(alpha: .27));
        glow(body, color, 2.4);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(1, -1), width: 8, height: 10),
          Paint()..color = const Color(0xff172741),
        );
        final dots = Paint()..color = const Color(0xff7cb4ff);
        for (final dot in const [
          Offset(-8, -2),
          Offset(-5, 3),
          Offset(4, -7),
          Offset(6, 4),
          Offset(12, 2),
        ]) {
          canvas.drawCircle(dot, 1.5, dots);
        }
        eye(const Offset(12, -4));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AquariumPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
