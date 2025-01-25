local xemu = {}
xemu.emuId_bizhawk = 0
xemu.emuId_vba  = 1

-- Button bitmasks --
xemu.button_A      = 1
xemu.button_B      = 2
xemu.button_select = 4
xemu.button_start  = 8
xemu.button_right  = 0x10
xemu.button_left   = 0x20
xemu.button_up     = 0x40
xemu.button_down   = 0x80
xemu.button_R      = 0x100
xemu.button_L      = 0x200

if memory then
    if memory.usememorydomain then
        xemu.emuId = xemu.emuId_bizhawk
    elseif memory.readshort then
        xemu.emuId = xemu.emuId_vba
    end
else
    xemu.emuId = xemu.emuId_mesen
end

-- Bitwise operations
if xemu.emuId == xemu.emuId_mesen then
    -- [[
    xemu_mesen = require("cross emu - mesen")
    xemu.rshift = xemu_mesen.rshift
    xemu.lshift = xemu_mesen.lshift
    xemu.not_ = xemu_mesen.not_
    xemu.and_ = xemu_mesen.and_
    xemu.or_ = xemu_mesen.or_
    xemu.xor = xemu_mesen.xor
    --]]
else
    xemu.rshift = bit.rshift
    xemu.lshift = bit.lshift
    xemu.not_ = bit.bnot
    xemu.and_ = bit.band
    xemu.or_ = bit.bor
    xemu.xor = bit.bxor
end

-- Define memory access functions
if xemu.emuId == xemu.emuId_bizhawk then
    function makeMemoryReader(f)
        return function(p)
            if p >= 0x08000000 then
                return f(xemu.and_(p, 0x07FFFFFF), "ROM")
            elseif p >= 0x03000000 then
                return f(xemu.and_(p, 0x7FFF), "IWRAM")
            else
                return f(xemu.and_(p, 0x3FFFF), "EWRAM")
            end
        end
    end

    function makeMemoryWriter(f)
        return function(p, v)
            if p >= 0x08000000 then
                print(string.format('Error: trying to write to ROM address %X', p))
            elseif p >= 0x03000000 then
                return f(xemu.and_(p, 0x7FFF), v, "IWRAM")
            else
                return f(xemu.and_(p, 0x3FFFF), v, "EWRAM")
            end
        end
    end

    xemu.read_u8      = makeMemoryReader(memory.read_u8)
    xemu.read_u16_le  = makeMemoryReader(memory.read_u16_le)
    xemu.read_s8      = makeMemoryReader(memory.read_s8)
    xemu.read_s16_le  = makeMemoryReader(memory.read_s16_le)
    xemu.write_u8     = makeMemoryWriter(memory.write_u8)
    xemu.write_u16_le = makeMemoryWriter(memory.write_u16_le)
elseif xemu.emuId == xemu.emuId_vba then
    xemu.read_u8      = memory.readbyte
    xemu.read_u16_le  = memory.readshort
    xemu.read_s8      = memory.readbytesigned
    xemu.read_s16_le  = memory.readshortsigned
    xemu.write_u8     = memory.writebyte
    xemu.write_u16_le = memory.writeshort
else -- xemu.emuId == xemu.emuId_mesen
    -- Unknown what emu.memType will need to be used
    function makeMemoryReader(f, isSigned)
        return function(p)
            if p >= 0x08000000 then
                return f(p, emu.memType.prgRom, isSigned)
            else
                return f(p, emu.memType.workRam, isSigned)
            end
        end
    end

    function makeMemoryWriter(f)
        return function(p, v)
            if p >= 0x08000000 then
                print(string.format('Error: trying to write to ROM address %X', p))
            else
                return f(xemu.and_(p, 0x3FFFF), v, emu.memType.workRam)
            end
        end
    end

    xemu.read_u8      = makeMemoryReader(emu.read, false)
    xemu.read_u16_le  = makeMemoryReader(emu.readWord, false)
    xemu.read_s8      = makeMemoryReader(emu.read, true)
    xemu.read_s16_le  = makeMemoryReader(emu.readWord, true)
    xemu.write_u8     = makeMemoryWriter(emu.write)
    xemu.write_u16_le = makeMemoryWriter(emu.writeWord)
end

