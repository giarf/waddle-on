# Penguin artwork and animation

## Provenance

`Sources/WaddleOn/Resources/Penguin/penguin-atlas.png` contains rasterized **Club Penguin artwork**, not a newly drawn approximation. The base SWF was retrieved on 2026-10-07 from the third-party preservation mirror:

<https://media.cpatake.boo/play/v2/content/global/penguin/penguin.swf>

- Source size: 164,425 bytes; SWF version 11, 24 fps, 38 root timeline frames.
- Source SHA-256: `f089b4c1fc17d7f6a53e352cee199dc4b30128b3bca909a03dac3505e8366b7e`.
- Atlas SHA-256: `091b7053ead83aeb52d71a0d3fd2d6e31b448292cda1105bc4f8147461e63cc0`.
- Exporter: local JPEXS FFDec 26.2.1 at `/Users/gabrielrojasferrada/dev/clubpenguin/ffdec_mac/FFDec.app/Contents/Resources/ffdec-cli.jar`.

The local `wand/legacy-media` and `wand/vanilla-media` directories were empty. Their submodule URLs were checked; the attempted legacy-media raw URL returned 404. The local Yukon checkout contains engine code but no `assets/media` character images. The local `swfs` directory contains party room files; inspection of `party.swf` showed room symbols rather than the reusable base penguin. These source checkouts were kept read-only. The former official `media1.clubpenguin.com` hostname did not resolve, so the preservation mirror was used. This mirror's bytes have not been independently compared with an official archival checksum.

The artwork remains Club Penguin/Disney artwork; neither the source-code license nor this extraction grants redistribution rights to it. The mirror does not establish a separate license.

## Extraction

1. Export the source using FFDec `-swf2xml input.swf penguin.xml`.
2. Work on an XML copy only. Replace the root stage rectangle with `Xmin=-800, Xmax=800, Ymin=-1400, Ymax=700` (twips). The original stage is only 20×20 px and would clip the character.
3. Retain root frames 1–16 and their definitions. Remove root `DoActionTag` nodes; no ActionScript is run in the app. Frames 1–8 are the eight standing directions. Root frames 9–16 each contain three synchronized, eight-frame walk component timelines (two components in the back-facing pose).
4. Expand each walk root frame into eight consecutive `ShowFrameTag`s before its subsequent remove/place tags. Set root frame count to 72. This preserves each root pose's original transforms and lets its nested walk components advance together.
5. Convert using `-xml2swf`, then export with `-zoom 3 -ignorebackground -export frame OUTPUT render.swf`. This produces 72 transparent 240×315 PNGs.
6. Crop every frame identically to pixel rectangle `(57,115,184,257)`, including a four-pixel transparent safety margin. Pack into the atlas described below without scaling, redrawing, or recoloring.

Only the resulting PNG is shipped. Flash, Java, network access, and the source mirror are not runtime dependencies.

## Atlas contract

