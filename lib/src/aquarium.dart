import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'pond.dart';

Color tailColor(Tail tail) => switch (tail) {
  Tail.amber => const Color(0xffffa164),
  Tail.violet => const Color(0xffc8a4ff),
  Tail.rose => const Color(0xffff8db3),
};

class Aquarium extends StatefulWidget {
  const Aquarium({super.key, required this.pond, required this.onFeed});

  final Pond pond;
  final VoidCallback onFeed;

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
    _motion.drop(target);
    widget.onFeed();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final water = widget.pond.water.round();
    final goodWater = water >= 65;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: 308,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                button: true,
                label: 'Rải thức ăn vào hồ',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (event) => feed(
                    Offset(
                      event.localPosition.dx / constraints.maxWidth,
                      event.localPosition.dy / constraints.maxHeight,
                    ),
                  ),
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _AquariumPainter(_motion)),
                  ),
                ),
              ),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _BubbleLabel('Hồ bảy màu', Color(0xffd9f5ea)),
                        _BubbleLabel(
                          'Nước $water%',
                          goodWater
                              ? const Color(0xffa0f8d4)
                              : const Color(0xffffbc81),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _BubbleLabel(
                      'Chạm vào mặt nước để thả mồi',
                      Color(0xffbfd8d1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleLabel extends StatelessWidget {
  const _BubbleLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xdd0a2028),
      border: Border.all(color: const Color(0xff31575a)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 9),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
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
  Duration _last = Duration.zero;
  double time = 0;
  double _nextSelection = 0;
  bool reduced = false;
  Offset? target;
  double droppedAt = -10;

  void drop(Offset point) {
    target = Offset(
      point.dx.clamp(.08, .92).toDouble(),
      point.dy.clamp(.28, .78).toDouble(),
    );
    droppedAt = time;
    notifyListeners();
  }

  void tick(Duration elapsed) {
    final delta = ((elapsed - _last).inMicroseconds / 1000000).clamp(0.0, .038);
    _last = elapsed;
    time += delta;
    if (time >= _nextSelection) {
      _selectFish();
      _nextSelection = time + .65;
    }

    var index = 0;
    final activeTarget = time - droppedAt < 2.9 ? target : null;
    for (final pose in poses.values) {
      final natural = _position(pose.fish, index);
      final movingTime = time * (reduced ? .32 : 1);
      final phase = pose.phase;
      final heading = math.cos(movingTime * .44 + phase);
      final destination = activeTarget == null
          ? natural
          : activeTarget +
                Offset(math.sin(phase) * .084, math.cos(phase) * .16);
      final dx = destination.dx - pose.x;
      final dy = destination.dy - pose.y;
      final attraction = activeTarget == null ? 1.85 : 2.4;
      pose.x += dx * delta * attraction;
      pose.y += dy * delta * attraction;
      final direction = activeTarget == null ? heading : (dx * 10).clamp(-1, 1);
      pose.yaw += (direction - pose.yaw) * delta * 7;
      final pitch = (dy * 1.8).clamp(-.23, .23) * pose.yaw.sign;
      pose.pitch += (pitch - pose.pitch) * delta * 5;
      index++;
    }
    notifyListeners();
  }

  Offset _position(Fish fish, int index) {
    final phase = fish.id * 2.39996;
    final movingTime = time * (reduced ? .32 : 1);
    final cycle = movingTime * .44 + phase;
    if (fish.age(pond.time) < 8 && pond.sheltered > 0) {
      return Offset(
        (fish.id.isEven ? .19 : .84) + math.sin(cycle) * .07,
        .78 + math.cos(cycle) * .048,
      );
    }
    return Offset(
      .5 + math.sin(cycle) * (.29 + (index % 3) * .047),
      .30 + (index % 7) * .079 + math.cos(cycle) * .031,
    );
  }

  void _selectFish() {
    const limit = 13;
    final young = pond.fish.where((fish) => !fish.isAdult(pond.time)).toList();
    final selected = <Fish>[
      ...pond.fish.where((fish) => pond.breeders.contains(fish.id)),
      ...pond.fish
          .where(
            (fish) =>
                fish.isAdult(pond.time) && !pond.breeders.contains(fish.id),
          )
          .take(limit - 2 - math.min(young.length, 4)),
      ...young.reversed.take(4),
    ];
    final ids = selected.map((fish) => fish.id).toSet();
    poses.removeWhere((id, pose) => !ids.contains(id));
    for (final (index, fish) in selected.indexed) {
      poses.putIfAbsent(fish.id, () {
        final point = _position(fish, index);
        final phase = fish.id * 2.39996;
        return _Pose(fish, phase, point.dx, point.dy, math.cos(phase));
      });
    }
  }
}

class _AquariumPainter extends CustomPainter {
  _AquariumPainter(this.motion) : super(repaint: motion);

  final _TankMotion motion;
  static const _mint = Color(0xff8af9d6);
  static const _glass = RadialGradient(
    center: Alignment(.03, -.90),
    radius: 1.12,
    colors: [Color(0xff214b55), Color(0xff122c36), Color(0xff09151e)],
    stops: [0, .53, 1],
  );
  static const _ground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00071519), Color(0xff071519)],
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
    final spriteScale = (size.width / 420).clamp(.77, 1.24);
    for (final pose in motion.poses.values) {
      _drawFish(canvas, size, pose, spriteScale, time);
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

  void _drawFish(
    Canvas canvas,
    Size size,
    _Pose pose,
    double scale,
    double time,
  ) {
    final fish = pose.fish;
    final growth = fish.growth(motion.pond.time);
    scale *= .26 + growth * .70;
    canvas.save();
    canvas.translate(pose.x * size.width, pose.y * size.height);
    canvas.rotate(pose.pitch);
    canvas.scale(scale * pose.yaw.sign * math.max(.13, pose.yaw.abs()), scale);
    final tail = tailColor(fish.tail);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
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

    final flap = math.sin(time * 21 + pose.phase);
    final spread = fish.sex == Sex.male ? 10 + fish.vividness * .042 : 10.0;
    for (final offset in fish.sex == Sex.male ? [0, 7] : [4]) {
      final tip = -20.0 + offset + flap * 2;
      final path = Path()
        ..moveTo(tip - 8 - flap * 2, -spread + flap)
        ..lineTo(tip, 0)
        ..lineTo(tip - 8 - flap * 2, spread + flap);
      glow(path, tail, 3.0);
    }
    for (final x in [-7.0, 2.0]) {
      final arc = Path()
        ..moveTo(x, -11)
        ..quadraticBezierTo(x - 12, 0, x, 11);
      glow(arc, _mint, 3.15);
    }
    final mouth = Path()
      ..moveTo(16, -4.5)
      ..lineTo(21, 0)
      ..lineTo(16, 4.5);
    glow(mouth, _mint, 2.7);
    canvas.drawCircle(
      const Offset(10, -1.7),
      2.25,
      Paint()..color = const Color(0xffeafff5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AquariumPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
