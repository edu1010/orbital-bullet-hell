# Abstract Swarm Prototype

Godot 4 first-person arena shooter / bullet-hell survival prototype using only primitive meshes and generated UI/effects. The arena is now a hollow abstract sphere: the player runs on the inside surface with radial gravity.

Enemy visuals are generated from primitive low-poly pieces: dark cores, warm faceted masks, neon crystal accents, and shard-like silhouettes. No external or copyrighted assets are used.

## Launch

Open this folder in Godot 4.x and run `res://scenes/Main.tscn` or press Play. The project main scene is already set in `project.godot`.

## Controls

- WASD: move
- Mouse: look / aim
- Space: jump, double jump, enemy-platform jump
- Left mouse: fire extra shot when charged
- Right mouse: fire orbital shield when charged
- Shift: boost when charged
- Esc: pause
- R: restart from game over

Primary fire is automatic while a run is active.

## Saving

Progress and preferences persist between sessions via Godot `ConfigFile` saves in
`user://`:

- `abstract_swarm_highscore.cfg` — best score.
- `bullet_hell_settings.cfg` — all settings (resolution, fullscreen, FPS limit, FOV,
  sensitivity, volume, HUD toggles, language) and every key rebind. Saved on each
  change and reloaded on startup.

The language toggle (English / Español) lives in Settings → HUD and re-localizes the
whole UI, including the tutorial, on the fly.

## Tutorial

The main menu has a `TUTORIAL` button (marked with a graduation-cap icon). It launches
a guided, non-lethal sandbox with one short scene per game element — movement, jumping,
primary fire, enemy-platform jumps, the extra shot, orbital shield, boost, each enemy type
(charger, avoider, bomb), the heal reflector, and the score magnet. Each scene states an
objective and only advances once the player actually performs that mechanic. `Esc` exits to
the menu and `N` skips the current scene. See `scripts/tutorial_controller.gd`.

Rare purple score magnets can drop from kills. Collecting one pulls all active score shards toward you.

## Structure

- `scenes/player/Player.tscn`: first-person controller
- `scenes/enemies/*.tscn`: swarmers, chargers, avoiders, bombs
- `scenes/projectiles/Projectile.tscn`: pooled primary projectile
- `scenes/shards/Shard.tscn`: pooled score pickup
- `scenes/pickups/ScoreMagnet.tscn`: rare pickup that magnetizes active score shards
- `scenes/effects/BurstEffect.tscn`: pooled greybox burst effect
- `scripts/game_manager.gd`: run state, pooling, scoring, collision severity, enemy-platform checks, bombs, extra shot, orbital shield
- `scripts/spawn_manager.gd`: spawn pacing, whole-sphere outside spawns, enemy mix
- `scripts/main.gd`: generated spherical arena shell and interior grid
- `scripts/ui/game_ui.gd`: HUD, menu, pause, game over, damage/ready feedback

Most tuning values are exported on the relevant scripts.
