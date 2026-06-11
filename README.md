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
