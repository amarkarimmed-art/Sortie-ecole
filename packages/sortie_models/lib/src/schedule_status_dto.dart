import 'package:equatable/equatable.dart';

class ScheduleStatusDto extends Equatable {
  final bool isOpen;
  final String? closesAt;
  final String? nextOpeningAt;
  final int perimeterRadius;
  final int openingMarginMinutes;
  final bool isRamadanMode;
  final bool gateConfigured;
  final double? gateLatitude;
  final double? gateLongitude;
  final String messageFr;
  final String messageAr;

  const ScheduleStatusDto({
    required this.isOpen,
    this.closesAt,
    this.nextOpeningAt,
    this.perimeterRadius = 50,
    this.openingMarginMinutes = 10,
    this.isRamadanMode = false,
    this.gateConfigured = false,
    this.gateLatitude,
    this.gateLongitude,
    this.messageFr = '',
    this.messageAr = '',
  });

  factory ScheduleStatusDto.fromJson(Map<String, dynamic> json) {
    return ScheduleStatusDto(
      isOpen: json['is_open'] as bool? ?? false,
      closesAt: json['closes_at'] as String?,
      nextOpeningAt: json['next_opening_at'] as String?,
      perimeterRadius: json['perimeter_radius'] as int? ?? 50,
      openingMarginMinutes: json['opening_margin_minutes'] as int? ?? 10,
      isRamadanMode: json['is_ramadan_mode'] as bool? ?? false,
      gateConfigured: json['gate_configured'] as bool? ?? false,
      gateLatitude: (json['gate_latitude'] as num?)?.toDouble(),
      gateLongitude: (json['gate_longitude'] as num?)?.toDouble(),
      messageFr: json['message_fr'] as String? ?? '',
      messageAr: json['message_ar'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_open': isOpen,
      if (closesAt != null) 'closes_at': closesAt,
      if (nextOpeningAt != null) 'next_opening_at': nextOpeningAt,
      'perimeter_radius': perimeterRadius,
      'opening_margin_minutes': openingMarginMinutes,
      'is_ramadan_mode': isRamadanMode,
      'gate_configured': gateConfigured,
      if (gateLatitude != null) 'gate_latitude': gateLatitude,
      if (gateLongitude != null) 'gate_longitude': gateLongitude,
      'message_fr': messageFr,
      'message_ar': messageAr,
    };
  }

  @override
  List<Object?> get props => [
        isOpen,
        closesAt,
        nextOpeningAt,
        perimeterRadius,
        openingMarginMinutes,
        isRamadanMode,
        gateConfigured,
        gateLatitude,
        gateLongitude,
        messageFr,
        messageAr,
      ];
}
