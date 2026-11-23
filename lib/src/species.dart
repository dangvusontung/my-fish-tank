enum Brood { live, eggs }

/// Per-species tuning. Day values are in-game days ([Pond.daySeconds] each);
/// ranges are `(min, max)` with max exclusive.
enum Species {
  guppy(
    label: 'Bảy màu',
    latin: 'Poecilia reticulata',
    glyph: '⟫((•›',
    brood: Brood.live,
    adultDays: (54, 69),
    lifeDays: (395, 545),
    clutch: (20, 41),
    spawnEvery: (25, 36),
    incubation: 0,
    hatchRate: 1,
    basePrice: 20,
    vividDivisor: 3,
    adultIncome: 3.3,
    youngIncome: .7,
    load: 1,
    predation: 1,
    pairCost: 90,
    habit:
        'Đẻ con trực tiếp 20–40 con mỗi lứa. Cá lớn ăn cả cá mới đẻ, '
        'rêu Java cho cá con chỗ trốn.',
  ),
  neon(
    label: 'Cá neon',
    latin: 'Paracheirodon innesi',
    glyph: '›══•›',
    brood: Brood.eggs,
    adultDays: (70, 85),
    lifeDays: (600, 900),
    clutch: (100, 201),
    spawnEvery: (20, 30),
    incubation: 1,
    hatchRate: .45,
    fryLoss: .12,
    basePrice: 14,
    vividDivisor: 6,
    adultIncome: 1.6,
    youngIncome: .3,
    load: .5,
    predation: .3,
    pairCost: 140,
    schoolSize: 6,
    spawnWater: 70,
    habit:
        'Đẻ 100–200 trứng mỗi đợt, chỉ đẻ khi nước từ 70% trở lên. '
        'Trứng nhạy sáng nên tỷ lệ nở thấp. Đủ đàn 6 con thì ít stress '
        'và kiếm xu nhiều hơn.',
  ),
  betta(
    label: 'Betta',
    latin: 'Betta splendens',
    glyph: '≋≋(•›',
    brood: Brood.eggs,
    adultDays: (90, 110),
    lifeDays: (700, 900),
    clutch: (12, 493),
    spawnEvery: (30, 40),
    incubation: 2,
    hatchRate: .75,
    fryLoss: .25,
    basePrice: 60,
    vividDivisor: 2,
    adultIncome: 6,
    youngIncome: .8,
    load: 1.2,
    predation: 1,
    pairCost: 260,
    habit:
        'Trống nhặt trứng vào tổ bọt và canh tổ nên trứng nở tốt. '
        'Betta trống có tính lãnh thổ: hơn một con trống trưởng thành '
        'trong hồ thì chúng đánh nhau, con thừa không kiếm xu và có thể chết.',
  ),
  corydoras(
    label: 'Cá chuột',
    latin: 'Corydoras aeneus',
    glyph: '›▰•⌟',
    brood: Brood.eggs,
    adultDays: (100, 130),
    lifeDays: (1200, 1800),
    clutch: (100, 201),
    spawnEvery: (25, 35),
    incubation: 4,
    hatchRate: .5,
    fryLoss: .15,
    basePrice: 30,
    vividDivisor: 4,
    adultIncome: 2.4,
    youngIncome: .4,
    load: 1,
    predation: 0,
    pairCost: 200,
    habit:
        'Rà đáy, hiền, không ăn cá con. Cá mái dán từng cụm trứng lên cây: '
        'rêu Java càng dày thì trứng nở càng nhiều. Ăn mồi thừa nên rải '
        'dư ít làm bẩn nước hơn.',
  ),
  angelfish(
    label: 'Thần tiên',
    latin: 'Pterophyllum scalare',
    glyph: '›◇•›',
    brood: Brood.eggs,
    adultDays: (150, 180),
    lifeDays: (2500, 3600),
    clutch: (234, 1083),
    spawnEvery: (35, 45),
    incubation: 3,
    hatchRate: .7,
    fryLoss: .25,
    basePrice: 80,
    vividDivisor: 2,
    adultIncome: 10,
    youngIncome: 1.2,
    load: 2.5,
    predation: 2,
    pairCost: 520,
    habit:
        'Cặp bố mẹ dọn lá hoặc đá để đẻ 234–1.082 trứng rồi canh trứng. '
        'Cặp non thường ăn lứa đầu. Cá lớn săn cá con rất mạnh và làm '
        'bẩn nước nhiều.',
  ),
  platy(
    label: 'Mún đỏ',
    latin: 'Xiphophorus maculatus',
    glyph: '‹⬭•›',
    brood: Brood.live,
    adultDays: (60, 91),
    lifeDays: (730, 1096),
    clutch: (20, 81),
    spawnEvery: (28, 43),
    incubation: 0,
    hatchRate: 1,
    basePrice: 18,
    vividDivisor: 4,
    adultIncome: 2.8,
    youngIncome: .55,
    load: .85,
    predation: .55,
    pairCost: 105,
    habit:
        'Thân ngắn, tròn, màu đỏ cam. Đẻ con trực tiếp và hay bơi '
        'quanh bụi cây ở tầng giữa.',
  ),
  swordtail(
    label: 'Đuôi kiếm',
    latin: 'Xiphophorus hellerii',
    glyph: '⟋─╾•›',
    brood: Brood.live,
    adultDays: (84, 113),
    lifeDays: (1095, 1461),
    clutch: (20, 101),
    spawnEvery: (28, 36),
    incubation: 0,
    hatchRate: 1,
    basePrice: 34,
    vividDivisor: 3,
    adultIncome: 4.6,
    youngIncome: .65,
    load: 1.35,
    predation: .9,
    pairCost: 220,
    habit:
        'Bơi khoẻ ở khoảng trống, đẻ con trực tiếp. Cá trống lên '
        'kiếm ở mép dưới vây đuôi khi lớn.',
  ),
  zebrafish(
    label: 'Sọc ngựa',
    latin: 'Danio rerio',
    glyph: '‹≡•›',
    brood: Brood.eggs,
    adultDays: (75, 106),
    lifeDays: (730, 1461),
    clutch: (100, 201),
    spawnEvery: (14, 22),
    incubation: 3,
    hatchRate: .45,
    fryLoss: .14,
    basePrice: 16,
    vividDivisor: 5,
    adultIncome: 1.9,
    youngIncome: .25,
    load: .55,
    predation: .4,
    pairCost: 170,
    schoolSize: 6,
    habit:
        'Sọc dọc thân, bơi nhanh thành đàn ở tầng trên và rải '
        'trứng xuống đáy. Đủ đàn 6 con thì kiếm xu nhiều hơn.',
  ),
  honeyGourami(
    label: 'Sặc mật ong',
    latin: 'Trichogaster chuna',
    glyph: '‹◖•⌄',
    brood: Brood.eggs,
    adultDays: (100, 141),
    lifeDays: (1095, 1826),
    clutch: (100, 301),
    spawnEvery: (26, 39),
    incubation: 2,
    hatchRate: .62,
    fryLoss: .2,
    basePrice: 47,
    vividDivisor: 3,
    adultIncome: 4.8,
    youngIncome: .65,
    load: .9,
    predation: .5,
    pairCost: 305,
    habit:
        'Lướt chậm gần mặt nước, có hai vây bụng dài như râu. '
        'Cá trống gom trứng vào tổ bọt và canh tới lúc nở.',
  ),
  ram(
    label: 'Phượng hoàng',
    latin: 'Mikrogeophagus ramirezi',
    glyph: '‹✧◉›',
    brood: Brood.eggs,
    adultDays: (115, 161),
    lifeDays: (730, 1096),
    clutch: (100, 301),
    spawnEvery: (26, 39),
    incubation: 3,
    hatchRate: .58,
    fryLoss: .24,
    basePrice: 62,
    vividDivisor: 2,
    adultIncome: 7.4,
    youngIncome: .9,
    load: 1.25,
    predation: .7,
    pairCost: 410,
    spawnWater: 80,
    habit:
        'Rà tầng thấp, thân lấp lánh chấm lam. Cặp bố mẹ đẻ trên '
        'đá phẳng và canh trứng. Trong game cần nước từ 80% để đẻ.',
  );

  const Species({
    required this.label,
    required this.latin,
    required this.glyph,
    required this.brood,
    required this.adultDays,
    required this.lifeDays,
    required this.clutch,
    required this.spawnEvery,
    required this.incubation,
    required this.hatchRate,
    this.fryLoss = 0,
    required this.basePrice,
    required this.vividDivisor,
    required this.adultIncome,
    required this.youngIncome,
    required this.load,
    required this.predation,
    required this.pairCost,
    required this.habit,
    this.schoolSize = 0,
    this.spawnWater = 50,
  });

  final String label;
  final String latin;
  final String glyph;
  final Brood brood;
  final (int, int) adultDays;
  final (int, int) lifeDays;
  final (int, int) clutch;
  final (int, int) spawnEvery;

  /// Days from laying to hatching (egg layers only).
  final int incubation;
  final double hatchRate;

  /// Daily chance that a hatched fry dies in good conditions.
  final double fryLoss;
  final int basePrice;
  final int vividDivisor;
  final double adultIncome;
  final double youngIncome;

  /// Feed and waste load relative to a guppy.
  final double load;

  /// How hard an adult hunts fry. Zero means peaceful.
  final double predation;
  final int pairCost;
  final String habit;
  final int schoolSize;
  final int spawnWater;
}
