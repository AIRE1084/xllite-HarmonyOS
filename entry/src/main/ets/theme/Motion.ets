/** Shared, typed timings. Reduced-motion preferences are applied at the call site. */
export interface MotionDurations {
  instant: number
  fast: number
  base: number
  slow: number
  verySlow: number
}
export interface MotionCurves {
  standard: Curve
  decelerate: Curve
  accelerate: Curve
  emphasized: Curve
  smooth: Curve
  sharp: Curve
  linear: Curve
}
export interface MotionSystem {
  duration: MotionDurations
  curve: MotionCurves
}
export const Motion: MotionSystem = {
  duration: { instant: 100, fast: 200, base: 320, slow: 480, verySlow: 720 },
  curve: { standard: Curve.EaseInOut, decelerate: Curve.EaseOut, accelerate: Curve.EaseIn,
    emphasized: Curve.Friction, smooth: Curve.Smooth, sharp: Curve.Sharp, linear: Curve.Linear },
}
