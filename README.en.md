# Pokémon Z Mods

[Español](README.md) · [English](README.en.md) · [Français](README.fr.md)

Configurable challenge mod for the Spanish, English and French editions of **Pokémon Z**. It adds enforced Nuzlocke, Random and Randomlocke from the first playthrough, setup wizards, in-battle learning aids and an integrated type chart.

> This repository does not include Pokémon Z, ROMs, executables, graphics, music or save files. You need a legally obtained copy of a supported edition.

## Supported editions

| Tested edition | Profile | Default mod language |
| --- | --- | --- |
| Pokémon Z **2.18 Spanish** | `es_218` | Español |
| Pokémon Z **2.13 English** | `en_213` | English |
| Pokémon Z **2.12 French + Patch 1** | `fr_212p1` | Français |

Pokémon names, move names and move descriptions come from each game's localized data. Every menu, explanation and notification added by the mod is translated. The mod language can be changed at any time under Options without changing the base game's language.

## Quick installation on Windows

1. Close the game and back up its folder and save files.
2. Download `Pokemon-Z-Mods-v1.1.3.zip` from [the latest release](https://github.com/Calatravo/pokemon_mods/releases/latest) and extract it.
3. On Windows, double-click `Install Pokemon Z Mods.cmd` and select the folder containing `Game.exe`.

You can also use PowerShell with the path to your game:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GamePath "C:\Games\Pokemon Z V2.13" -Language auto
```

`auto` detects the edition from its files even if the folder was renamed, then selects the language and compatibility profile. You can explicitly use `-Language es`, `-Language en` or `-Language fr`. The installer backs up `preload.rb` and `mkxp.json`, enables the loader, safely handles the broken legacy Zlib wrapper in 2.12/2.13 and never modifies `Data\Scripts.rxdata`. It is safe to run the same command again to update the mod.

See [PLATFORMS.md](PLATFORMS.md) for Android/JoiPlay, Steam Deck, Linux, macOS and iOS status, or [INSTALL.md](INSTALL.md) for manual installation, updating, uninstalling and troubleshooting.

## Android installation

### Simple installer for JoiPlay and Kirin

Download the [Android v1.1.3 installer (.apk)](https://github.com/Calatravo/pokemon_mods/releases/download/v1.1.3/Pokemon-Z-Mods-v1.1.3-Android-Installer.apk). Choose the game folder, confirm its edition and tap **Install / update mod**. It includes the mod, backups and a loading check. The APK is **experimental**: JoiPlay was tested on virtual Android; Kirin remains unverified. [Installer source and instructions](installer/android/README.md).

> Version 1.1.3 includes the fixes verified in JoiPlay. The published 1.1.2 ZIPs do not include those fixes and failed to load the mod in the tested environment. See the [validation report](docs/android-validation.md).

1. Install [JoiPlay and RPG Maker Plugin](https://joiplay.net/), or Kirin for experimental testing. Extract Pokémon Z into an accessible folder such as `Documents/PokemonZ`.
2. Close the game and back up your saves. Install and open the **Pokémon Z Mods** APK.
3. Tap **Choose game folder**, select the folder directly containing `Game.exe`, and grant access. Do not select the ZIP or the `Mods` folder.
4. Confirm the game edition: **Spanish 2.18**, **English 2.13** or **French 2.12 + Patch 1**. Select the game edition, regardless of your preferred mod menu language.
5. Tap **Install / update mod**. Backups are stored in `PokemonZMods-backups/date-time/`. Saves and `Data/Scripts.rxdata` are preserved.
6. In JoiPlay, tap `+` and add `Game.exe`. If asked for the **RPG Maker XP RTP**, download it from [RPG Maker](https://www.rpgmakerweb.com/run-time-package) and import it through **Settings → Import Runtime Packages → RPG Maker XP** in JoiPlay. You do not need to run the Windows installer on Android. In Kirin, add the same game folder to its library.
7. Open the game, close it and return to the APK to **Check installation**. Confirm loading with `PASS (14 hooks)` and `Compatibility profile PASS`.

See the [illustrated installation steps](README.md#instalador-sencillo-para-joiplay-y-kirin) for screenshots of folder selection, installation and verification.

### When Randomlocke appears

Start a new game and progress through the introduction and initial Nuzlocke selection. **The setup wizards do not appear on the title screen.** If you choose Nuzlocke, configure its rules; then enable Random for Randomlocke. Answer **Yes** to the game's “Understood?” tips prompt to continue; **No** repeats the tips.

![Random setup running in JoiPlay; Spanish game used for this test](docs/screenshots/android/joiplay-random-settings.png)

### Test results and Kirin status

**JoiPlay 1.22.001 + RPG Maker Plugin 1.23.00:** startup, all 14 hooks and the Random wizard were verified with Spanish 2.18 on virtual Android. This is not a full playthrough; the other game editions have not been verified on Android.

**Kirin 0.3.5 and 0.4.0-beta4 remain unconfirmed.** The Android 16.1 emulator fails before loading the mod, even with 8 GB RAM and 8 CPU cores. A second Android 13 emulator rejects the ARM64 APK because of an incompatible architecture. No physical ARM64 phone has been tested. The installer prepares the files for Kirin but does not fix its runtime failure.

If options are missing after the introduction, keep `Mods/HardcoreNuzlocke/nuzlocke.log` and report the game, mod and runtime versions. Options should also include the challenge, battle aid and type chart menus. See the [test environment and limitations](docs/android-validation.md).

Without the APK, prepare the game on a PC using the **version 1.1.3** installer, then copy the resulting folder to Android. `Game.exe`, `preload.rb` and `Mods/HardcoreNuzlocke/loader.rb` must retain their layout, without an extra ZIP-named parent folder. See [INSTALL.md](INSTALL.md).

## First-playthrough setup

Nuzlocke and Random are available from the first playthrough; completing the game is no longer required. At the end of the introduction, after the initial Nuzlocke question, selecting **Yes** leads to its setup wizard. The game then always asks whether Random should be enabled and, if accepted, opens the Random setup wizard.

This supports four starting modes:

- Normal game: Nuzlocke and Random disabled.
- Nuzlocke: only the enforced Locke rules are active.
- Random: only the randomizer is active.
- Randomlocke: Nuzlocke and Random are active together.

Typical settings start enabled. Selecting any setting opens a full explanation, describes its gameplay impact and asks for a Yes/No confirmation before changing it. `Apply and continue` saves the configuration. Nuzlocke and Random settings are locked to that save once play begins; learning aids remain editable.

## Enforced Nuzlocke

### Mandatory rules

| Rule | Effect |
| --- | --- |
| **Permadeath** | A Pokémon that reaches 0 HP is marked dead, cannot be revived or returned to the party, and is moved automatically to the `CEMETERY` PC box. |
| **First encounter** | Only the first valid encounter in each area may be caught. Fainting it or fleeing records the opportunity as missed. Dupes and shiny exemptions are evaluated first. |
| **One catch per area** | Every logical area has one normal catch. Maps grouped into one location share their state unless method or subarea settings split them. |

### Configurable rules

| Setting | Default | Effect |
| --- | --- | --- |
| **Dupes clause (evolution line)** | On | An encounter from an evolution line already obtained is ignored and does not consume the area. Its capture is blocked so another encounter can be found. |
| **Exact species clause** | On | A species already obtained is treated as a duplicate without requiring the full evolution-line check. |
| **Shiny clause** | On | A shiny may be caught even after the area is used. It is logged as an extra catch and does not replace the normal area catch. |
| **Level caps** | On | Experience is capped by story progress. Configured caps are levels 17, 27, 36, 42, 50, 56, 70, 75, 80, 85, 94 and 100. |
| **No battle items** | On | Healing, boost and similar Bag items are blocked in battle. Poké Balls remain available for legal captures and held items are not removed. |
| **Set style** | On | Enforces Set battle style, removing the free switch offered after an opposing Pokémon faints. |
| **Gifts consume the area** | Off | Gift Pokémon and Eggs use the area where they are received. A used area blocks the gift; duplicate and shiny clauses still apply. Off means gifts are exempt. |
| **Static encounters consume the area** | On | Visible, static and event-started Pokémon count as that area's encounter. Off makes them exempt. |
| **Grass/water/fishing share the area** | On | Land, cave, Surf and fishing use one shared opportunity. Off gives each method a separate opportunity. |
| **Each submap counts separately** | Off | Every internal map or floor becomes its own area. Off groups floors and segments belonging to the same logical place. |

Illegal Poké Balls are returned with an explanation. Double encounters, shiny Pokémon, gifts and duplicates follow their configured clauses. `Nuzlocke progress` reports current area, catches, missed encounters, extra shiny catches, deaths and the level cap. `Area records` shows each location's encounter and catch state. If no usable Pokémon remain, the run is marked failed without making the save unusable.

The introductory Bidoof battle after choosing a starter is exempt from permadeath and run failure. The starter recovers its HP if it faints; later battles follow normal rules. With random moves enabled, starters receive their randomized moves according to level and Progressive Random settings.


## Random mode

Random tables are generated and saved for the playthrough, so species, abilities, evolutions and other results remain consistent.

### Ability mode

| Mode | Default | Effect |
| --- | --- | --- |
| **Full Random** | Selected | Every species receives new random abilities. |
| **Consistent mapping** | Not selected | Every original ability maps to one stable random replacement throughout the save. |
| **Do not randomize** | Not selected | Keeps the species' normal abilities. |

### Configurable Random settings

| Setting | Default | Effect |
| --- | --- | --- |
| **Progressive Random** | On | Restricts species base strength and move power according to earned badges, avoiding extreme early-game results. |
| **Random moves** | On | Gives each species a random learnset; Progressive Random also scales available power. |
| **Random evolutions** | Off | Replaces evolutions with stable random species saved for the playthrough. |
| **Similar-BST evolutions** | On | When evolutions are randomized, prefers a target with similar base-stat total. It has no practical effect while Random evolutions is off. |
| **Random TM compatibility** | On | Randomizes which TMs each Pokémon can learn. |
| **Random types** | Off | Assigns stable random types, changing STAB, weaknesses, resistances and immunities. |
| **Random field items** | On | Randomizes one-time visible and hidden pickups while protecting key items, HMs and Mega Stones. Renewable trees, rocks, material crates and Berry plants keep their normal resources to prevent unlimited random farming. |
| **Random event gifts** | Off | Randomizes non-essential gifts and rewards handed out directly by events. Key items, HMs and Mega Stones remain protected. |
| **Random held items** | On | Allows wild Pokémon to carry safe random items. |
| **Random trainer rewards** | Off | Allows some defeated trainers to grant an extra random reward. |
| **Semi Random mode** | Off | Limits randomization to encounters and gifts; trainers, moves, abilities and items keep their normal behavior. |

After a field item, event gift or reward is successfully added to the Bag, the game keeps its normal acquisition messages and then opens a separate window with the item's localized description. It appears once even for multiple copies and, with Random enabled, describes the item actually received after replacement.

Generations **1 through 9** start enabled and can be toggled individually. The randomizer only selects species from enabled generations and prevents the last enabled generation from being disabled.

## Battle learning aids

These settings work in normal, Nuzlocke, Random and Randomlocke games. They can be changed at any time under Options, with the same explanation and confirmation screen.

| Aid | Default | Effect |
| --- | --- | --- |
| **Move details with X** | On | Press `X` over a battle move to see its type icon and name, physical/special/status category, power, accuracy, PP, priority, effectiveness and localized description. |
| **Move effectiveness** | On | Labels damaging moves as `SUPER EFFECTIVE`, `NOT VERY EFFECTIVE`, `NORMAL` or `NO EFFECT`; status moves display `STATUS`. |
| **Exact multipliers** | Off | Uses the actual combined multiplier (`x0`, `x0.25`, `x0.5`, `x1`, `x2`, `x4`, etc.) in move and switch help. |
| **Switch matchup help** | On | While browsing the party during a switch, compares the candidate's offensive and defensive type matchup with the active opponent. |
| **Warn about no-effect moves** | On | Requests confirmation before using a damaging move with an `x0` multiplier. Status moves are not interrupted. |
| **Show opponent types** | On | Displays the active opponent's type names above the move selector. |

## Type chart and menus

The integrated chart uses the game's type icons and translated type names. Left/Right changes type, `C` switches between Defense and Attack, Up/Down scrolls long lists and `X` or Escape returns. Relations are shown as `x2`, `x1/2` and `x0` in a safe multi-column layout, including Rock's longer attack list.

During battle, press `R` in the move selector to open the chart immediately. Closing it returns to the same selected move without spending the turn or changing the choice. The move selector shows `R: Types` next to the `X: Info` shortcut.

Added entries:

- **Options → Challenges:** Nuzlocke/Random configuration and status, progress, area records and Cemetery.
- **Options → Battle learning aids:** all six learning settings.
- **Options → Type chart:** offensive and defensive type reference.
- **Options → Mod language:** Español, English or Français.
- **Pause menu → Challenges:** opens the same challenge center.

## Screenshots

| Challenges | Random setup |
| --- | --- |
| ![Challenge center](docs/screenshots/01-desafios.jpg) | ![Random configuration](docs/screenshots/02-configuracion-random.jpg) |

| Type chart | Battle learning aids |
| --- | --- |
| ![Integrated type chart](docs/screenshots/03-tabla-tipos.jpg) | ![Battle learning configuration](docs/screenshots/04-ayudas-combate.jpg) |

## Diagnostics

The game creates `Mods\HardcoreNuzlocke\nuzlocke.log`. A correct startup includes:

```text
Installation self-test PASS (14 hooks)
Compatibility profile PASS: en_213; language=en
```

If the game closes or a screen fails to open, attach that log, the exact game edition and the list of other installed mods to the issue.

## Legal notice

Free, unofficial fan project. Pokémon and its trademarks belong to their respective owners. This project is not affiliated with or endorsed by Nintendo, Game Freak, Creatures Inc. or The Pokémon Company.

## Automatic updates on Windows

Starting with 1.1.0, a separate process checks stable GitHub releases at startup. Slow or unavailable internet does not hold up the game. The prompt appears only in the initial menu; if you already loaded your save, it waits until a future launch.

Accepting closes the game automatically. A separate update window downloads and verifies the package SHA-256, backs up the old mod and installs the update. The game then reopens. Declining keeps the current version and allows another check next launch. Saves, saved settings and the installation language/profile are preserved.

PowerShell and write access to the game directory are required; no elevation is requested. Errors and backups are stored in `Mods/.pzn-updates/<session>/`. Install 1.1.0 manually once to enable future updates. Other platforms continue to use manual installation.