-- GUI functions
if xemu.emuId == xemu.emuId_bizhawk then
    xemu.drawPixel = function(x, y, fg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(xemu.and_(fg, 0xFF), 0x18)
        end
        
        gui.drawPixel(x, y, fg)
    end
    
    xemu.drawBox = function(x0, y0, x1, y1, fg, bg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(xemu.and_(fg, 0xFF), 0x18)
        end
        if bg ~= nil and type(bg) ~= "string" then
            bg = xemu.rshift(bg, 8) + xemu.lshift(xemu.and_(bg, 0xFF), 0x18)
        end
        
        gui.drawBox(x0, y0, x1, y1, fg, bg)
    end
    
    xemu.drawLine = function(x0, y0, x1, y1, fg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(xemu.and_(fg, 0xFF), 0x18)
        end
        
        gui.drawLine(x0, y0, x1, y1, fg)
    end
    
    xemu.drawText = function(x, y, text, fg, bg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(xemu.and_(fg, 0xFF), 0x18)
        end
        if bg ~= nil and type(bg) ~= "string" then
            bg = xemu.rshift(bg, 8) + xemu.lshift(xemu.and_(bg, 0xFF), 0x18)
        end
        
        gui.pixelText(x, y, text, fg, bg)
    end
elseif xemu.emuId == xemu.emuId_vba then
    xemu.drawPixel = function(x, y, fg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = string.format("#%08X", fg)
        end
        
        gui.pixel(x, y, fg)
    end
    
    xemu.drawBox = function(x0, y0, x1, y1, fg, bg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = string.format("#%08X", fg)
        end
        if bg ~= nil and type(bg) ~= "string" then
            bg = string.format("#%08X", bg)
        end
        
        gui.box(x0, y0, x1, y1, bg or 0, fg)
    end
    
    xemu.drawLine = function(x0, y0, x1, y1, fg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = string.format("#%08X", fg)
        end
        
        gui.line(x0, y0, x1, y1, fg)
    end
    
    xemu.drawText = function(x, y, text, fg, bg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = string.format("#%08X", fg)
        end
        if bg ~= nil and type(bg) ~= "string" then
            bg = string.format("#%08X", bg)
        end
        
        gui.text(x, y, text, fg, bg)
    end
else -- xemu.emuId == xemu.emuId_mesen
    function decodeColour(colour)
        if colour == nil then
            return nil
        end
        
        if type(colour) == "string" then
            if colour == "red" then
                return 0xFF0000
            elseif colour == "orange" then
                return 0x808000
            elseif colour == "yellow" then
                return 0xFFFF00
            elseif colour == "white" then
                return 0xFFFFFF
            elseif colour == "black" then
                return 0x000000
            elseif colour == "green" then
                return 0x00FF00
            elseif colour == "purple" then
                return 0xFF00FF
            elseif colour == "cyan" then
                return 0x00FFFF
            elseif colour == "blue" then
                return 0x0000FF
            elseif colour == "clear" then
                return 0xFF000000
            else
                print(string.format("Colour = %s", colour))
                return
            end
        end

        return xemu.and_(colour, 0xFFFFFF)
    end
    
    xemu.drawPixel = function(x, y, fg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(0xFF - xemu.and_(fg, 0xFF), 0x18)
        end
        
        emu.drawPixel(x, y + 7, decodeColour(fg))
    end
    
    xemu.drawBox = function(x0, y0, x1, y1, fg, bg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(0xFF - xemu.and_(fg, 0xFF), 0x18)
        end
        if bg ~= nil and type(bg) ~= "string" then
            bg = xemu.rshift(bg, 8) + xemu.lshift(0xFF - xemu.and_(bg, 0xFF), 0x18)
        end
        
        emu.drawRectangle(x0, y0 + 6, x1 - x0 + 1, y1 - y0 + 1, decodeColour(fg), bg == fg)
    end
    
    xemu.drawLine = function(x0, y0, x1, y1, fg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(0xFF - xemu.and_(fg, 0xFF), 0x18)
        end
        
        emu.drawLine(x0, y0 + 6, x1, y1 + 6, decodeColour(fg))
    end
    
    xemu.drawText = function(x, y, text, fg, bg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(0xFF - xemu.and_(fg, 0xFF), 0x18)
        end
        if bg ~= nil and type(bg) ~= "string" then
            bg = xemu.rshift(bg, 8) + xemu.lshift(0xFF - xemu.and_(bg, 0xFF), 0x18)
        end
        
        emu.drawString(x, y + 7, text, decodeColour(fg), decodeColour(bg))
    end
end

-- Run function
if xemu.emuId == xemu.emuId_mesen then
    xemu.run = function(main)
        emu.addEventCallback(main, emu.eventType.nmi)
    end
elseif xemu.emuId == xemu.emuId_bizhawk then
    xemu.run = event.onframestart
elseif xemu.emuId == xemu.emuId_vba then
    xemu.run = vba.registerbefore
else
    xemu.run = function(main)
        while true do
            main()
            emu.frameadvance()
        end
    end
end


return xemu