- RGBA PNG, **1143×1136** pixels, 9 columns × 8 rows.
- Each cell is **127×142** pixels, consistent origin across all frames.
- Rows from the top: south, southwest, west, northwest, north, northeast, east, southeast.
- Column 0: authentic standing pose; columns 1–8: one full authentic walk cycle.
- Playback: 24 fps (the SWF's original rate).
- All eight walk frames in each of the eight directions were verified pixel-distinct. Source frame bounds were checked to fit the enlarged export stage, and standing-direction contact sheet visually inspected.

## Swift API

```swift
let penguin = PenguinView(frame: NSRect(x: 0, y: 0, width: 100, height: 110))
penguin.setWalking(true, toward: CGVector(dx: 1, dy: 0))
penguin.setWalking(false, toward: .zero)
penguin.toggleDance() // Again to stop; original 193-frame dance loops.
penguin.throwSnowball(toward: CGVector(dx: 1, dy: 0)) // One shot, then idle.
penguin.stopAction()
let busy = penguin.isPerformingAction
```

`PenguinView` is an `NSView` with intrinsic content size 100×110. Use it on the main thread. The movement vector uses AppKit screen coordinates: positive x is right, positive y is up. Zero or non-finite vectors preserve the previous facing direction. The view aspect-fits the sprite, preserving transparency and anchor alignment; callers own all movement and event handling.

Resources load from `Bundle.module`, subdirectory `Resources/Penguin`, with the package's `.copy("Resources")` rule. Frames are decoded once and shared between instances. The 24 fps timer runs in common run-loop modes while attached to a window, uses a weak capture, and stops when detached. Reduce Motion displays standing poses while retaining facing updates.

### Original dance and snowball actions

`Support/extract-penguin-actions.py` reproduces both action atlases from the pinned source SWF using Java, FFDec 26.2.1 and Pillow:

```sh
python3 Support/extract-penguin-actions.py /path/to/penguin.swf /path/to/ffdec-cli.jar /path/to/work-dir
```

The extractor resolves the original root display list at each action frame, retains its component transforms, then holds that pose while all nested component timelines advance together at **24 fps**. Importantly, root frame 29 inherits two components from frame 28 with matrix-only updates; these are resolved before extraction and their animation clocks restart together. No artwork is redrawn, recolored, interpolated or approximated. Source `stop()` commands on throw frame 28 are respected by one-shot native playback; no ActionScript runs in the app.

| Action | Root frame | Component symbols | Frames | Duration |
| --- | --- | --- | --- | --- |
| Dance | 26 | 275, 297, 319 | 193 | 193/24 = 8.0416667 s, looping |
| Throw southwest | 27 | 345, 370, 398 | 28 | 28/24 = 1.1666667 s |
| Throw northwest | 28 | 422, 429, 455 | 28 | 28/24 = 1.1666667 s |
| Throw northeast | 29 | 481, inherited 429 and 455 | 28 | 28/24 = 1.1666667 s |
| Throw southeast | 30 | 495, 370, 398 | 28 | 28/24 = 1.1666667 s |

The local Yukon sources were read directly: `ActionsMenu.js` requests dance frame 26, and `SnowballFactory.js` computes `max(round(direction / 2), 1) + 26` and schedules projectile release after **833 milliseconds**. Thus the eight facing directions map to the four authentic throw poses as S/SW → 27, W/NW → 28, N/NE → 29, E/SE → 30. `PenguinView.snowballReleaseDelay` and `.throwDuration` expose the timing contract; projectile creation and movement belong to Desktop.

- Dance atlas: `penguin-dance-atlas.png`, **3616×2769**, 16 columns × 13 rows, first 193 cells in row-major order (remaining 15 transparent).
- Throw atlas: `penguin-throw-atlas.png`, **6328×852**, 28 columns × 4 rows ordered roots 27, 28, 29, 30.
- Both use transparent **226×213** cells, from the same unscaled 3× FFDec raster canvas cropped at `(6,65,232,278)`. The original 127×142 standing/walking cell occupies `(51,50,178,192)` in this shared canvas (top-origin coordinates). The entire canvas is aspect-fit for every state, preventing action clipping, anchor jumps or action-specific resizing; the penguin therefore occupies less of a same-sized view than before the action expansion.
- Dance SHA-256: `e11fb06da1805431937fda1e3e4ca52bf27f13496bc1001169371b776d9812a9`.
- Throw SHA-256: `17c115f6f44751aadb521b914acdb603106f7dfb4a855df9f7c13912acf5e0dc`.

Dance starts facing south, toggles off, and can be interrupted by a throw. A throw replaces the current action, uses monotonic elapsed time, and returns to a standing pose after 28/24 seconds. `setWalking(true,toward:)` cancels actions; `setWalking(false,toward:)` does not disturb an active action. `stopAction()` returns to idle after an action. Reduce Motion suppresses animated action frames but preserves busy state and one-shot completion timing. Detaching stops redraw timers; action elapsed time still advances, so a completed throw does not resume later.

## Actual limitations

- The source standing poses are static. Idle breathing is a subtle native vertical stretch of the authentic standing pose, not an original multi-frame idle animation.
- The bundled color is the blue/purple color present in the SWF. Clothing, player-selected colors, sit, and other special-action timelines are not included.
- Extraction reproduces vector fills and original timeline transforms through FFDec's rasterizer; it is not a Flash runtime screenshot and may differ in edge antialiasing.
- A missing/invalid atlas logs an error and leaves a transparent view rather than substituting unrelated artwork.

## Verification performed

- `swift build` completed successfully, including `PenguinView.swift` and the copied resource bundle.
- A native AppKit smoke check decoded the atlas through `NSImage`, extracted its `CGImage`, and cropped all 72 cells with the same geometry used by the view. The resulting south-facing cell was visually checked for orientation and transparency.
- Pillow verified eight distinct walking frames for every direction. The final expanded source canvas contains the full union of visible pixels with margins; no individual frame is cropped to its own bounds.
- Full interactive desktop movement and integration are owned by the application/desktop components.
- Action extraction verified all 305 frames and transparency bounds against both the stage and final common crop; the dance has 57 pixel-distinct frames (original holds/repeats retained), and the throws have 28, 25, 25 and 28 respectively. Union bounds on the 240×315 source canvas are dance `(30,99,210,274)`, throw 27 `(39,69,228,273)`, throw 28 `(29,90,168,239)`, throw 29 `(73,90,212,239)`, and throw 30 `(10,69,199,272)`. Each has at least four pixels of final-crop safety margin.
- A contact sheet spanning all five action sequences was visually inspected, including the windup, held snowball, release and recovery. `swift build` passed with the action playback API and copied atlases.
- A native AppKit smoke executable loaded the real `PenguinView` and package resource bundle, drew all four throw directions, verified dance toggle and stop, preserved dance through `setWalking(false)`, cancelled dance through `setWalking(true)`, and waited for each throw's one-shot completion. All assertions passed; `git diff --check` also passed.
