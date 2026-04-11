import 'package:flutter/material.dart';

/// Where the tooltip card should appear relative to the highlighted target.
enum TooltipPosition { above, below, auto }

/// A single step in a coach-marks walkthrough overlay.
class CoachMarkStep {
  /// Key attached to the target widget that will be highlighted.
  final GlobalKey targetKey;

  /// Bold heading displayed in the tooltip card.
  final String title;

  /// Body copy explaining the feature to the user.
  final String description;

  /// Controls tooltip placement. [TooltipPosition.auto] picks the side with
  /// more available space.
  final TooltipPosition position;

  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.position = TooltipPosition.auto,
  });
}
