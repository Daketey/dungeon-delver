# Dungeon Delver 3D

A first-person 3D dungeon crawler built in Godot 4.6, based on the **Simple Dungeon 1.5** tabletop ruleset.

[dungeon-delver-3d.netlify.app](https://dungeon-delver-3d.netlify.app)

## Controls

| Key | Action |
|---|---|
| WASD | Move |
| Mouse | Look around |
| E | Interact (doors, merchant) |
| Tab | Inventory |
| M | Dungeon map |
| L | Notification log history |
| F1 | Toggle debug: disable enemy spawns |
| Left-click / Enter | Attack in combat |

## Gameplay

Explore a procedurally-generated dungeon one room at a time. Fight enemies, disarm traps, find treasure, and buy gear from the merchant. After 10 kills, the Greater Demon awakens — prepare before facing it.

### Combat (Simple Dungeon 1.5 rules)

- **d8 HIT** — must beat enemy level to land a hit
- **d6 DMG** — your damage dealt
- **d4 DEF** — damage blocked
- **Natural 8** — re-roll damage die
- **Natural 1** — swap damage and defense dice
- **Heroic Feats** — swap any two dice once per fight
- **Flee** — take d4 damage and retreat

### Boss

After 10 kills, the boss appears **d4 rooms away**. No new enemies, traps, or treasure spawn while it hunts you. Reach it before exploring further.

### Starting Equipment

Roll d4 on the weapons and treasure tables. Longswords prevent shield use.

## Technical

- **Engine:** Godot 4.6.3 (GL Compatibility for web export)
- **Language:** GDScript (strict typing, warnings-as-errors)
- **Rendering:** Forward+ (desktop) / GL Compatibility (web)
- **Architecture:** Single-room scene loading with state persistence via `World.gd` + `RoomGenerator.gd`
- **UI:** All menus built as `.tscn` scenes (TitleScreen, CombatScreen, PlayerHUD)

## Project Structure

```
scripts/         GDScript source files (World, Combat, UI, GameData, etc.)
scenes/          .tscn scene files (World, Player, Enemy, UI screens, etc.)
materials/       .tres material files (Floor, Wall, Environment)
textures/        Texture assets
  dungeon/       Wall/floor textures and normal maps
  ui/            UI textures (compass, etc.)
Enemies/         Enemy sprite textures
Dice/            Dice face textures
rooms/           Legacy room scenes (unused, templates are in RoomGenerator.gd)
```

## Export

Web export via Godot's HTML5/WebGL target. Requires GL Compatibility renderer.
