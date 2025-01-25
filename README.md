# lua
Lua scripts for lua-supporting emulators
Specifically:
* SNES
  * [snes9x-rr](https://github.com/TASEmulators/snes9x-rr/releases) (v1.43 or 1.51)
  * [BizHawk](https://github.com/TASEmulators/BizHawk/releases/tag/2.8) (v2.8 or less)
  * [Mesen](https://mesen.ca/). Mesen scripts additionally require `cross emu - mesen.lua`
  * [lsnes](https://tasvideos.org/EmulatorResources/Lsnes) (I should test this more often)
* GBA
  * [VBA-rr](https://github.com/TASEmulators/vba-rerecording/releases)
  * [BizHawk](https://github.com/TASEmulators/BizHawk/releases/tag/2.8) (v2.8 or less)
* NES
  * [FCEUX](https://fceux.com/web/home.html)

* `Super Camhack.lua`: Requires `Super Metroid.lua` + `cross emu.lua`. BizHawk only. Non-intrusively fixes graphical errors caused by:
  * Misaligned doors
  * Scrolling too fast
  * Glitches allowing freedom of movement during x-ray
* `Super Hitbox.lua`: Requires `Super Metroid.lua` + `cross emu.lua`. Draws hitboxes around just about everything and some additional features:
  * Can show hitboxes beyond the screen boundaries in BizHawk (using the extra padding feature)
  * CPU usage monitor (BizHawk only)
  * Show the raw block/BTS data of blocks on screen (via select + A)
  * List all valid doors in the room, including out of bounds (via select + A)
  * Bind the hitbox display origin around Samus for navigation out of bounds (via select + B), origin can then be moved arbitrarily via select + d-pad to easily explore an entire room without moving
  * Move Samus around arbitrarily via select + A + d-pad
  * Show enemy health (with health bar); projectile damage; Samus' cooldown time, beam charge, recoil time and i-frame time
* `Super Hitbox + TAS.lua`: Requires `Super Metroid.lua` + `cross emu.lua`. Extension of `Super Hitbox.lua` with ports of the TAS features from sniq's lsnes script
* `Fusion Hitbox.lua`: Requires `cross emu gba.lua`. Hitbox viewer for Metroid Fusion. Supports room data, Samus, enemies and projectiles
* `RoS.lua`: Hitbox viewer for Metroid II. Supports room data and enemies.
* `Castlevania 2.lua`: Hitbox viewer for Castlevania II. Level data only. This one was the hardest hitbox viewer to make, Simon's Quest is weird.
* `Super charge shinespark.lua`: Requires `Super Metroid.lua` + `cross emu.lua`. Shows a rhythm game style chart on top of the HUD minimap to help learn the quick charge timing
* `super audio.lua`: BizHawk only. Requires `Super Metroid.lua` + `cross emu.lua`. WIP script for looking at sound effects ARAM state
* `super enemy.lua`: BizHawk only. Requires `Super Metroid.lua` + `cross emu.lua`. WIP script for looking at enemy RAM. Uses `enemy data.txt` for labelling AI variables and any known values
* `super cpu.lua`: BizHawk only. Requires `cross emu.lua`. Colours the screen according to execution time of registered functions
* `smz3.lua`: BizHawk only. Simple script that lets the user take notes for the smz3 randomiser. Works via a text box whose text is persisted to disk and a dropdown for switching between areas
