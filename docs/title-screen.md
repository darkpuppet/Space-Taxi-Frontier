# Orbital taxi stand title screen

The main menu uses `assets/backgrounds/title-taxi-stand-v1.png`, an original opaque bitmap generated with the built-in imagegen tool using the game's original taxi/passenger atlas as a style reference. The scene shows a yellow taxi at a neon orbital taxi rank, waiting travelers, a station canopy, and a planet in the distance. A quieter dark area on the left leaves room for the title and controls.

The original PNG is preserved. A full-window Godot TextureRect scales the bitmap to cover the logical viewport while preserving its aspect ratio. The New Game and Exit controls use a translucent panel on the left. Menu text remains native Godot UI for clear rendering and keyboard navigation.

Starting the game hides the title artwork. Pause, life-loss, Game Over, and campaign overlays retain their centered layout. Returning to the main menu restores the artwork. The existing 1280 by 720 logical viewport and letterboxing behavior handle window resizing.

`tests/menus.gd` checks visibility through the menu lifecycle and saves `tests/title-screen.png` when run graphically. `tests/window-scaling.gd` checks the title menu at landscape, portrait, and smaller window sizes.
