import 'package:flutter/widgets.dart';

// FB-style high velocity, low-friction momentum scroll physics.
// Enables fast, buttery smooth fling scrolling in both directions while maintaining
// pre-rendered cache extent ahead of the viewport.
class FeedMomentumScrollPhysics extends ClampingScrollPhysics {
  const FeedMomentumScrollPhysics({
    super.parent,
    this.downwardMaxBallisticVelocity = 12000,
    this.upwardMaxBallisticVelocity = 12000,
    this.downwardFriction = 0.012,
    this.upwardFriction = 0.010,
    this.downwardMomentumFactor = 0.85,
    this.upwardMomentumFactor = 0.90,
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
