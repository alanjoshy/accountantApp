// Tag display + normalize (store without #, show with #).

String normalizeTagName(String raw) {
  var t = raw.trim();
  while (t.startsWith('#')) {
    t = t.substring(1).trim();
  }
  return t;
}

String formatTagLabel(String tag) {
  final t = normalizeTagName(tag);
  if (t.isEmpty) return '#';
  return '#$t';
}
