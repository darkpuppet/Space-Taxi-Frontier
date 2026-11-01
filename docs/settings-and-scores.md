# Settings and high scores

Open **Settings** from the main menu or Pause. Changes apply immediately and persist independently of career progress. Back or Escape returns to the menu you opened it from; opening or closing Settings never resumes the taxi.

| Tab | Options |
| --- | --- |
| Sound | Master, music, effects, and voice volume |
| Game | Pilot name (16 characters), fullscreen, camera shake, title dispatch ticker |
| Controls | Rebind left, right, lift, and brake; controller dead zone; reset controls |

Keyboard rebinding replaces the selected keyboard action while preserving controller bindings. Duplicate assignments and M, T, R, Enter, Escape, and 1-4 are reserved to keep menu, mute, tow, retry, and workshop controls available. The default layout includes WASD, arrow keys, and Space for lift; resetting controls restores it. Flight hints reflect the current primary keys. M is a temporary mute toggle; mixer levels persist separately.

**High Scores** is available from the main menu, Pause, and end-of-run screens. The local table retains the top ten finished runs, ranked by final credits, then sector reached and fares delivered. The display shows pilot name, credits, fares, and **Last Level**, the highest level reached in that run. Campaign completion status is still retained in the saved entry.

When a Game Over or completed campaign qualifies for the top ten, a name-entry dialog opens automatically. The previous pilot name is prefilled and selected. Enter a nonblank name of up to 16 characters and press Enter or Save High Score; the entry is saved once and the leaderboard appears. The entered name is remembered for next time. Skip or Escape declines the entry and returns to the end-of-run screen. Scores below the cutoff (including exact ties for tenth place) do not prompt. Abandoned runs and developer testing sessions do not submit.

The leaderboard is presented as a ten-row mechanical split-flap departure board. Individual letter and number tiles cycle through characters with a hinged flip, staggered across each row, then settle on the score. Animation continues while the game is paused and stops when the board finishes or is hidden. Opening the table again replays the reveal. Names are displayed in uppercase while the saved name remains unchanged. Numeric values too long for their cells show `#` overflow markers rather than losing leading digits. `scripts/split_flap_board.gd` owns this presentation.

Normal preferences live in `user://frontier_settings.cfg`; scores live in `user://frontier_scores.cfg`. New Game and Return to Main Menu do not erase them. Tests using an isolated career file automatically use isolated preference and score files as well.

Implementation: `scripts/preferences.gd`, `scripts/high_scores.gd`, and `scripts/menu_dialogs.gd`. Audio uses independent music, effects, and voice buses under Master. `tests/settings-scores.gd` verifies real rebinding, persisted mixer settings, menu lifecycle, table ranking, duplicate prevention, and campaign/developer recording behavior. Graphical runs save settings and high-score preview images under `tests/`.
