-- TODO: Make different colours for different slots

DisplayTileData = 0
DisplayEnemyData = 1
DisplayRoomBoxes = 1
DisplaySamusBox = 1
DisplayProjectileBoxes = 1
DisplayEnemyBoxes = 1
EnemyHAdjust = 0
EnemyVAdjust = 0
AVISkipDoorTransitions = 0
AVIFullMapView = 0

while true do
	local CurrentInput = memory.readshort(0x30011E8)
	local ChangedInput = memory.readshort(0x30011EC)
	if AND(CurrentInput, 0x4) ~= 0 then	-- while holding Select
		DisplayTileData        = XOR(DisplayTileData,        AND(ChangedInput, 0x0001))	-- A pressed
		DisplayEnemyData       = XOR(DisplayEnemyData,       AND(ChangedInput, 0x0001))	-- A pressed
		DisplayRoomBoxes       = XOR(DisplayRoomBoxes,       SHIFT(AND(ChangedInput, 0x0002), 1))	-- B pressed
		DisplaySamusBox        = XOR(DisplaySamusBox,        SHIFT(AND(ChangedInput, 0x0200), 9))	-- L pressed
		DisplayProjectileBoxes = XOR(DisplayProjectileBoxes, SHIFT(AND(ChangedInput, 0x0200), 9))	-- L pressed
		DisplayEnemyBoxes      = XOR(DisplayEnemyBoxes,      SHIFT(AND(ChangedInput, 0x0100), 8))	-- R pressed
		EnemyHAdjust = EnemyHAdjust +       AND(ChangedInput, 0x0010)		-- Right pressed
		EnemyHAdjust = EnemyHAdjust - SHIFT(AND(ChangedInput, 0x0020), 1)	-- Left pressed
		EnemyVAdjust = EnemyVAdjust - SHIFT(AND(ChangedInput, 0x0040), 2)	-- Up pressed
		EnemyVAdjust = EnemyVAdjust + SHIFT(AND(ChangedInput, 0x0080), 3)	-- Down pressed
	end
	
	-- This function draws boxes around blocks of different colours, corrosponding to a property of the block:
	--	Red: Standard solid block
	--	Purple: Unused block (just incase)
	--	Orange: Blocks of interest (items and doors)
	-- And display the data about the tile (its clipdata); Red for normal blocks, Orange for >= 0x8000 blocks
	if DisplayRoomBoxes ~= 0 then
		local cameraX, cameraY = SHIFT(memory.readshort(0x3000124), 2), SHIFT(memory.readshort(0x3000128), 2)
		-- these are the co-ordinates of the top-left of the screen measured in quarter pixels (thus divided by 4)
		local width = memory.readshort(0x30000A0)
		-- this is how wide the room is in blocks
		local tile = 0x2026000 + SHIFT(SHIFT(cameraX, 4) + SHIFT(cameraY, 4)*width, -1)
		-- 0x02026000 is the start of clipdata
		-- each block is a 16x16 (thus the camera is divided by 16)
		-- each block's clipdata is a half-word (thus camera is shifted left)
		outline = {
			[0x00] = function ()
				 end, -- Air
			[0x01] = function ()
					gui.box(TileX, TileY, TileX+15, TileY+15, "clear", "red")
				 end, -- Normal block
			[0x02] = function ()
					gui.line(TileX, TileY, TileX+15, TileY+15, "red")
					gui.line(TileX, TileY+15, TileX+15, TileY+15, "red")
					gui.line(TileX, TileY, TileX, TileY+15, "red")
				 end, -- 45° down-right slope
			[0x03] = function ()
					gui.line(TileX, TileY+15, TileX+15, TileY, "red")
					gui.line(TileX, TileY+15, TileX+15, TileY+15, "red")
					gui.line(TileX+15, TileY, TileX+15, TileY+15, "red")
				 end, -- 45° down-left slope
			[0x04] = function ()
					gui.line(TileX, TileY, TileX+15, TileY+7, "red")
					gui.line(TileX, TileY+15, TileX+15, TileY+15, "red")
					gui.line(TileX, TileY, TileX, TileY+15, "red")
				 end, -- Higher 22.5° down-right slope
			[0x05] = function ()
					gui.line(TileX, TileY+8, TileX+15, TileY+15, "red")
					gui.line(TileX, TileY+15, TileX+15, TileY+15, "red")
					gui.line(TileX, TileY+8, TileX, TileY+15, "red")
				 end, -- Lower 22.5° down-right slope
			[0x06] = function ()
					gui.line(TileX, TileY+15, TileX+15, TileY+8, "red")
					gui.line(TileX, TileY+15, TileX+15, TileY+15, "red")
					gui.line(TileX+15, TileY+8, TileX+15, TileY+15, "red")
				 end, -- Lower 22.5° down-left slope
			[0x07] = function ()
					gui.line(TileX, TileY+7, TileX+15, TileY, "red")
					gui.line(TileX, TileY+15, TileX+15, TileY+15, "red")
					gui.line(TileX+15, TileY, TileX+15, TileY+15, "red")
				 end, -- Higher 22.5° down-left slope
			[0x08] = function ()
					gui.box(TileX, TileY, TileX+15, TileY+15, "clear", "purple")
				 end,
			[0x09] = function ()
				 end, -- Transition blocks
			[0x0A] = function ()
					gui.box(TileX, TileY, TileX+15, TileY+15, "clear", "orange")
				 end, -- Items
			[0x0B] = function ()
					gui.box(TileX, TileY, TileX+15, TileY+15, "clear", "orange")
				 end, -- Door blocks
			[0x0C] = function ()
					gui.box(TileX, TileY, TileX+15, TileY+15, "clear", "purple")
				 end
		}
		
		for y=0,10 do
			for x=0,16 do
				TileX, TileY = x*16 - AND(cameraX, 0x000F), y*16 - AND(cameraY, 0x000F)
				-- this if for pixel-aligning the grid, because the screen doesn't just scroll per block!
				local b = memory.readshort(tile + SHIFT(x + y*width, -1))
				-- this gets the block's clipdata
				local a
				if b < 0x8000 then
					a = memory.readbyte(0x83F0834 + b)
					if DisplayTileData ~= 0 then
						gui.text(TileX+4, TileY+4, string.format("%02X",b), "red")
					end
				else
					b = AND(b, 0x7FFF)
					a = memory.readbyte(0x83BF5C0 + b)
					if DisplayTileData ~= 0 then
						gui.text(TileX+4, TileY+4, string.format("%02X",b), "orange")
					end
				end
				-- this gets the block's hitbox index
				outline[a]()
			end
		end
	end

	local cameraX, cameraY = memory.readshort(0x3000124), memory.readshort(0x3000128)
	-- these are the co-ordinates of the top-left of the screen measured in quarter pixels
	
	-- This function displays the hitbox of all the enemies in the room, as well as their health (as text and a bar)
	if DisplayEnemyBoxes ~= 0 then
		for i=0,23 do
			if memory.readshort(0x3000140 + i*56) ~= 0 then
				local enemyX, enemyY = memory.readshort(0x3000144 + i*56), memory.readshort(0x3000142 + i*56)
				local topleft = {(enemyX + memory.readshortsigned(0x300014E + i*56) - cameraX)/4, (enemyY + memory.readshortsigned(0x300014A + i*56) - cameraY)/4}
				local bottomright = {(enemyX + memory.readshortsigned(0x3000150 + i*56) - cameraX)/4, (enemyY + memory.readshortsigned(0x300014C + i*56) - cameraY)/4}
				gui.box(topleft[1], topleft[2], bottomright[1], bottomright[2], "clear", "#808080")
				-- draw enemy hitbox
				
				if DisplayEnemyData ~= 0 then
					gui.text(topleft[1] + EnemyHAdjust, topleft[2]-32 + EnemyVAdjust, "Slot:" .. string.format("%02X",i) .. "\nID: " .. string.format("%02X",memory.readbyte(0x300015D + i*56)), "#808080")
					--gui.text(topleft[1] + EnemyHAdjust, topleft[2]-24 + EnemyVAdjust, string.format("%02X",memory.readbyte(0x3000140 + i*56)) .. "\n" .. string.format("%01X",memory.readbyte(0x3000174 + i*56)), "#808080")
				end
				
				local enemyhealth = memory.readshort(0x3000154 + i*56)
				local enemyspawnhealth = memory.readshort(0x82E4D4C + memory.readbyte(0x300015D + i*56)*14)
				if enemyspawnhealth ~= 0 then
					gui.text(topleft[1], topleft[2]-16, enemyhealth .. "/" .. enemyspawnhealth, "#808080")
					-- show enemy health
					if enemyhealth < enemyspawnhealth then
						gui.box(topleft[1], topleft[2]-8, topleft[1] + enemyhealth/enemyspawnhealth*32, topleft[2]-5, "#606060")
						gui.box(topleft[1], topleft[2]-8, topleft[1] + 32, topleft[2]-5, "clear", "#808080")
						-- draw enemy health bar
					end
				end
			end
		end
	end
	-- This function displays Samus' hitbox, as well as her arm cannon point and cooldown time
	if DisplaySamusBox ~= 0 then
		do
			local samusX, samusY = memory.readshort(0x300125A), memory.readshort(0x300125C)
			local armcannonX, armcannonY = (memory.readshort(0x3000B82) - cameraX - 2)/4, (memory.readshort(0x3000B80)-cameraY - 2)/4
			local topleft = {(samusX + memory.readshortsigned(0x3001268) - cameraX - 2)/4, (samusY + memory.readshortsigned(0x300126A) - cameraY - 2)/4}
			local bottomright = {(samusX + memory.readshortsigned(0x300126C) - cameraX - 2)/4, (samusY + memory.readshortsigned(0x300126E) - cameraY - 2)/4}
			gui.box(topleft[1], topleft[2], bottomright[1], bottomright[2], "clear", "#80FFFF")
			-- draw Samus' hitbox
			gui.box(armcannonX-1, armcannonY-1, armcannonX+1, armcannonY+1, "green")
			-- draw arm cannon point
			
			local cooldown = memory.readbyte(0x300124E)
			if cooldown ~= 0 then
				gui.text(armcannonX-1, armcannonY-9, cooldown, "green")
			end
			-- show current cooldown time
		end
	end
	
	-- This function displays the hitbox of all of Samus' projectiles in the room, as well as their damage
	if DisplayProjectileBoxes ~= 0 then
	    pdamage = {2, 2, 3, 3, nil, nil, 10, 15, 9, nil, 10, 30, 40, 45, 45, nil, 8, 50, 1}
		for i=0,15 do
			if memory.readshort(0x3000960 + i*32) ~= 0 then
				local projectileX, projectileY = memory.readshort(0x300096A + i*32), memory.readshort(0x3000968 + i*32)
				topleft = {(projectileX + memory.readshortsigned(0x300097A + i*32) - cameraX - 2)/4, (projectileY + memory.readshortsigned(0x3000976 + i*32) - cameraY - 2)/4}
				local bottomright = {(projectileX + memory.readshortsigned(0x300097C + i*32) - cameraX - 2)/4, (projectileY + memory.readshortsigned(0x3000978 + i*32) - cameraY - 2)/4}
				gui.box(topleft[1], topleft[2], bottomright[1], bottomright[2], "clear", "#FFFF80")
				-- draw projectile hitbox
				
				local projectiletype = memory.readbyte(0x300096F + i*32)
				local beam = memory.readbyte(0x300131A)
				local projectiledamage
				if projectiletype == 0x04 then		-- Uncharged beam
					if AND(beam, 0x10) then		-- Ice
						projectiledamage = 6
					else				-- All others
						projectiledamage = 3
					end
				elseif projectiletype == 0x09 then	-- Charge beam
					if AND(beam, 0x10) then		-- Ice
						projectiledamage = 12
					else				-- All others
						projectiledamage = 9
					end
				elseif projectiletype == 0x0F then	-- Flare damage
					if AND(beam, 0x18) then		-- Wave/Ice
						projectiledamage = 15
					elseif AND(beam, 0x04) then	-- Plasma
						projectiledamage = 12
					elseif AND(beam, 0x02) then	-- Wide
						projectiledamage = 9
					else				-- Charge
						projectiledamage = 6
					end
				else
					projectiledamage = pdamage[projectiletype+1]	-- All others
				end
				gui.text(topleft[1], topleft[2]-8, projectiledamage, "#FFFF80")
				-- show projectile damage
			end
		end
	end
	
	-- This function pauses AVI recording during periods of no gameplay
	if AVISkipDoorTransitions ~= 0 then
		if memory.readbyte(0x03000BDE) ~= 0001 or memory.readbyte(0x03000BE0) ~= 0002 then
			avi.pause()
		else
			avi.resume()
		end
	end
	
	-- This function assists my full map view AVI recording
	if AVIFullMapView ~= 0 then
		--memory.writeshort(cameraX, cameraX - cameraX % 960)
		--memory.writeshort(cameraY, cameraY - cameraY % 640)
	end
        
	vba.frameadvance()
end