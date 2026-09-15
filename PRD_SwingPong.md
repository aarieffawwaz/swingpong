# PRD: SwingPong — Phone-as-Mirror Juggling

> Revision 4. The original 2D version (ball travels up/down a flat screen) is kept
> at `PRD_SwingPong_v1_2D.md.bak`. Revision 2 correctly made the game spatial but
> wrongly modelled the input as a tennis-style swing. Revision 3 fixed the mechanic but
> still had the classifier predicting shot power, which a threshold does better. This
> revision moves the model to the one job rules genuinely cannot do.

## 1. Overview
Keepie-uppie with a virtual ball. The phone is held **flat, screen facing up, like a
bat**, and the player bounces a ball on it. Because the screen faces up, it acts as a
**window looking upward** — you glance down at it and see the ball hovering above you,
shrinking as it rises and growing as it falls back. Drift the bat and the ball leaves
the view; an edge indicator points to where it went.

The bat stays up throughout. There is no shoulder swing and no full-arm stroke — every
input is a short upward pop from the wrist and forearm.

Two distinct real-world inputs, doing two different jobs:

| Input | Source | Job |
|---|---|---|
| **How the bat is tilted** | `deviceMotion.gravity` | Which direction the ball launches |
| **How hard you pop the bat** | Peak `\|userAcceleration\|` | How high the ball goes |
| **Was that even a hit?** | Core ML classifier over CoreMotion | Whether the contact counts at all |

**Learning goals demonstrated:**
- Training a motion classification model in Create ML
- Integrating a trained model via Core ML for real-time inference
- Applying Gestalt principles (continuity, common fate) to make the ball read as one continuous object moving through space, even when it leaves the screen

## 2. Problem / Challenge Statement
Learn to train and integrate a motion classification model, and use Gestalt principles
to make an off-screen, spatially-located object feel present and trackable.

## 3. Core Mechanic

