# Desktop shell integration and validation

`DesktopController` is main-thread AppKit code. It exposes `init()`, `start()`,
`stop()`, `showBubble(_:)`, `setChatVisible(_:)`, `setChatContent(_:)`,
`setChatExpanded(_:)`, `onOpenSettings`, and `onQuit`. Set callbacks and install
the chat view before calling `start()`. The chat starts visible and accepts key
focus when clicked or explicitly opened. The character panel never takes key focus.

The only character dependency is `PenguinView(frame:)` and
`setWalking(_:toward:)`, with a `CGVector` in AppKit coordinates.

## Checks performed

- `swiftc -typecheck` passed for the desktop implementation against a temporary,
  external `NSView`-based `PenguinView` contract stub.
- Initial integrated `swift build` was blocked by the character class and
  Resources directory not yet being present in the shared workspace.
- Integrated build and live UI verification remain with the coordinator.

## Manual acceptance

1. Launch: character and bottom chat appear above normal windows; menu bar shows
   the penguin. Typing in another application remains unaffected.
2. Click a transparent character corner and rounded chat/bubble corner: the
   underlying application receives the click. Click the sprite itself: toggle chat.
3. Drag the sprite between displays, including one left of or below the primary
   display. Release: keep the character within a visible screen frame.
4. Option-click in another application: character walks toward the pointer,
   then stops animating. Try another display, screen edges, Spaces and fullscreen.
5. Open chat, type, expand history to 450 points, collapse to 100 points. Ensure
   input focus and scrolling work without the character stealing focus.
6. Show a long multiline bubble: text remains legible, selectable and scrollable,
   and the panel stays within the current display. Empty text hides the bubble.
7. Hide/show through the Spanish menu, open settings and quit. Call stop/start
   again during development to confirm monitor and timer cleanup.
8. Disconnect a display while the character is on it: it returns to an available
   visible frame.

## Runtime limitations

Mouse-only global observation uses NSEvent, not an event tap or global keyboard
capture; no Accessibility permission is requested. If the environment does not
deliver global mouse events, dragging and “Traer pingüino aquí” remain available.
Option-click is observed rather than consumed: the underlying application also
receives its click. Alpha hit regions refresh every 50 ms, so unusually fast
pointer-entry-and-click sequences can race the refresh. Layer-backed sprite
rendering and display scaling need live verification of the alpha sampling.
The bubble has a downward tail even when screen-edge constraints place it below
the character. The shell does not guarantee overlay visibility above system-owned
secure surfaces such as the lock screen.
