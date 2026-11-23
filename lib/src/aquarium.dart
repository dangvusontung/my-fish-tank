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

/// The colour that best identifies a fish of [species] with [tail].
Color fishColor(Species species, Tail tail) => switch (species) {
  Species.guppy || Species.betta => tailColor(tail),
  Species.neon => _neonBlue,
  Species.corydoras => _bronze,
  Species.angelfish => _silver,
};

/// Where a corpse rests, as fractions of the tank size.
Offset corpseSpot(Corpse corpse) =>
    Offset(corpse.x, .8 + (corpse.id * .2914 % 1) * .04);

class Aquarium extends StatefulWidget {
  const Aquarium({
    super.key,
    required this.pond,
    required this.onFeed,
    this.onScoop,
  });

  final Pond pond;
  final VoidCallback onFeed;
  final ValueChanged<Corpse>? onScoop;

  @override
  State<Aquarium> createState() => AquariumState();
}

class AquariumState extends State<Aquarium>
    with SingleTickerProviderStateMixin {
  late final _TankMotion _motion;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _motion = _TankMotion(widget.pond);
    _ticker = createTicker(_motion.tick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.reduced = MediaQuery.disableAnimationsOf(context);
  }

  void feed([Offset target = const Offset(.51, .51)]) {
    if (widget.pond.fish.isEmpty) return;
    _motion.drop(target);
    widget.onFeed();
  }

  void _tap(Offset point, Size size) {
    final onScoop = widget.onScoop;
    if (onScoop != null) {
      for (final corpse in widget.pond.corpses.reversed) {
        final spot = corpseSpot(corpse);
        final distance =
            (Offset(spot.dx * size.width, spot.dy * size.height) - point)
                .distance;
        if (distance < 30) {
          onScoop(corpse);
          return;
        }
      }
    }
    feed(Offset(point.dx / size.width, point.dy / size.height));
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
      builder: (context, constraints) => Semantics(
        button: true,
        label: 'Rải thức ăn vào hồ',
        onTap: () => feed(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapUp: (event) => _tap(event.localPosition, constraints.biggest),
          child: SizedBox.expand(
            child: RepaintBoundary(
              child: CustomPaint(painter: _AquariumPainter(_motion)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pose {
  _Pose(this.fish, this.phase, this.x, this.y, this.yaw);
  final Fish fish;
  final double phase;
  double x;
  double y;
  double yaw;
  double pitch = 0;
}

class _TankMotion extends ChangeNotifier {
  _TankMotion(this.pond);

  final Pond pond;
  final Map<int, _Pose> poses = {};
  final List<double> snails = [];
  Duration _last = Duration.zero;
  double time = 0;
  double _nextSync = 0;
  bool reduced = false;
  Offset? target;
  double droppedAt = -10;

  void drop(Offset point) {
    target = Offset(
      point.dx.clamp(.08, .92).toDouble(),
      point.dy.clamp(.13, .87).toDouble(),
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

    final activeTarget = time - droppedAt < 2.9 ? target : null;
    final movingTime = time * (reduced ? .32 : 1);
    for (final pose in poses.values) {
      final natural = _position(pose, movingTime);
      final ahead = _position(pose, movingTime + .15);
      final phase = pose.phase;
      final bottom = pose.fish.species == Species.corydoras;
      final destination = activeTarget == null
          ? natural
          : bottom
          ? Offset(activeTarget.dx + math.sin(phase) * .06, natural.dy)
          : activeTarget +
                Offset(math.sin(phase) * .084, math.cos(phase) * .16);
      final dx = destination.dx - pose.x;
      final dy = destination.dy - pose.y;
      final attraction = activeTarget == null ? 1.85 : 2.4;
      pose.x += dx * delta * attraction;
      pose.y += dy * delta * attraction;
      final direction = activeTarget == null
          ? ((ahead.dx - natural.dx) * 60).clamp(-1, 1)
          : (dx * 10).clamp(-1, 1);
      pose.yaw += (direction - pose.yaw) * delta * 7;
      final pitch = (dy * 1.8).clamp(-.23, .23) * pose.yaw.sign;
      pose.pitch += (pitch - pose.pitch) * delta * 5;
    }

    // Snails crawl along the floor towards the nearest corpse.
    final corpses = pond.corpses;
    for (var i = 0; i < snails.length; i++) {
      final goal = corpses.isEmpty
          ? .5 + math.sin(movingTime * .05 + i * 2.1) * .42
          : corpses[i % corpses.length].x + (i.isEven ? -.025 : .025);
      final step = (goal - snails[i]).clamp(-.012 * delta, .012 * delta);
      snails[i] += step;
    }
    notifyListeners();
  }

  Offset _position(_Pose pose, double movingTime) {
    final fish = pose.fish;
    final phase = pose.phase;
    final depth = fish.id * .41421356 % 1;
    if (fish.age(pond.time) < Pond.fryDays && pond.sheltered > 0) {
      final cycle = movingTime * .44 + phase;
      return Offset(
        (fish.id.isEven ? .19 : .84) + math.sin(cycle) * .07,
        .72 + depth * .13 + math.cos(cycle) * .03,
      );
    }
    switch (fish.species) {
      case Species.neon:
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
      case Species.corydoras:
        return Offset(
          .5 + math.sin(movingTime * .18 + phase) * .38,
          .79 + depth * .05 + math.sin(movingTime * 1.7 + phase) * .006,
        );
      case Species.betta:
        final cycle = movingTime * .22 + phase;
        return Offset(
          .5 + math.sin(cycle) * .3,
          .25 + depth * .35 + math.cos(cycle * 1.1) * .03,
        );
      case Species.angelfish:
        final cycle = movingTime * .26 + phase;
        return Offset(
          .5 + math.sin(cycle) * .27,
          .35 + depth * .3 + math.cos(cycle * .9) * .04,
        );
      case Species.guppy:
        final cycle = movingTime * .44 + phase;
        return Offset(
          .5 + math.sin(cycle) * (.29 + (fish.id % 3) * .047),
          .29 + depth * .50 + math.cos(cycle * 1.07) * .031,
        );
    }
  }

  void _syncFish() {
    final ids = <int>{};
    final movingTime = time * (reduced ? .32 : 1);
    for (final fish in pond.fish) {
      ids.add(fish.id);
      poses.putIfAbsent(fish.id, () {
        final phase = fish.id * 2.39996;
        final pose = _Pose(fish, phase, .5, .5, 1);
        final point = _position(pose, movingTime);
        final ahead = _position(pose, movingTime + .15);
        return pose
          ..x = point.dx
          ..y = point.dy
          ..yaw = ((ahead.dx - point.dx) * 60).clamp(-1, 1).toDouble();
      });
    }
    poses.removeWhere((id, pose) => !ids.contains(id));
    while (snails.length < pond.snails) {
      snails.add(.1 + snails.length * .618 % .8);
    }
    if (snails.length > pond.snails) snails.length = pond.snails;
  }
}

class _AquariumPainter extends CustomPainter {
  _AquariumPainter(this.motion) : super(repaint: motion);

  final _TankMotion motion;
  static const _mint = Color(0xff8af9d6);
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
            size.height * (.18 + row * .015) +
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
      size.height * .72,
      size.width,
      size.height * .28,
    );
    canvas.drawRect(floor, paint..shader = _ground.createShader(floor));
    paint.shader = null;
    for (var i = 0; i < 52; i++) {
      final x = size.width * (i * .6137 % 1);
      final y = size.height * (.837 + (i * .79187 % 1) * .143);
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
      final y = size.height * (.88 - opacityPhase * .69);
      line
        ..color = const Color(0xffa6eff0)
            .withValues(alpha: math.sin(opacityPhase * math.pi) * .27)
        ..strokeWidth = .85;
      canvas.drawCircle(Offset(x, y), 1 + i % 4 * .77, line);
    }

    _drawPlants(canvas, size, line, time);
    _drawClutches(canvas, size, paint, line, time);
    _drawCorpses(canvas, size, line, time);
    _drawSnails(canvas, size, line);
    const detailedFish = 24;
    final density = math.max(1, motion.poses.length / detailedFish);
    final spriteScale =
        (size.shortestSide / 420).clamp(.77, 1.24) *
        (1 / math.sqrt(density)).clamp(.42, 1);
    var index = 0;
    for (final pose in motion.poses.values) {
      final detailed =
          index < detailedFish || motion.pond.breeders.contains(pose.fish.id);
      _drawFish(
        canvas,
        size,
        pose,
        spriteScale,
        time,
        line,
        detailed: detailed,
      );
      index++;
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

  void _drawPlants(Canvas canvas, Size size, Paint paint, double time) {
    final count = math.min(8, 2 + motion.pond.levels[Equipment.javaMoss]! * 2);
    for (var i = 0; i < count * 2; i++) {
      final x = size.width * ((i.isEven ? .14 : .86) + (i % 3 - 1) * .039);
      final y = size.height * .93;
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
      final (anchor, spread, color) = switch (clutch.species) {
        Species.betta => (
          Offset(.3 + seed * .4, .195),
          const Offset(.05, .008),
          const Color(0xccf3f7ff),
        ),
        Species.corydoras => (
          Offset(clutch.id.isEven ? .15 : .85, .76 + seed * .05),
          const Offset(.025, .03),
          const Color(0xddf1e3c0),
        ),
        Species.angelfish => (
          Offset(.25 + seed * .5, .84),
          const Offset(.03, .012),
          const Color(0xddffd59a),
        ),
        _ => (
          Offset(.15 + seed * .7, .86),
          const Offset(.12, .02),
          const Color(0x99d9f6ff),
        ),
      };
      for (var i = 0; i < dots; i++) {
        final offset = Offset(
          math.sin(i * 2.4 + clutch.id) * spread.dx,
          math.cos(i * 1.7 + clutch.id) * spread.dy,
        );
        final center = Offset(
          (anchor.dx + offset.dx) * size.width,
          (anchor.dy + offset.dy) * size.height,
        );
        if (clutch.species == Species.betta) {
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
    for (final corpse in motion.pond.corpses) {
      final spot = corpseSpot(corpse);
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
        size.height * (.855 + i % 3 * .012),
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
  }) {
    final fish = pose.fish;
    final growth = fish.growth(motion.pond.time);
    scale *=
        (.26 + growth * .70) *
        switch (fish.species) {
          Species.neon => .75,
          Species.corydoras => .85,
          Species.angelfish => 1.15,
          _ => 1.0,
        };
    canvas.save();
    canvas.translate(pose.x * size.width, pose.y * size.height);
    canvas.rotate(pose.pitch);
    final facing = pose.yaw < 0 ? -1 : 1;
    canvas.scale(scale * facing * math.max(.13, pose.yaw.abs()), scale);
    final color = fishColor(fish.species, fish.tail);
    if (!detailed) {
      final flap = math.sin(time * 21 + pose.phase) * 2;
      paint
        ..color = color
        ..strokeWidth = 3.5;
      const tip = Offset(-9, 0);
      canvas.drawLine(Offset(-22, -9 + flap), tip, paint);
      canvas.drawLine(Offset(-22, 9 + flap), tip, paint);
      paint.color = fish.species == Species.guppy ? _mint : color;
      canvas.drawLine(const Offset(-3, 0), const Offset(17, 0), paint);
      canvas.restore();
      return;
    }
    void glow(Path path, Color color, double width) {
      paint
        ..strokeWidth = width + 1
        ..color = color.withValues(alpha: .57)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.8);
      canvas.drawPath(path, paint);
      paint
        ..strokeWidth = width
        ..color = color
        ..maskFilter = null;
      canvas.drawPath(path, paint);
    }

    Path chevron(double x, double half) => Path()
      ..moveTo(x - half, -half)
      ..lineTo(x, 0)
      ..lineTo(x - half, half);

    void eye(Offset at, [double radius = 2.25]) =>
        canvas.drawCircle(at, radius, Paint()..color = const Color(0xffeafff5));

    final flap = math.sin(time * 21 + pose.phase);
    switch (fish.species) {
      case Species.guppy:
        final spread = fish.sex == Sex.male ? 10 + fish.vividness * .042 : 10.0;
        for (final offset in fish.sex == Sex.male ? [0, 7] : [4]) {
          final tip = -20.0 + offset + flap * 2;
          final path = Path()
            ..moveTo(tip - 8 - flap * 2, -spread + flap)
            ..lineTo(tip, 0)
            ..lineTo(tip - 8 - flap * 2, spread + flap);
          glow(path, color, 3.0);
        }
        for (final x in [-7.0, 2.0]) {
          final arc = Path()
            ..moveTo(x, -11)
            ..quadraticBezierTo(x - 12, 0, x, 11);
          glow(arc, _mint, 3.15);
        }
        glow(chevron(21, 4.5), _mint, 2.7);
        eye(const Offset(10, -1.7));
      case Species.neon:
        // ›══•›
        glow(chevron(-15 + flap, 5), _neonBlue, 2.4);
        glow(
          Path()
            ..moveTo(-11, -2.4)
            ..lineTo(12, -2.4),
          _neonBlue,
          2.6,
        );
        glow(
          Path()
            ..moveTo(-11, 2.6)
            ..lineTo(9, 2.6),
          _neonRed,
          2.6,
        );
        glow(chevron(20, 3.5), _neonBlue, 2.2);
        eye(const Offset(14.5, -.6), 1.8);
      case Species.betta:
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
      case Species.corydoras:
        // ›▰•⌟ armoured bronze body, barbels hooked down.
        glow(chevron(-14 + flap, 5.5), _bronze, 2.4);
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -6, 24, 11),
          const Radius.circular(4),
        );
        canvas.drawRRect(body, Paint()..color = _bronze.withValues(alpha: .35));
        glow(Path()..addRRect(body), _bronze, 2.4);
        glow(
          Path()
            ..moveTo(14, -1)
            ..lineTo(16, 6)
            ..lineTo(11, 6),
          _bronze,
          2.0,
        );
        eye(const Offset(7, -2), 1.9);
      case Species.angelfish:
        // ›◇•› tall diamond body with trailing fins.
        glow(chevron(-12 + flap, 5), _silver, 2.4);
        final body = Path()
          ..moveTo(-10, 0)
          ..lineTo(2, -17)
          ..lineTo(14, 0)
          ..lineTo(2, 17)
          ..close();
        glow(body, _silver, 2.6);
        glow(
          Path()
            ..moveTo(2, -17)
            ..lineTo(-5, -27 + flap)
            ..moveTo(2, 17)
            ..lineTo(-5, 27 + flap),
          _silver,
          1.8,
        );
        paint
          ..color = const Color(0xff6f8a94)
          ..strokeWidth = 2;
        canvas.drawLine(const Offset(-2, -11), const Offset(-2, 11), paint);
        canvas.drawLine(const Offset(6, -9), const Offset(6, 9), paint);
        glow(chevron(18, 3.5), _silver, 2.2);
        eye(const Offset(9, -2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AquariumPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
