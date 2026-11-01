# Taxi death insults

## Title-screen dispatch ticker

Edit **ticker-messages.tres** to update the humorous dispatch wire along the bottom of the title screen. It uses the same `phrases` resource format and can be edited in Godot's Inspector or a text editor. It starts with 24 space-taxi messages, shuffled when the UI loads. One message scrolls right to left at 75 logical pixels per second; its complete trailing edge must leave the display before a 0.65-second blank gap and the next message's entrance. The ticker continues while the menu pauses gameplay and hides when a shift starts or another overlay opens.

The display uses glowing amber 5-by-7 LED glyphs, an unlit diode grid, and a dark bezel. Text appears in uppercase; letters, digits, and common punctuation are supported. Unknown characters display as a question mark. The original message text stays unchanged in the library.

## Crash lines

Edit **death-insults.tres** to add, remove, or change the game's crash one-liners. In Godot, select the resource and edit its `phrases` array in the Inspector. In a text editor, put each phrase in double quotes inside `PackedStringArray(...)`, separated by commas. Escape embedded double quotes as `\"`. No code change is needed; restart the game after editing.

Lines should be short, funny digs at the fictional driver's piloting. Keep each to roughly one sentence so the crash banner and loss dialog stay readable. The library starts with 28 phrases.

The game shuffles the full library, uses every unique nonblank phrase before repeating, and avoids immediate repeats across shuffles. Blank and duplicate lines are ignored; an empty list falls back to a built-in quip. The resource is preloaded, so Godot includes it in game exports.

An explosion shows its quip immediately in the banner and retains the same one in the retry or Game Over dialog. Black-hole deaths also show a random quip. Pausing doesn't reroll it, retries clear it, and voluntary restarts don't trigger a death insult. Selection uses its own random generator so it doesn't alter gameplay randomness.
