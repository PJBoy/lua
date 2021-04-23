# lua
Lua scripts for lua-supporting emulators

* `Super Camhack.lua`: Requires `Super Metroid.lua`. BizHawk only. Non-intrusively fixes graphical errors caused by:
  * Misaligned doors
  * Scrolling too fast
  * Glitches allowing freedom of movement during x-ray
* `Super Hitbox.lua`: Requires `Super Metroid.lua`. Draws hitboxes around just about everything and some additional features:
  * Can show hitboxes beyond the screen boundaries in BizHawk (using the extra padding feature)
  * CPU usage monitor (BizHawk only)
  * Show the raw block/BTS data of blocks on screen (via select + A)
  * List all valid doors in the room, including out of bounds (via select + A)
  * Bind the hitbox display origin around Samus for navigation out of bounds (via select + B), origin can then be moved arbitrarily via select + d-pad to easily explore an entire room without moving
  * Move Samus around arbitrarily via select + A + d-pad
  * Show enemy health (with health bar); projectile damage; Samus' cooldown time, beam charge, recoil time and i-frame time
* `Fusion Hitbox.lua`: Hitbox viewer for Metroid Fusion. Supports room data, Samus, enemies and projectiles
* `RoS.lua`: Hitbox viewer for Metroid II. Supports room data and enemies.
* `Castlevania 2.lua`: Hitbox viewer for Castlevania II. Level data only. This one was the hardest hitbox viewer to make, Simon's Quest is weird.
* `Super charge shinespark.lua`: Requires `Super Metroid.lua`. Shows a rhythm game style chart on top of the HUD minimap to help learn the quick charge timing
* `smz3.lua`: BizHawk only. Simple script that lets the user take notes for the smz3 randomiser. Works via a text box whose text is persisted to disk and a dropdown for switching between areas
