import 'madrid_date.dart';

class LiturgicalCelebration {
  final DateTime date;
  final String name;
  final String season;
  final String? color;

  const LiturgicalCelebration({
    required this.date,
    required this.name,
    required this.season,
    this.color,
  });
}

/// Calcula una selección del calendario romano general sin depender de red.
///
/// Aplica los traslados españoles de Ascensión y Corpus al domingo.
///
/// No modela los calendarios propios diocesanos ni otros traslados.
class LiturgicalCalendar {
  static List<LiturgicalCelebration> forYear(int year) {
    final easter = _easter(year);
    final celebrations = <LiturgicalCelebration>[
      _fixed(year, 1, 1, 'Santa María, Madre de Dios', 'Navidad', 'Blanco'),
      _fixed(year, 1, 6, 'Epifanía del Señor', 'Navidad', 'Blanco'),
      _fixed(year, 8, 15, 'Asunción de la Virgen María', 'Tiempo ordinario',
          'Blanco'),
      _fixed(year, 11, 1, 'Todos los Santos', 'Tiempo ordinario', 'Blanco'),
      _fixed(year, 12, 8, 'Inmaculada Concepción', 'Adviento', 'Blanco'),
      _fixed(year, 12, 25, 'Natividad del Señor', 'Navidad', 'Blanco'),
      _fixed(year, 12, 27, 'San Juan Evangelista', 'Navidad', 'Blanco'),
      LiturgicalCelebration(
        date: _sagradaFamilia(year),
        name: 'Sagrada Familia',
        season: 'Navidad',
        color: 'Blanco',
      ),
      _mobile(easter, -46, 'Miércoles de Ceniza', 'Cuaresma', 'Morado'),
      _mobile(easter, -7, 'Domingo de Ramos', 'Semana Santa', 'Rojo'),
      _mobile(easter, -3, 'Jueves Santo', 'Triduo Pascual', 'Blanco'),
      _mobile(easter, -2, 'Viernes Santo', 'Triduo Pascual', 'Rojo'),
      _mobile(easter, -1, 'Vigilia Pascual', 'Triduo Pascual', 'Blanco'),
      _mobile(easter, 0, 'Domingo de Pascua', 'Pascua', 'Blanco'),
      _mobile(easter, 42, 'Ascensión del Señor', 'Pascua', 'Blanco'),
      _mobile(easter, 49, 'Pentecostés', 'Pascua', 'Rojo'),
      _mobile(easter, 56, 'Santísima Trinidad', 'Tiempo ordinario', 'Blanco'),
      _mobile(easter, 63, 'Corpus Christi', 'Tiempo ordinario', 'Blanco'),
      _mobile(
          easter, 68, 'Sagrado Corazón de Jesús', 'Tiempo ordinario', 'Blanco'),
      ..._advent(year),
    ];
    celebrations.sort((a, b) => a.date.compareTo(b.date));
    return celebrations;
  }

  static List<LiturgicalCelebration> next({
    DateTime? from,
    int limit = 6,
  }) {
    final start = _dateOnly(from ?? MadridDate.now());
    final candidates = <LiturgicalCelebration>[
      ...forYear(start.year),
      ...forYear(start.year + 1),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return candidates
        .where((celebration) => !celebration.date.isBefore(start))
        .take(limit)
        .toList(growable: false);
  }

  static LiturgicalCelebration _fixed(
    int year,
    int month,
    int day,
    String name,
    String season,
    String color,
  ) =>
      LiturgicalCelebration(
        date: DateTime(year, month, day),
        name: name,
        season: season,
        color: color,
      );

  static LiturgicalCelebration _mobile(
    DateTime easter,
    int offset,
    String name,
    String season,
    String color,
  ) =>
      LiturgicalCelebration(
        date: easter.add(Duration(days: offset)),
        name: name,
        season: season,
        color: color,
      );

  static List<LiturgicalCelebration> _advent(int year) {
    final christmas = DateTime(year, 12, 25);
    final fourth = christmas.subtract(Duration(days: christmas.weekday));
    final advent = List<LiturgicalCelebration>.generate(
      4,
      (index) => LiturgicalCelebration(
        date: fourth.subtract(Duration(days: 21 - index * 7)),
        name: 'Domingo de Adviento ${index + 1}',
        season: 'Adviento',
        color: 'Morado',
      ),
    );
    final christTheKing = fourth.subtract(const Duration(days: 28));
    advent.add(LiturgicalCelebration(
      date: christTheKing,
      name: 'Jesucristo, Rey del Universo',
      season: 'Tiempo ordinario',
      color: 'Blanco',
    ));
    return advent;
  }

  static DateTime _sagradaFamilia(int year) {
    final christmas = DateTime(year, 12, 25);
    for (var day = 26; day <= 31; day++) {
      final date = DateTime(year, 12, day);
      if (date.weekday == DateTime.sunday) return date;
    }
    return christmas.add(const Duration(days: 5));
  }

  // Algoritmo de Meeus para el domingo de Pascua del calendario gregoriano.
  static DateTime _easter(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
