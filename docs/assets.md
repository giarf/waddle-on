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
```

`PenguinView` is an `NSView` with intrinsic content size 100×110. Use it on the main thread. The movement vector uses AppKit screen coordinates: positive x is right, positive y is up. Zero or non-finite vectors preserve the previous facing direction. The view aspect-fits the sprite, preserving transparency and anchor alignment; callers own all movement and event handling.

Resources load from `Bundle.module`, subdirectory `Resources/Penguin`, with the package's `.copy("Resources")` rule. Frames are decoded once and shared between instances. The 24 fps timer runs in common run-loop modes while attached to a window, uses a weak capture, and stops when detached. Reduce Motion displays standing poses while retaining facing updates.

## Actual limitations

- The source standing poses are static. Idle breathing is a subtle native vertical stretch of the authentic standing pose, not an original multi-frame idle animation.
- The bundled color is the blue/purple color present in the SWF. Clothing, player-selected colors, sit, dance, and special-action timelines are not included.
- Extraction reproduces vector fills and original timeline transforms through FFDec's rasterizer; it is not a Flash runtime screenshot and may differ in edge antialiasing.
- A missing/invalid atlas logs an error and leaves a transparent view rather than substituting unrelated artwork.

## Verification performed

- `swift build` completed successfully, including `PenguinView.swift` and the copied resource bundle.
- A native AppKit smoke check decoded the atlas through `NSImage`, extracted its `CGImage`, and cropped all 72 cells with the same geometry used by the view. The resulting south-facing cell was visually checked for orientation and transparency.
- Pillow verified eight distinct walking frames for every direction. The final expanded source canvas contains the full union of visible pixels with margins; no individual frame is cropped to its own bounds.
- Full interactive desktop movement and integration are owned by the application/desktop components.