1. Ball sits above the bat at a 3D position: **azimuth** (left/right), **elevation**
   (how far off the bat's axis), and **height** (how far up).
2. The phone's attitude defines a **view frustum** — the cone the upward-facing "mirror" sees.
3. Inside the frustum the ball is **drawn on screen**, scaled by height: high = small, near = large.
4. Outside it, an edge indicator points toward the ball (§5.3) and the player tilts the
   bat to bring it back into view.
5. The ball falls under gravity. Height shrinks, ball grows.
6. On contact the player **pops the bat upward**. CoreMotion captures the 0.5 s window
   around the acceleration peak.
7. Core ML classifies the window as `bounce` / `adjust` / `idle`. Anything but `bounce`
   is discarded — no hit, no score, ball keeps falling.
8. For a real bounce: peak magnitude sets the launch speed, the bat's tilt sets the
   direction (§5.4). Both continuous, both plain physics.
9. Repeat. A rally is how long you keep it up.

## 4. Spatial Model — and its one hard constraint

**Depth is simulated, not measured.** The ball's distance is game state. The player does
not walk toward or away from it.

This is not a shortcut, it is a requirement. CoreMotion provides **3DoF rotation only**.
Deriving real position would mean double-integrating `userAcceleration`, which accumulates
unbounded drift within roughly a second — it does not work, at any tuning. True 6DoF
position requires ARKit world tracking (camera on, lit textured room, recoverable tracking loss).

Rotational aiming with simulated depth preserves the entire mirror illusion at zero cost:
works in the dark, no camera permission, no ARKit, nothing to lose tracking.

**Coordinate handling:**
- Elevation and roll are **gravity-referenced** and therefore absolute and reliable.
- Yaw is **arbitrary** under `.xArbitraryZVertical` — the phone does not know which way
  is north unless the magnetometer is used. So azimuth must be **relative to a zeroed
  origin captured at game start** ("hold the phone facing forward and tap Start"), not
  to any world direction. Expect slow yaw drift over minutes; offer a re-center gesture.

## 5. Functional Requirements

### 5.1 Motion Classification (Create ML + Core ML)

**What the model is for, and why a rule is not enough.**

Ball height and direction are *not* the model's job. Height is peak `|userAcceleration|`
mapped continuously to launch velocity; direction is the bat's tilt read off the `gravity`
vector and reflected about the bat normal. Both are exact, continuous, and need no training
data. Putting a classifier on either would bucket a continuous quantity — strictly worse.

The problem rules genuinely cannot solve is **deciding whether a triggered window was a real
bounce at all.** The contact trigger is a magnitude threshold, and over a minutes-long rally
these all cross it: grip adjustments, hand drift, taking a step, lunging to recover, setting
the phone down. Raising the threshold loses soft bounces (a whole class of play); lowering it
floods the game with phantom hits. The separating information is not in the peak — it is in
the shape of the window. That is a classification problem.

- Model type: Create ML **Activity Classification** — the template exists to answer
  "what motion is this," which is exactly the question.
- Classes: `bounce`, `adjust`, `idle`.
- Runtime: the threshold is a cheap pre-filter; every window it catches goes to the model,
  and only `bounce` runs the physics. Training windows are captured through the *same*
  trigger at the *same* threshold, so train and inference see the same distribution.
- **Load-bearing test:** remove the model and the game misfires constantly, with no
  threshold setting that fixes it.
- Features: 9 channels — `userAcceleration xyz`, `rotationRate xyz`, `gravity xyz`.
- Sample rate **100 Hz**, prediction window **50 samples (0.5 s)**, cut as 20 frames
  before the acceleration peak and 30 after. These must match the data-collection app
  and the live inference path exactly.
- Window sizing rationale: a bat contact is a ~0.1–0.2 s impulse and a juggling rhythm
  runs under a second. A longer window would span two bounces; a lower rate would smear
  the peak, which is precisely the soft-vs-hard signal.
- Attitude/yaw is deliberately **excluded** as a feature: yaw is arbitrary, and roll/pitch
  are already encoded in the gravity channels. Including it would let the model memorize
  orientation instead of learning motion.
- The samples that matter most are **near the threshold** — the borderline motions the
  trigger would otherwise misfire on. Obvious bounces and obvious stillness teach little.
- Fully on-device. No network.

### 5.2 Contact Detection (pre-filter)
- A rule-based trigger, not ML: `|userAcceleration|` crossing a threshold marks a contact;
  the surrounding window is then handed to the classifier.
- A **refractory period** (~0.35 s) after each trigger stops one bounce firing twice.
- Threshold requires on-device tuning and cannot be guessed. The data-collection app
  exposes it as a slider with a live meter for exactly this reason; carry the tuned value
  into the game.

### 5.3 Off-Screen Indication — the heart of the feel
When the ball is outside the frustum, the screen must communicate **direction** and
**distance** without showing the ball:

- A directional indicator pinned to the screen edge nearest the ball's true bearing —
  it slides continuously along the edge as you rotate, never jumps.
- Indicator **size or opacity encodes how far off-axis** the ball is: nearly-in-view reads
  strongly, far-behind-you reads faintly.
- The **behind-you case** must be unambiguous and distinct from far-left / far-right —
  a bearing of 179° and 181° must not read identically.
- The ball must **animate continuously in and out** of the frustum. It slides past the
  screen edge; it never pops in or vanishes.

### 5.4 On-Screen Rendering
- Ball scales inversely with depth. Far = small, near = large.
- Position on screen derives from the angular offset between phone bearing and ball bearing.
- Return trajectory driven by the classified swing:
  - Launch speed scales continuously with peak `|userAcceleration|` — a gentle tap gives a
    low bounce, a firm pop gives a high one, and every gradation in between exists.
  - Launch bearing comes from reflecting about the bat's face normal, derived from the
    `gravity` vector at contact. Continuous 360° aim, no discrete direction buckets.
- Neither of these involves the model. That is deliberate.

### 5.5 Visual Feedback (Gestalt Principles)
- **Continuity:** the ball's path — on-screen, crossing the edge, and off-screen as an
  indicator — must read as one unbroken trajectory. No teleporting, no discrete state flips.
- **Common fate:** trail, glow, and indicator move with matched direction and timing so
  they are perceived as one object, not several UI elements.
- Optional: classified swing type shown briefly, timed with the ball's departure rather
  than as a separate popup.

## 6. Non-Functional Requirements
- Physical iPhone required — CoreMotion does not produce real data in the Simulator.
- On-device inference only.
- Deployment target **iOS 26.0** (not 27) so TestFlight builds reach iOS 26 devices.
  Building against the iOS 27 SDK in Xcode 27 is fine and unrelated.

## 7. Out of Scope
- ARKit / 6DoF positional tracking
- Multiplayer or two-phone sync
- Magnetometer / true-north heading
- Leaderboards, social, persistence beyond the session
- Any cloud training or inference

## 8. Tech Stack
- **Language:** Swift
- **Rendering:** SwiftUI, or SpriteKit if depth-sorted sprites get awkward in plain SwiftUI
- **Motion:** CoreMotion (`CMMotionManager`, `startDeviceMotionUpdates(using: .xArbitraryZVertical)`)
- **Training:** Create ML — Activity Classification
- **Inference:** Core ML (`.mlmodel` in the app bundle)

## 9. Milestones
1. ✅ Data-collection app (`selfpong_model`) — rally mode auto-cuts labeled 100 Hz /
   50-frame windows around each contact and appends them to CSV.
2. Record ≥30 samples per class — `bounce`, `adjust`, `idle` — all at the same
   trigger threshold the game will use.
3. Train in Create ML; export `.mlmodel`.
4. **Attitude-to-screen mapping** — ball rendered at a fixed 3D bearing above the bat,
   tracking correctly as you tilt. Build this with no ML at all; it is the riskiest
   unknown and is fully independent of the model.
5. Off-screen indicator + edge-crossing continuity.
6. Gravity simulation: ball rises, hangs, falls back to the bat.
7. Model integrated; live class shown on a debug label. Confirm grip shifts and walking
   are rejected while soft bounces are still accepted.
8. Physics wired: peak magnitude → launch speed, gravity tilt → launch bearing.
9. Gestalt polish pass.
10. End-to-end playtest.

**Sequencing note:** milestone 4 is the real risk, not the ML. Build it early and in
parallel with data collection — if the mirror mapping doesn't feel right, the game doesn't
work no matter how good the classifier is.

## 10. Open Questions
- Frustum field of view — how much of the world does the "mirror" show? Too narrow is
  frustrating, too wide kills the sense of aiming. Needs on-device tuning.
- Miss condition: dropping the ball is the natural lose state for keepie-uppie, and a
  rally counter is the natural score. Recommend adding both only **after** the mirror
  mapping and the classifier are both confirmed working.
- Yaw drift over a long session — is a manual re-center enough, or is it annoying in practice?
