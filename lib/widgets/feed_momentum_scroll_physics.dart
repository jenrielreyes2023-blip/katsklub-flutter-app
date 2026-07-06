import 'package:flutter/widgets.dart';

// Keep the initial fling feeling quick, but make downward flings decelerate
// sooner so the feed lands within the next few rendered cards instead of
// flying far past them. Upward flings stay looser because that content was
// already visited and is more likely to be ready in memory.
class FeedMomentumScrollPhysics extends ClampingScrollPhysics {
  const FeedMomentumScrollPhysics({
    super.parent,
    this.downwardMaxBallisticVelocity = 5200,
    this.upwardMaxBallisticVelocity = 8000,
    this.downwardFriction = 0.026,
    this.upwardFriction = 0.014,
    this.downwardMomentumFactor = 0.12,
    this.upwardMomentumFactor = 0.9,
  });

  final double downwardMaxBallisticVelocity;
  final double upwardMaxBallisticVelocity;
  final double downwardFriction;
  final double upwardFriction;
  final double downwardMomentumFactor;
  final double upwardMomentumFactor;

  @override
  FeedMomentumScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FeedMomentumScrollPhysics(
      parent: buildParent(ancestor),
      downwardMaxBallisticVelocity: downwardMaxBallisticVelocity,
      upwardMaxBallisticVelocity: upwardMaxBallisticVelocity,
      downwardFriction: downwardFriction,
      upwardFriction: upwardFriction,
      downwardMomentumFactor: downwardMomentumFactor,
      upwardMomentumFactor: upwardMomentumFactor,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);

    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    if (velocity.abs() < tolerance.velocity) {
      return null;
    }

    final isDownward = velocity > 0;
    final maxVelocity =
        isDownward ? downwardMaxBallisticVelocity : upwardMaxBallisticVelocity;
    final clampedVelocity = velocity
        .clamp(
          -upwardMaxBallisticVelocity,
          maxVelocity,
        )
        .toDouble();

    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: clampedVelocity,
      friction: isDownward ? downwardFriction : upwardFriction,
      tolerance: tolerance,
    );
  }

  @override
  double carriedMomentum(double existingVelocity) {
    final parentMomentum = super.carriedMomentum(existingVelocity);
    if (existingVelocity > 0) {
      return parentMomentum * downwardMomentumFactor;
    }
    return parentMomentum * upwardMomentumFactor;
  }
}
