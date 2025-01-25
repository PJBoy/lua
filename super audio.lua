local xemu = require("cross emu")
local sm = require("Super Metroid")

console.clear()

-- Extra GUI
if xemu.emuId == xemu.emuId_bizhawk then
    forms.destroyall()

    local x = 0
    local y = 0
    local width = 500
    local height = 480
    local fixedWidth = true
    local boxType = nil
    local multiline = true
    local scrollbars = "both"
    
    superform_sound1 = forms.newform(width, height, "ARAM - sound 1")
    superform_sound2 = forms.newform(width, height, "ARAM - sound 2")
    superform_sound3 = forms.newform(width, height, "ARAM - sound 3")
    form_sound1 = forms.label(superform_sound1, "", x, y, width, height, fixedWidth)
    form_sound2 = forms.label(superform_sound2, "", x, y, width, height, fixedWidth)
    form_sound3 = forms.label(superform_sound3, "", x, y, width, height, fixedWidth)
    
    width = 708
    height = 480
    superform_sound1Tracker = forms.newform(width, height, "ARAM - sound 1 tracker")
    superform_sound2Tracker = forms.newform(width, height, "ARAM - sound 2 tracker")
    superform_sound3Tracker = forms.newform(width, height, "ARAM - sound 3 tracker")
    -- int forms.textbox(int formhandle, [string caption = null], [int? width = null], [int? height = null], [string boxtype = null],
    --     [int? x = null], [int? y = null], [bool multiline = False], [bool fixedwidth = False], [string scrollbars = null])
    form_sound1tracker = forms.textbox(superform_sound1Tracker, "", width, height, boxType, x, y, multiline, fixedWidth, scrollbars)
    form_sound2tracker = forms.textbox(superform_sound2Tracker, "", width, height, boxType, x, y, multiline, fixedWidth, scrollbars)
    form_sound3tracker = forms.textbox(superform_sound3Tracker, "", width, height, boxType, x, y, multiline, fixedWidth, scrollbars)
end

