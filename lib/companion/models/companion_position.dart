import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Saved screen-relative position for the companion (0.0–1.0).
class CompanionPosition {
  const CompanionPosition({required this.x, required this.y});

  final double x;
  final double y;

  factory CompanionPosition.defaultPosition() => const CompanionPosition(
        x: AppConstants.defaultPositionX,
        y: AppConstants.defaultPositionY,
      );

  factory CompanionPosition.fromOffset(Offset offset, Size screenSize) {
    final maxX = screenSize.width - AppConstants.companionWidth;
    final maxY = screenSize.height - AppConstants.companionHeight;
    return CompanionPosition(
      x: (offset.dx / maxX).clamp(0.0, 1.0),
      y: (offset.dy / maxY).clamp(0.0, 1.0),
    );
  }

  Offset toOffset(Size screenSize) {
    final maxX = screenSize.width - AppConstants.companionWidth;
    final maxY = screenSize.height - AppConstants.companionHeight;
    return Offset(x * maxX, y * maxY);
  }

  CompanionPosition copyWith({double? x, double? y}) {
    return CompanionPosition(x: x ?? this.x, y: y ?? this.y);
  }

  Map<String, double> toJson() => {'x': x, 'y': y};

  factory CompanionPosition.fromJson(Map<String, dynamic> json) {
    return CompanionPosition(
      x: (json['x'] as num?)?.toDouble() ?? AppConstants.defaultPositionX,
      y: (json['y'] as num?)?.toDouble() ?? AppConstants.defaultPositionY,
    );
  }
}
