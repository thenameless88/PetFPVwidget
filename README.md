# PetFPVwidget_EN – pixel-art pet widget

Full-screen (320x240) widget: a pixel-art cat or dog that shows moods, reacts to telemetry (LQ, RSSI, RX and TX battery) and shows the ARM state.
Tested on: Helloradio V12

## Installation

1. Copy the `SD/WIDGETS/PetFPV/` folder to the SD card, so you get `SD:/WIDGETS/PetFPV/main.lua` and `SD:/WIDGETS/PetFPV/img/...`
2. Pick a 1-zone (full screen) layout and add the widget.

Keep the folder name `PetFPV`: EdgeTX limits widget folder names to 8 characters, and the code uses this path.

## Breeds (`Breed` option, 1–10)

| # | Breed |
|---|-------|
| 1 | Siamese (blue point) |
| 2 | Calico (tricolor) |
| 3 | Black cat |
| 4 | British shorthair |
| 5 | Ginger tabby |
| 6 | Golden retriever |
| 7 | Husky |
| 8 | Harlequin dachshund |
| 9 | Corgi |
| 10 | German shepherd |

## How it works

- In the calm state the mood changes every 4 seconds: calm, happy, looking around, excited, bored, sleepy. Dogs pant happily.
- No telemetry: the pet sleeps.
- On a bad value the pet cries, the frame flashes red, a caption appears and a beep sounds:
  - LQ < 70 % (`LQLow` option)
  - RSSI < -95 dBm (`RssiLow` option)
  - RX battery < 3.50 V per cell (`CELL_LOW` constant)
  - TX battery < 6.8 V (`TX_LOW_V` constant)
- ARM indicator top right: green SAFE / flashing red ARMED, with a determined face; a tone sounds when ARM/DISARM changes.
- The bottom status bar shows LQ, RSSI, RX and TX with a green / red / grey dot.

## Widget options (EdgeTX allows at most 5)

| Option | Default | Meaning |
|--------|---------|---------|
| LQLow | 70 | LQ warning threshold (%) |
| RssiLow | -95 | RSSI warning threshold (dBm) |
| Cells | 0 | RX battery cell count, 0 = auto |
| ArmSw | ch5 | ARM switch or channel |
| Breed | 1 | Breed, 1–10 |

Constants at the top of `main.lua`: `ARM_ACTIVE_HIGH` (true: switch high = ARM), `TX_LOW_V`, `CELL_LOW`, `CARD` (background card), `DEBUG`.

## Credits
Special thanks to **haverr44** for creating the pixel art assets used in this script.
