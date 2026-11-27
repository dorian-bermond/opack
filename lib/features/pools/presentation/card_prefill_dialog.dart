import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/text_diff.dart';

/// Another printing of the card being edited: how it is named to the
/// user and what its fields read, by key, as the editor shows them.
typedef CardVersion = ({String id, String label, Map<String, String> fields});

/// Asks which fields to take from one of [versions]: the user picks the
/// version, then the fields, each shown as the change it makes to what
/// the field reads now ([current]), the parts taken out barred in red,
/// the parts brought in green. Only [field] is offered when given; a field
/// a version reads the same as now cannot be picked. Answers the values
/// to set by key, `null` when nothing is taken.
Future<Map<String, String>?> showPrefillDialog(
  BuildContext context, {
  required List<CardVersion> versions,
  required Map<String, String> current,
  required List<String> keys,
  required String Function(String key) label,
  String? field,
}) => showDialog<Map<String, String>>(
  context: context,
  builder: (context) =>
      _PrefillDialog(versions: versions, current: current, keys: field == null ? keys : [field], label: label),
);

class _PrefillDialog extends StatefulWidget {
  const _PrefillDialog({required this.versions, required this.current, required this.keys, required this.label});

  final List<CardVersion> versions;
  final Map<String, String> current;
  final List<String> keys;
  final String Function(String key) label;

  @override
  State<_PrefillDialog> createState() => _PrefillDialogState();
}

class _PrefillDialogState extends State<_PrefillDialog> {
  late CardVersion _version = widget.versions.first;
  late Set<String> _picked = _changed.toSet();

  /// The fields [_version] reads otherwise than now.
  List<String> get _changed => [
    for (final key in widget.keys)
      if ((_version.fields[key] ?? '') != (widget.current[key] ?? '')) key,
  ];

  void _pickVersion(CardVersion version) => setState(() {
    _version = version;
    _picked = _changed.toSet();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final changed = _changed;
    return AlertDialog(
      key: const Key('prefillDialog'),
      title: Text(l10n.prefillTitle),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The version the values come from.
            if (widget.versions.length > 1) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final version in widget.versions)
                    ChoiceChip(
                      key: ValueKey('prefillVersion-${version.id}'),
                      label: Text(version.label),
                      selected: version == _version,
                      onSelected: (_) => _pickVersion(version),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_version.label, style: theme.textTheme.titleSmall),
              ),
            if (changed.isEmpty)
              Text(l10n.prefillNoChange, style: theme.textTheme.bodyMedium)
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final key in widget.keys)
                      CheckboxListTile(
                        key: ValueKey('prefillField-$key'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        enabled: changed.contains(key),
                        value: _picked.contains(key),
                        title: Text(widget.label(key)),
                        subtitle: changed.contains(key)
                            ? _DiffText(from: widget.current[key] ?? '', to: _version.fields[key] ?? '')
                            : Text(l10n.prefillSame, style: theme.textTheme.bodySmall),
                        onChanged: (on) => setState(() => on! ? _picked.add(key) : _picked.remove(key)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('applyPrefill'),
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, {for (final key in _picked) key: _version.fields[key] ?? ''}),
          child: Text(l10n.apply),
        ),
      ],
    );
  }
}

/// A change as git shows it: what goes barred in red, what comes in green.
class _DiffText extends StatelessWidget {
  const _DiffText({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium!;
    if (from.isEmpty || to.isEmpty) {
      // Nothing to compare word by word: all of one, all of the other.
      return Text.rich(
        TextSpan(
          children: [
            if (from.isEmpty)
              TextSpan(
                text: l10n.fieldEmpty,
                style: base.copyWith(color: theme.colorScheme.outline),
              ),
            if (from.isNotEmpty) TextSpan(text: from, style: _removed(base)),
            const TextSpan(text: '  '),
            if (to.isEmpty)
              TextSpan(
                text: l10n.fieldEmpty,
                style: base.copyWith(color: theme.colorScheme.outline),
              ),
            if (to.isNotEmpty) TextSpan(text: to, style: _added(base)),
          ],
        ),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          for (final part in wordDiff(from, to))
            TextSpan(
              text: part.text,
              style: switch (part.kind) {
                DiffKind.same => base,
                DiffKind.removed => _removed(base),
                DiffKind.added => _added(base),
              },
            ),
        ],
      ),
    );
  }

  static TextStyle _removed(TextStyle base) => base.copyWith(
    color: const Color(0xFFC62828),
    decoration: TextDecoration.lineThrough,
    decorationColor: const Color(0xFFC62828),
    backgroundColor: const Color(0x22C62828),
  );

  static TextStyle _added(TextStyle base) =>
      base.copyWith(color: const Color(0xFF2E7D32), backgroundColor: const Color(0x222E7D32));
}