function updateForm_sound(form, i_sound, n_voices)
    local soundInstructionListPointers = {}
    for i = 0, n_voices - 1 do
        soundInstructionListPointers[i] = sm.getAram_sound_p_instructionList(i_sound)(i)()
    end
    
    local soundAdsrSettings = {}
    for i = 0, n_voices - 1 do
        soundAdsrSettings[i] = sm.getAram_sound_adsrSettings(i_sound)(i)
    end

    local text_soundInstructionListPointers           = "Instruction list pointers:             "
    local text_soundInstructionListIndices            = "Instruction list indices:              "
    local text_soundInstructionListTimers             = "Instruction list timers:               "
    local text_soundDisableBytes                      = "Disable bytes:                         "
    local text_soundVoiceBitsets                      = "Voice bitsets:                         "
    local text_soundVoiceMasks                        = "Voice masks:                           "
    local text_soundVoiceIndices                      = "Voice indices:                         "
    local text_soundDspIndices                        = "DSP indices:                           "
    local text_soundTrackOutputVolumeBackups          = "Track output volume backups:           "
    local text_soundTrackPhaseInversionOptionsBackups = "Track phase inversion options backups: "
    local text_soundReleaseFlags                      = "Release flags:                         "
    local text_soundReleaseTimers                     = "Release timers:                        "
    local text_soundRepeatCounters                    = "Repeat counters:                       "
    local text_soundRepeatPoints                      = "Repeat points:                         "
    local text_soundAdsrSettings                      = "ADSR settings:                         "
    local text_soundUpdateAdsrSettingsFlags           = "Update ADSR settings flags:            "
    local text_soundNotes                             = "Notes:                                 "
    local text_soundSubnotes                          = "Subnotes:                              "
    local text_soundSubnoteDeltas                     = "Subnote deltas:                        "
    local text_soundTargetNotes                       = "Target notes:                          "
    local text_soundPitchSlideFlags                   = "Pitch slide flags:                     "
    local text_soundLegatoFlags                       = "Legato flags:                          "
    local text_soundPitchSlideLegatoFlags             = "Pitch slide legato flags:              "

    local separator = ""
    for i = 0, n_voices - 1 do
        text_soundInstructionListPointers           = text_soundInstructionListPointers           .. separator .. string.format("$%04X", soundInstructionListPointers[i])
        text_soundInstructionListIndices            = text_soundInstructionListIndices            .. separator .. string.format("% 4Xh", sm.getAram_sound_i_instructionLists(i_sound)(i))
        text_soundInstructionListTimers             = text_soundInstructionListTimers             .. separator .. string.format("% 4Xh", sm.getAram_sound_instructionTimers(i_sound)(i))
        text_soundDisableBytes                      = text_soundDisableBytes                      .. separator .. string.format("% 4Xh", sm.getAram_sound_disableBytes(i_sound)(i))
        text_soundVoiceBitsets                      = text_soundVoiceBitsets                      .. separator .. string.format("% 4Xh", sm.getAram_sound_voiceBitsets(i_sound)(i))
        text_soundVoiceMasks                        = text_soundVoiceMasks                        .. separator .. string.format("% 4Xh", sm.getAram_sound_voiceMasks(i_sound)(i))
        text_soundVoiceIndices                      = text_soundVoiceIndices                      .. separator .. string.format("% 4Xh", sm.getAram_sound_voiceIndices(i_sound)(i))
        text_soundDspIndices                        = text_soundDspIndices                        .. separator .. string.format("% 4Xh", sm.getAram_sound_dspIndices(i_sound)(i))
        text_soundTrackOutputVolumeBackups          = text_soundTrackOutputVolumeBackups          .. separator .. string.format("% 4Xh", sm.getAram_sound_trackOutputVolumeBackups(i_sound)(i))
        text_soundTrackPhaseInversionOptionsBackups = text_soundTrackPhaseInversionOptionsBackups .. separator .. string.format("% 4Xh", sm.getAram_sound_trackPhaseInversionOptionsBackups(i_sound)(i))
        text_soundReleaseFlags                      = text_soundReleaseFlags                      .. separator .. string.format("% 4Xh", sm.getAram_sound_releaseFlags(i_sound)(i))
        text_soundReleaseTimers                     = text_soundReleaseTimers                     .. separator .. string.format("% 4Xh", sm.getAram_sound_releaseTimers(i_sound)(i))
        text_soundRepeatCounters                    = text_soundRepeatCounters                    .. separator .. string.format("% 4Xh", sm.getAram_sound_repeatCounters(i_sound)(i))
        text_soundRepeatPoints                      = text_soundRepeatPoints                      .. separator .. string.format("% 4Xh", sm.getAram_sound_repeatPoints(i_sound)(i))
        text_soundAdsrSettings                      = text_soundAdsrSettings                      .. separator .. string.format("% 4Xh", soundAdsrSettings[i])
        text_soundUpdateAdsrSettingsFlags           = text_soundUpdateAdsrSettingsFlags           .. separator .. string.format("% 4Xh", sm.getAram_sound_updateAdsrSettingsFlags(i_sound)(i))
        text_soundNotes                             = text_soundNotes                             .. separator .. string.format("% 4Xh", sm.getAram_sound_notes(i_sound)(i))
        text_soundSubnotes                          = text_soundSubnotes                          .. separator .. string.format("% 4Xh", sm.getAram_sound_subnotes(i_sound)(i))
        text_soundSubnoteDeltas                     = text_soundSubnoteDeltas                     .. separator .. string.format("% 4Xh", sm.getAram_sound_subnoteDeltas(i_sound)(i))
        text_soundTargetNotes                       = text_soundTargetNotes                       .. separator .. string.format("% 4Xh", sm.getAram_sound_targetNotes(i_sound)(i))
        text_soundPitchSlideFlags                   = text_soundPitchSlideFlags                   .. separator .. string.format("% 4Xh", sm.getAram_sound_pitchSlideFlags(i_sound)(i))
        text_soundLegatoFlags                       = text_soundLegatoFlags                       .. separator .. string.format("% 4Xh", sm.getAram_sound_legatoFlags(i_sound)(i))
        text_soundPitchSlideLegatoFlags             = text_soundPitchSlideLegatoFlags             .. separator .. string.format("% 4Xh", sm.getAram_sound_pitchSlideLegatoFlags(i_sound)(i))

        separator = " | "
    end

    forms.settext(form, ""
        .. string.format("Current sound %d:             %Xh\n",  i_sound + 1, sm.getAram_sound(i_sound)())
        .. string.format("Sound %d initialisation flag: %02X\n", i_sound + 1, sm.getAram_sound_initialisationFlag(i_sound)())
        .. string.format("Sound %d enabled voices:      %Xh\n",  i_sound + 1, sm.getAram_sound_enabledVoices(i_sound)())
        .. "\n"
        .. text_soundInstructionListPointers           .. "\n"
        .. text_soundInstructionListIndices            .. "\n"
        .. text_soundInstructionListTimers             .. "\n"
        .. text_soundDisableBytes                      .. "\n"
        .. text_soundVoiceBitsets                      .. "\n"
        .. text_soundVoiceMasks                        .. "\n"
        .. text_soundVoiceIndices                      .. "\n"
        .. text_soundDspIndices                        .. "\n"
        .. text_soundTrackOutputVolumeBackups          .. "\n"
        .. text_soundTrackPhaseInversionOptionsBackups .. "\n"
        .. text_soundReleaseFlags                      .. "\n"
        .. text_soundReleaseTimers                     .. "\n"
        .. text_soundRepeatCounters                    .. "\n"
        .. text_soundRepeatPoints                      .. "\n"
        .. text_soundAdsrSettings                      .. "\n"
        .. text_soundUpdateAdsrSettingsFlags           .. "\n"
        .. text_soundNotes                             .. "\n"
        .. text_soundSubnotes                          .. "\n"
        .. text_soundSubnoteDeltas                     .. "\n"
        .. text_soundTargetNotes                       .. "\n"
        .. text_soundPitchSlideFlags                   .. "\n"
        .. text_soundLegatoFlags                       .. "\n"
        .. text_soundPitchSlideLegatoFlags             .. "\n"
    )
    forms.refresh(form)
