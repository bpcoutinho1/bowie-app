/// Lowercase without accents, for matching names people type differently.
String foldText(String value) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final out = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    final i = from.indexOf(char);
    out.write(i == -1 ? char : to[i]);
  }
  return out.toString();
}
