import '../../catalog/domain/models.dart';

/// Hands out packs for sealed and draft.
abstract interface class PackSource {
  List<CardData> nextPack();
}
