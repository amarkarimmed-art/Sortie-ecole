import 'package:equatable/equatable.dart';
import 'surveillance_item.dart';

abstract class SurveillanceState extends Equatable {
  const SurveillanceState();

  @override
  List<Object?> get props => [];
}

class SurveillanceInitial extends SurveillanceState {
  const SurveillanceInitial();
}

class SurveillanceLoading extends SurveillanceState {
  const SurveillanceLoading();
}

class SurveillanceLoaded extends SurveillanceState {
  final List<SurveillanceItem> items;
  final bool isResyncing;

  const SurveillanceLoaded({
    required this.items,
    this.isResyncing = false,
  });

  /// Groupement par classe avec tri `calledAt` ascendant (CA11).
  Map<String, List<SurveillanceItem>> get groupedByClass {
    final map = <String, List<SurveillanceItem>>{};
    for (final item in items) {
      final list = map.putIfAbsent(item.className, () => []);
      list.add(item);
    }
    // Tri chaque classe par heure d'appel croissante
    for (final entry in map.entries) {
      entry.value.sort((a, b) => a.calledAt.compareTo(b.calledAt));
    }
    return map;
  }

  SurveillanceLoaded copyWith({
    List<SurveillanceItem>? items,
    bool? isResyncing,
  }) {
    return SurveillanceLoaded(
      items: items ?? this.items,
      isResyncing: isResyncing ?? this.isResyncing,
    );
  }

  @override
  List<Object?> get props => [items, isResyncing];
}

class SurveillanceError extends SurveillanceState {
  final String message;

  const SurveillanceError(this.message);

  @override
  List<Object?> get props => [message];
}