end

function updateForm_soundTracker(form, i_sound, n_voices)
    local text_legatoPitchSlide = "F5 %02X %02X       ; Legato pitch slide with subnote delta = %02Xh, target note = %02Xh\r\n"
    local text_pitchSlide       = "F8 %02X %02X       ; Pitch slide with subnote delta = %02Xh, target note = %02Xh\r\n"
    local text_adsr             = "F9 %04X        ; Voice ADSR settings = %04Xh\r\n"
    local text_repeat           = "FB             ; Repeat\r\n"
    local text_noise            = "FC             ; Enable noise\r\n"
    local text_maybeRepeat      = "FD             ; Decrement repeat counter and repeat if non-zero\r\n"
    local text_repeatPoint      = "FE %02X          ; Set repeat pointer with repeat counter = %Xh\r\n"
    local text_eof              = "FF             ; EOF\r\n"
    local text_note             = "%02X %02X %02X %02X %02X ; Instrument = % 2Xh, volume = % 2Xh, panning = % 2Xh, note = % 2Xh, length = % 2Xh\r\n"
    
    local text = ""
    for i_voice = 0, n_voices - 1 do
        text = text .. string.format("Sound %d voice %d:\r\n", i_sound, i_voice)
        local p_begin_soundInstructionList = sm.getAram_sound_p_instructionList(i_sound)(i_voice)()
        if sm.getAram_sound_disableBytes(i_sound)(i_voice) == 0xFF or p_begin_soundInstructionList == 0 then
            text = text .. "[disabled]\r\n"
        else
            local i_soundInstructionList = sm.getAram_sound_i_instructionLists(i_sound)(i_voice)
            local p_soundInstructionList = p_begin_soundInstructionList + i_soundInstructionList
            
            local i = 0
            while true do
                if i == i_soundInstructionList then
                    text = text .. "> "
                else
                    text = text .. "  "
                end
                
                text = text .. string.format("$%04X: ", p_begin_soundInstructionList + i)
                
                local command = xemu.read_aram_u8(p_begin_soundInstructionList + i)
                i = i + 1
                if command == 0xFF then
                    text = text .. text_eof
                    break
                elseif command == 0xF5 then
                    local delta = xemu.read_aram_u8(p_begin_soundInstructionList + i)
                    local note = xemu.read_aram_u8(p_begin_soundInstructionList + i + 1)
                    i = i + 2
                    text = text .. string.format(text_legatoPitchSlide, delta, note, delta, note)
                elseif command == 0xF8 then
                    local delta = xemu.read_aram_u8(p_begin_soundInstructionList + i)
                    local note = xemu.read_aram_u8(p_begin_soundInstructionList + i + 1)
                    i = i + 2
                    text = text .. string.format(text_pitchSlide, delta, note, delta, note)
                elseif command == 0xF9 then
                    local adsr = xemu.read_aram_u16_le(p_begin_soundInstructionList + i)
                    i = i + 2
                    text = text .. string.format(text_adsr, adsr, adsr)
                elseif command == 0xFB then
                    text = text .. text_repeat
                elseif command == 0xFC then
                    text = text .. text_noise
                elseif command == 0xFD then
                    text = text .. text_maybeRepeat
                elseif command == 0xFE then
                    local counter = xemu.read_aram_u8(p_begin_soundInstructionList + i)
                    i = i + 1
                    text = text .. string.format(text_repeatPoint, counter, counter)
                else
                    local i_instrument = command
                    local volume  = xemu.read_aram_u8(p_begin_soundInstructionList + i)
                    local panning = xemu.read_aram_u8(p_begin_soundInstructionList + i + 1)
                    local note    = xemu.read_aram_u8(p_begin_soundInstructionList + i + 2)
                    local length  = xemu.read_aram_u8(p_begin_soundInstructionList + i + 3)
                    i = i + 4
                    text = text .. string.format(text_note, i_instrument, volume, panning, note, length, i_instrument, volume, panning, note, length)
                end
            end
    
            if i == i_soundInstructionList then
                text = text .. ">\r\n"
            end

        end
        
        text = text .. "\r\n"
    end

    forms.settext(form, text)
    forms.refresh(form)
end

function extraGui()
    updateForm_sound(form_sound1, 0, 4)
    updateForm_sound(form_sound2, 1, 2)
    updateForm_sound(form_sound3, 2, 2)
    updateForm_soundTracker(form_sound1tracker, 0, 4)
    updateForm_soundTracker(form_sound2tracker, 1, 2)
    updateForm_soundTracker(form_sound3tracker, 2, 2)
end

while true do
    extraGui()
    emu.frameadvance()
end