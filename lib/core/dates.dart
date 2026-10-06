/// Calendar days: no time, no time zone.
DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// `yyyy-mm-dd`, the format Postgres uses for `date`.
String formatDay(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}';
}

DateTime parseDay(String value) {
  final day = DateTime.parse(value.substring(0, 10));
  return DateTime(day.year, day.month, day.day);
}

/// `dd/mm/aaaa`, as people write dates in Brazil.
String formatDayBr(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(day.day)}/${two(day.month)}/${day.year}';
}

/// Whole days from [from] to [to], ignoring the time of day.
int daysBetween(DateTime from, DateTime to) {
  return DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

/// Same day [months] later, clamped to the end of shorter months.
DateTime addMonths(DateTime day, int months) {
  final total = day.month - 1 + months;
  final year = day.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day.day > lastDay ? lastDay : day.day);
}

const monthNames = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// Sunday first, as Brazilian calendars show the week.
const weekdayNames = [
  'domingo',
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
];

/// "12 de outubro".
String formatDayLong(DateTime day) =>
    '${day.day} de ${monthNames[day.month - 1]}';

/// "Outubro de 2026".
String formatMonth(DateTime month) {
  final name = monthNames[month.month - 1];
  return '${name[0].toUpperCase()}${name.substring(1)} de ${month.year}';
}

/// "Hoje", "Amanhã", "Ontem", or "segunda-feira, 12 de outubro".
String describeDay(DateTime day, DateTime today) {
  final days = daysBetween(today, day);
  if (days == 0) return 'Hoje';
  if (days == 1) return 'Amanhã';
  if (days == -1) return 'Ontem';
  final weekday = weekdayNames[day.weekday % 7];
  final text = '$weekday, ${formatDayLong(day)}';
  return day.year == today.year ? text : '$text de ${day.year}';
}
