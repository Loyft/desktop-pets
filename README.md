# Desktop Pet

A lightweight macOS menu-bar companion that walks the bottom of your screen, climbs the sides, and hangs from the top — pixel-art style, built to stay out of the way while it runs.

## Requirements

- macOS 14+
- Xcode 16+ (command-line tools alone are not enough to build the app bundle)

## Build & run

```bash
open DesktopPet.xcodeproj
```

In Xcode: select the **DesktopPet** scheme, then **Product → Run** (⌘R).

Or from the terminal:

```bash
xcodebuild -project DesktopPet.xcodeproj -scheme DesktopPet -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/DesktopPet-*/Build/Products/Debug/DesktopPet.app
```

The app is a menu-bar accessory (no Dock icon). Look for the cat-shaped status item.

## Menu

| Action | What it does |
|--------|----------------|
| Hide / Show Pet | Toggles the floating companion |
| Pause / Resume | Freezes motion and animation updates |
| Open at Login | Registers/unregisters a Login Item via `SMAppService` |
| Quit | Exits the app |

## Behavior

- Walks back and forth on the floor, sometimes idles, sometimes climbs a side or hangs from the top
- Random direction changes mid-path (not only looping the screen edge)
- Occasional speech bubbles (`meow`, `mrrp`, `prrr`, …)
- Click the pet for a short react animation + meow

## Sprites

Reference sheet: [`assets/cat-sprite-sheet.png`](assets/cat-sprite-sheet.png).

To regenerate the SpriteKit atlas (chroma-key + slice + climb/hang placeholders):

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install Pillow
python scripts/extract_sprites.py
```

Climb and hang frames are rotated placeholders from the walk cycle; swap PNGs in `DesktopPet/Resources/Assets.xcassets/Pet.spriteatlas` using the same names when you have final art.

## Architecture (brief)

- **PetPanel** — small transparent floating `NSPanel` that follows the pet (not a full-screen overlay)
- **EdgePathController** — edge path state machine (floor → climb → hang → descend)
- **SpriteAnimator** — nearest-neighbor sprite playback at ~10 FPS
- **PetNeeds** — stub model for future feeding / playing / sleeping

## License

Open source — add a license of your choice when you publish.
