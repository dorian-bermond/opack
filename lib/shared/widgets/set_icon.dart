import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/catalog/data/catalog_repository.dart';
import '../../features/catalog/domain/models.dart';

/// A set's expansion symbol, tinted like an icon; the set's code in a
/// small frame when it has none (Yu-Gi-Oh! and One Piece sets, a few
/// MtG ones).
class SetIcon extends ConsumerWidget {
  const SetIcon(this.game, this.code, {super.key, this.size = 24, this.color});

  final Game game;
  final String code;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set = ref.watch(catalogRepositoryProvider).setsFor(game).where((s) => s.code == code).firstOrNull;
    return SetSymbol(set, code: code, size: size, color: color);
  }
}

/// [SetIcon] for a set already looked up (`null` when unknown).
class SetSymbol extends StatelessWidget {
  const SetSymbol(this.set, {super.key, required this.code, this.size = 24, this.color});

  final SetSummary? set;
  final String code;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    if (set?.icon case final icon?) {
      return SvgPicture.asset(
        icon,
        key: const Key('setSymbol'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      );
    }
    final label = set?.displayCode ?? code;
    return Container(
      key: const Key('setCode'),
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size / 12),
      decoration: BoxDecoration(
        border: Border.all(color: tint, width: size / 16),
        borderRadius: BorderRadius.circular(size / 5),
      ),
      child: FittedBox(
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(color: tint, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
      ),
    );
  }
}
