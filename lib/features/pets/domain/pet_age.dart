/// Age in Portuguese, from a birth day: "5 anos", "1 ano", "8 meses",
/// "Menos de 1 mês". Estimated ages read "Cerca de 3 anos".
String describeAge(
  DateTime birthDate,
  DateTime today, {
  bool estimated = false,
}) {
  var months =
      (today.year - birthDate.year) * 12 + today.month - birthDate.month;
  if (today.day < birthDate.day) months -= 1;
  if (months < 0) months = 0;

  final years = months ~/ 12;
  final String text;
  if (years >= 1) {
    text = years == 1 ? '1 ano' : '$years anos';
  } else if (months >= 1) {
    text = months == 1 ? '1 mês' : '$months meses';
  } else {
    return 'Menos de 1 mês';
  }
  return estimated ? 'Cerca de $text' : text;
}

/// Birth day for someone who only knows the age in years: same day and month
/// as today, that many years back.
DateTime estimatedBirthDate(int years, DateTime today) {
  final year = today.year - years;
  // 29 February does not exist in most years.
  final day = today.month == 2 && today.day == 29 ? 28 : today.day;
  return DateTime(year, today.month, day);
}

/// Whole years between a birth day and today.
int ageInYears(DateTime birthDate, DateTime today) {
  var years = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    years -= 1;
  }
  return years < 0 ? 0 : years;
}

/// The next birthday on or after [today]. 29 February falls on the 28th in
/// years without it.
DateTime nextBirthday(DateTime birthDate, DateTime today) {
  DateTime inYear(int year) {
    final lastDay = DateTime(year, birthDate.month + 1, 0).day;
    final day = birthDate.day > lastDay ? lastDay : birthDate.day;
    return DateTime(year, birthDate.month, day);
  }

  final day = DateTime(today.year, today.month, today.day);
  final thisYear = inYear(today.year);
  return thisYear.isBefore(day) ? inYear(today.year + 1) : thisYear;
}
