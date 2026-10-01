import 'package:equatable/equatable.dart';

class ZmanAlertPreference extends Equatable {
  final int minutesBefore;
  final String displayName;

  const ZmanAlertPreference({
    required this.minutesBefore,
    required this.displayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'minutesBefore': minutesBefore,
      'displayName': displayName,
    };
  }

  static ZmanAlertPreference? fromJson(dynamic json, {String? fallbackName}) {
    if (json is int) {
      return ZmanAlertPreference(
        minutesBefore: json,
        displayName: fallbackName ?? '',
      );
    }
    if (json is! Map) return null;
    final minutesBefore = json['minutesBefore'];
    final displayName = json['displayName'] ?? fallbackName;
    if (minutesBefore is! int) return null;
    if (displayName is! String || displayName.isEmpty) return null;
    return ZmanAlertPreference(
      minutesBefore: minutesBefore,
      displayName: displayName,
    );
  }

  @override
  List<Object?> get props => [minutesBefore, displayName];
}
