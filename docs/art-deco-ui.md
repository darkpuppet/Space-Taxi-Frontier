# Art Deco interface

Buttons across the title screen, Pause, settings, workshop, leaderboard entry, and on-screen keyboard share a navy/teal and champagne-gold theme. Stepped inset frames, small diamond ornaments, square corners, and geometric Josefin Sans lettering reference classic taxi-rank and station signage. Hover, pressed, and controller/keyboard focus states remain distinct; focus uses a bright teal double outline.

Main titles, dialog titles, and the cockpit heading use Limelight display lettering with stepped rules and a centered diamond. Long titles automatically shrink to fit the existing panel width. Body copy and score-board glyphs retain their original fonts.

The UI is drawn natively in Godot rather than rendered into images. `scripts/art_deco.gd` owns the shared theme, title sizing, and fonts; `scripts/deco_button_frame.gd` and `scripts/deco_title_rule.gd` draw decorations without intercepting input. Compact keyboard buttons use smaller margins. Fonts and licenses are under `assets/fonts/`.
