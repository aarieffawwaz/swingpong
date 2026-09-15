# SwingPong Training — Simple Checklist

Do not use the old `soft / hard / angled` instructions. The current model learns:

- `bounce`: a real upward pop that should count.
- `adjust`: a grip or recovery movement that must not count.
- `idle`: ordinary movement that must not count.

The app guides you through the work. Do one row at a time.

| Step | What you do | Why | Done when |
|---|---|---|---|
| 1. Connect | Connect and unlock the iPhone, then open **selfpong_model**. | Motion recording only works on a real phone. | You see “Teach the game what a bounce feels like.” |
| 2. Calibrate | Press **Let’s Start**. For each of the five circles, press **Measure This Bounce** and make one gentle upward pop. | The app needs to learn how sensitive the trigger should be. | All five circles have checkmarks and the app says **Sensitivity ready**. |
| 3. Pilot Bounce | Choose **Me**, press **Start Recording**, and make different real bounces. Stop at 10. | This teaches motions that should count. | Real Bounce shows at least 10. |
| 4. Pilot Adjust | Press **Skip for now** or continue to **Hand Adjustment**. Shift grip and recover without a clean pop. Stop at 10. | These are confusing near-misses the model must reject. | Hand Adjustment shows at least 10. |
| 5. Pilot Idle | Continue to **Everyday Movement**. Walk, turn, hold still, and pick up the phone normally. Stop at 10. | These are normal motions the game must ignore. | Everyday Movement shows at least 10. |
| 6. Share pilot | Open **Check Your Progress**, press **Continue to Share**, then **Share Dataset**. Send `swings.csv` to the Mac. | The first 30 recordings must be checked before collecting more. | `swings.csv` is on the Mac. |
| 7. Validate | Run `python3 tools/prepare_dataset.py swings.csv --output PilotTrainingData`. | This catches broken or incomplete recordings. | The command says `Dataset ready: 30 valid sessions`. |
| 8. Full set | Return to each class and continue until each says 40. Keep **Me** selected for your recordings. | More varied examples improve the model. | You have at least 30 samples per class. |
| 9. Guest set | Ask another person to help. Select **Guest** and add at least 10 samples to every class. | Guest samples become a fair untouched test set. | Every class shows at least 40 total and includes 10 Guest samples. |
| 10. Final export | Share the CSV again and run the preparation tool with a new empty output folder. | Create ML needs one recording file per sample inside label folders. | `TrainingData/Training` and `TrainingData/Testing` exist. |

## Numbers that must not change

| Setting | Value |
|---|---:|
| Sample rate | 100 Hz |
| Frames per recording | 50 |
| Frames before trigger | 20, including the trigger |
| Frames after trigger | 30 |
| Refractory time | 0.35 seconds |
| Features | `ua_x ua_y ua_z rr_x rr_y rr_z g_x g_y g_z` |

The threshold is chosen during calibration and then locked. If the calibration feels wrong, recalibrate **before** recording samples.
