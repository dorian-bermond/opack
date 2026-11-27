/// How a part of a text changed from one version to the next.
enum DiffKind { same, removed, added }

typedef DiffPart = ({String text, DiffKind kind});

/// The words of [from] and [to] side by side, as git shows them: the words
/// both have, the ones only [from] has (removed) and the ones only [to]
/// has (added), in reading order. Spaces travel with the word before them,
/// so the parts join back into either text.
List<DiffPart> wordDiff(String from, String to) {
  final a = _words(from);
  final b = _words(to);
  // The longest common subsequence, by a table of lengths.
  final table = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      table[i][j] = a[i].trim() == b[j].trim()
          ? table[i + 1][j + 1] + 1
          : table[i + 1][j] > table[i][j + 1]
          ? table[i + 1][j]
          : table[i][j + 1];
    }
  }
  final parts = <DiffPart>[];
  void add(String text, DiffKind kind) {
    if (text.isEmpty) return;
    if (parts.isNotEmpty && parts.last.kind == kind) {
      parts[parts.length - 1] = (text: parts.last.text + text, kind: kind);
    } else {
      parts.add((text: text, kind: kind));
    }
  }

  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (a[i].trim() == b[j].trim()) {
      add(b[j], DiffKind.same);
      i++;
      j++;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      add(a[i], DiffKind.removed);
      i++;
    } else {
      add(b[j], DiffKind.added);
      j++;
    }
  }
  for (; i < a.length; i++) {
    add(a[i], DiffKind.removed);
  }
  for (; j < b.length; j++) {
    add(b[j], DiffKind.added);
  }
  return parts;
}

/// The words of [text], each with the spaces that follow it.
List<String> _words(String text) => [for (final m in RegExp(r'\S+\s*|\s+').allMatches(text)) m.group(0)!];
