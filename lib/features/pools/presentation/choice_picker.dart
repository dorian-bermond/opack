import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../catalog/domain/models.dart';
import 'card_field_icons.dart';

/// The answer of [pickChoice] when the user wants a value of their own.
const customChoice = '\u0000custom';

/// Lets the user pick one of [options] for the field [fieldKey]: the whole
/// list, with a search box over it that narrows it as one types, the
/// [current] value marked, "Custom…" last. [iconValue] is the value an
/// option's icon is looked up by (the English word behind a French one).
/// Answers the option picked, [customChoice] for one of the user's own,
/// `null` when nothing is picked.
Future<String?> pickChoice(
  BuildContext context, {
  required String title,
  required Game game,
  required String fieldKey,
  required List<String> options,
  required String current,
  String Function(String option)? iconValue,
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _ChoicePicker(
        title: title,
        game: game,
        fieldKey: fieldKey,
        options: options,
        current: current,
        iconValue: iconValue ?? (option) => option,
      ),
    );

class _ChoicePicker extends StatefulWidget {
  const _ChoicePicker({
    required this.title,
    required this.game,
    required this.fieldKey,
    required this.options,
    required this.current,
    required this.iconValue,
  });

  final String title;
  final Game game;
  final String fieldKey;
  final List<String> options;
  final String current;
  final String Function(String option) iconValue;

  @override
  State<_ChoicePicker> createState() => _ChoicePickerState();
}

class _ChoicePickerState extends State<_ChoicePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final option in widget.options)
        if (option.toLowerCase().contains(query)) option,
    ];
    return AlertDialog(
      key: ValueKey('choicePicker-${widget.fieldKey}'),
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('choiceSearch'),
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchChoice,
                border: const OutlineInputBorder(),
              ),
              onChanged: (text) => setState(() => _query = text),
              // Enter takes the only option left, or the first.
              onSubmitted: (_) => shown.isEmpty ? null : Navigator.pop(context, shown.first),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final option in shown)
                    ListTile(
                      key: ValueKey('choice-${widget.fieldKey}-$option'),
                      dense: true,
                      selected: option == widget.current,
                      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      leading: ValueIcon(widget.game, widget.fieldKey, widget.iconValue(option), size: 22),
                      title: Text(option),
                      trailing: option == widget.current ? const Icon(Icons.check, size: 18) : null,
                      onTap: () => Navigator.pop(context, option),
                    ),
                  ListTile(
                    key: ValueKey('customOption-${widget.fieldKey}'),
                    dense: true,
                    leading: const Icon(Icons.add, size: 18),
                    title: Text(l10n.customOption),
                    onTap: () => Navigator.pop(context, customChoice),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel))],
    );
  }
}
