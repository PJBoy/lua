xemu = require("cross emu")

console.clear()
gui.clearGraphics()

irq_no = 0
irq_begin = 1
irq_end = 2

colour_irq     = 0xFFFFFF80
colour_system  = 0x80808080
colour_enemy   = 0xFF000080
colour_samus   = 0x00FFFF80
colour_sprites = 0x0000FF80

-- Globals
interestPoints = {
    {address = 0x009583, colour = colour_irq,     irq = irq_begin, label = "NMI"},
    {address = 0x809601,                          irq = irq_end,   label = "NMI end"},
    {address = 0x00986A, colour = colour_irq,     irq = irq_begin, label = "IRQ"},
    {address = 0x80988A,                          irq = irq_end,   label = "IRQ end"},
    {address = 0x82897A, colour = 0x00000080,     irq = irq_no, label = "Wait for NMI"},
    {address = 0x82893D, colour = colour_system,  irq = irq_no, label = "Main game loop"},
    {address = 0x82897E, colour = colour_system,  irq = irq_no, label = "Main game loop"},
    {address = 0xA08EB6, colour = colour_enemy,   irq = irq_no, label = "Determine which enemies to process"},
    {address = 0xB49809, colour = colour_system,  irq = irq_no, label = "Debug handler"},
    {address = 0x8DC527, colour = colour_system,  irq = irq_no, label = "Palette FX object handler"},
    {address = 0x90E692, colour = colour_samus,   irq = irq_no, label = "JSR ($0A42)"},
    {address = 0xA09785, colour = colour_samus,   irq = irq_no, label = "Samus / projectile interaction handler"},
    {address = 0xA08FD4, colour = colour_enemy,   irq = irq_no, label = "Main enemy routine"},
    {address = 0x90E722, colour = colour_samus,   irq = irq_no, label = "JSR ($0A44)"},
    {address = 0x868104, colour = colour_enemy,   irq = irq_no, label = "Enemy projectile handler"},
    {address = 0x8485B4, colour = colour_system,  irq = irq_no, label = "PLM handler"},
    {address = 0x878064, colour = colour_system,  irq = irq_no, label = "Animated tiles objects handler"},
    {address = 0xA09894, colour = colour_enemy,   irq = irq_no, label = "Enemy projectile / Samus collision detection"},
    {address = 0xA0996C, colour = colour_enemy,   irq = irq_no, label = "Enemy projectile / projectile detection"},
    {address = 0xA0A306, colour = colour_enemy,   irq = irq_no, label = "Process enemy power bomb interaction"},
    {address = 0x9094EC, colour = colour_system,  irq = irq_no, label = "Main scrolling routine"},
    {address = 0xA0884D, colour = colour_sprites, irq = irq_no, label = "Draw Samus, projectiles, enemies and enemy projectiles"},
    {address = 0x868390, colour = colour_enemy,   irq = irq_no, label = "Draw low priority enemy projectiles"},
    {address = 0x90EB35, colour = colour_samus,   irq = irq_no, label = "Draw Samus and projectiles"},
    {address = 0xA08875, colour = colour_enemy,   irq = irq_no, label = "Draw Samus and projectiles end"},
    {address = 0xA09726, colour = colour_enemy,   irq = irq_no, label = "Handle queuing enemy BG2 tilemap VRAM transfer"},
    {address = 0x809B44, colour = colour_system,  irq = irq_no, label = "Handle HUD tilemap"},
    {address = 0x80A3AB, colour = colour_system,  irq = irq_no, label = "Calculate layer 2 position and BG scrolls and update BG graphics when scrolling"},
    {address = 0x8FE8BD, colour = colour_system,  irq = irq_no, label = "Execute room main ASM"},
    {address = 0x82DB69, colour = colour_samus,   irq = irq_no, label = "Handle Samus running out of health and increment game time"},
    {address = 0xA08687, colour = colour_system,  irq = irq_no, label = "Handle room shaking"},
    {address = 0xA09169, colour = colour_system,  irq = irq_no, label = "Decrement Samus hurt timers and clear active enemy indices"},
    {address = 0x828BB7, colour = colour_system,  irq = irq_no, label = "Main gameplay end"},
}

colour = 0
colour_old = 0

drawQueue = {}

function drawWrapped(x_from, y_from, x_to, y_to, colour, label)
    --console.log(string.format('(%3d, %3d) -> (%3d, %3d) - %08X %s', x_from, y_from, x_to, y_to, colour, label))
    if y_from == y_to then
        xemu.drawLine(x_from, y_from, x_to, y_to, colour)
    else
        xemu.drawLine(x_from, y_from, 341, y_from, colour)
        if y_to < y_from then
            xemu.drawBox(0, y_from+1, 341, 262, colour, colour)
            y_from = -1
        end
        
        xemu.drawBox(0, y_from+1, 341, y_to-1, colour, colour)
        xemu.drawLine(0, y_to, x_to, y_to, colour)
    end
end

function init()
    client.SetGameExtraPadding(0, 0, 341-256, 262-224)

    for i, point in ipairs(interestPoints) do
        event.onmemoryexecute(function()
            local x = emu.getregister('H')
            local y = emu.getregister('V')
            if point.irq == irq_begin then
                colour_old = colour
                colour = point.colour
            elseif point.irq == irq_end then
                colour = colour_old
            else
                colour = point.colour
            end
            
            drawQueue[#drawQueue+1] = {x = x, y = y, colour = colour, label = point.label}
        end, point.address)
    end
end


function on_paint()
    if #drawQueue ~= 0 then
        for i = 1, #drawQueue-1 do
            drawWrapped(drawQueue[i].x, drawQueue[i].y, drawQueue[i+1].x, drawQueue[i+1].y, drawQueue[i].colour, drawQueue[i].label)
        end
        
        local i = #drawQueue
        local x_to = emu.getregister('H')
        local y_to = emu.getregister('V')
        drawWrapped(drawQueue[i].x, drawQueue[i].y, x_to, y_to, drawQueue[i].colour, drawQueue[i].label)
        drawQueue = {}
    end
end

init()
while true do
    on_paint()
    emu.frameadvance()
end
