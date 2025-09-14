local xemu = require("cross emu")
local sm = require("Super Metroid")

if xemu.emuId ~= xemu.emuId_bizhawk then
    if console and console.log then
        console.log("Need BizHawk")
    elseif print then
        print("Need BizHawk")
    end
    
    return
end

console.clear()
forms.destroyall()

if memory.getmemorydomainsize("APURAM") == memory.getcurrentmemorydomainsize() then
    console.log('No "APURAM" memory domain, you might be using the snes9x core')
    console.log('Available memory domains:')
    for k,v in pairs(memory.getmemorydomainlist()) do
        console.log(string.format('%X - %-10s - %Xh bytes', k, v, memory.getmemorydomainsize(v)))
    end
end

local soundNames = {
    {
        [1] = "Power bomb explosion",
        [2] = "Silence",
        [3] = "Missile",
        [4] = "Super missile",
        [5] = "Grapple start",
        [6] = "Grappling",
        [7] = "Grapple end",
        [8] = "Charging beam",
        [9] = "X-ray",
        [0xA] = "X-ray end",
        [0xB] = "Uncharged power beam",
        [0xC] = "Uncharged ice beam",
        [0xD] = "Uncharged wave beam",
        [0xE] = "Uncharged ice + wave beam",
        [0xF] = "Uncharged spazer beam",
        [0x10] = "Uncharged spazer + ice beam",
        [0x11] = "Uncharged spazer + ice + wave beam",
        [0x12] = "Uncharged spazer + wave beam",
        [0x13] = "Uncharged plasma beam",
        [0x14] = "Uncharged plasma + ice beam",
        [0x15] = "Uncharged plasma + ice + wave beam",
        [0x16] = "Uncharged plasma + wave beam",
        [0x17] = "Charged power beam",
        [0x18] = "Charged ice beam",
        [0x19] = "Charged wave beam",
        [0x1A] = "Charged ice + wave beam",
        [0x1B] = "Charged spazer beam",
        [0x1C] = "Charged spazer + ice beam",
        [0x1D] = "Charged spazer + ice + wave beam",
        [0x1E] = "Charged spazer + wave beam",
        [0x1F] = "Charged plasma beam / hyper beam",
        [0x20] = "Charged plasma + ice beam",
        [0x21] = "Charged plasma + ice + wave beam",
        [0x22] = "Charged plasma + wave beam / post-credits Samus shoots screen",
        [0x23] = "Ice SBA",
        [0x24] = "Ice SBA end",
        [0x25] = "Spazer SBA",
        [0x26] = "Spazer SBA end",
        [0x27] = "Plasma SBA",
        [0x28] = "Wave SBA",
        [0x29] = "Wave SBA end",
        [0x2A] = "Selected save file",
        [0x2B] = "(Empty)",
        [0x2C] = "(Empty)",
        [0x2D] = "(Empty)",
        [0x2E] = "Saving",
        [0x2F] = "Underwater space jump",
        [0x30] = "Resumed spin jump",
        [0x31] = "Spin jump",
        [0x32] = "Spin jump end",
        [0x33] = "Screw attack",
        [0x34] = "Screw attack end",
        [0x35] = "High priority. Samus damaged",
        [0x36] = "Scrolling map",
        [0x37] = "Moved cursor / toggle reserve mode",
        [0x38] = "Menu option selected",
        [0x39] = "Switch HUD item",
        [0x3A] = "(Empty)",
        [0x3B] = "Hexagon map -> square map transition",
        [0x3C] = "Square map -> hexagon map transition",
        [0x3D] = "Dud shot",
        [0x3E] = "Space jump",
        [0x3F] = "Unused. Resumed space jump",
        [0x40] = "High priority. Mother Brain's rainbow beam",
        [0x41] = "Resume charging beam",
        [0x42] = "Unused"
    },
    {
        [1] = "High priority. Collected small health drop",
        [2] = "High priority. Collected big health drop",
        [3] = "High priority. Collected missile drop",
        [4] = "High priority. Collected super missile drop",
        [5] = "High priority. Collected power bomb drop",
        [6] = "Block destroyed by contact damage",
        [7] = "(Super) missile hit wall",
        [8] = "Bomb explosion",
        [9] = "Enemy killed",
        [0xA] = "Block crumbled",
        [0xB] = "Enemy killed by contact damage",
        [0xC] = "Beam hit wall / torizo statue crumbles",
        [0xD] = "Splashed into water",
        [0xE] = "Splashed out of water",
        [0xF] = "Low pitched air bubbles",
        [0x10] = "Lava/acid damaging Samus",
        [0x11] = "High pitched air bubbles",
        [0x12] = "Lava bubbling 1",
        [0x13] = "Lava bubbling 2",
        [0x14] = "Lava bubbling 3",
        [0x15] = "Maridia elevatube",
        [0x16] = "High priority. Fake Kraid cry",
        [0x17] = "High priority. Morph ball eye's ray",
        [0x18] = "Beacon",
        [0x19] = "Tourian statue unlocking particle",
        [0x1A] = "n00b tube shattering",
        [0x1B] = "Spike platform stops / tatori hits wall",
        [0x1C] = "High priority. Chozo grabs Samus",
        [0x1D] = "Dachora cry",
        [0x1E] = "High priority. Unused",
        [0x1F] = "High priority. Fune spits",
        [0x20] = "Shot fly",
        [0x21] = "Shot skree / wall/ninja space pirate",
        [0x22] = "Shot pipe bug / choot / Golden Torizo egg hatches",
        [0x23] = "Shot zero / sidehopper / zoomer",
        [0x24] = "Small explosion",
        [0x25] = "Big explosion",
        [0x26] = "Bomb Torizo explosive swipe",
        [0x27] = "High priority. Shot torizo",
        [0x28] = "Unused",
        [0x29] = "Mother Brain rising into phase 2 / Crocomire's wall explodes / Spore Spawn gets hard",
        [0x2A] = "Unused",
        [0x2B] = "Ridley's fireball hit surface / Crocomire post-death rumble / Phantoon exploding",
        [0x2C] = "High priority. Shot Spore Spawn / Spore Spawn opens up",
        [0x2D] = "High priority. Kraid's roar / Crocomire dying cry",
        [0x2E] = "High priority. Kraid's dying cry",
        [0x2F] = "Yapping maw",
        [0x30] = "Shot super-desgeega / Crocomire destroys wall",
        [0x31] = "Brinstar plant chewing",
        [0x32] = "Etecoon wall-jump",
        [0x33] = "Etecoon cry",
        [0x34] = "Cacatac spikes / Golden Torizo egg released",
        [0x35] = "High priority. Etecoon's theme",
        [0x36] = "Shot rio / squeept / dragon",
        [0x37] = "Refill/map station engaged",
        [0x38] = "Refill/map station disengaged",
        [0x39] = "Dachora speed booster",
        [0x3A] = "Tatori spinning",
        [0x3B] = "Dachora shinespark",
        [0x3C] = "Dachora shinespark ended",
        [0x3D] = "Dachora stored shinespark",
        [0x3E] = "Shot owtch / viola / ripper / tripper / suspensor platform / yard / yapping maw / atomic",
        [0x3F] = "Alcoon spit / fake Kraid lint / ninja pirate spin jump",
        [0x40] = "Unused",
        [0x41] = "(Empty)",
        [0x42] = "Boulder bounces",
        [0x43] = "Boulder explodes",
        [0x44] = "(Empty)",
        [0x45] = "Typewriter stroke - Ceres self destruct sequence",
        [0x46] = "High priority. Lavaquake",
        [0x47] = "Shot waver",
        [0x48] = "Torizo sonic boom",
        [0x49] = "Shot skultera / sciser / zoa",
        [0x4A] = "Shot evir",
        [0x4B] = "Chozo / torizo footsteps",
        [0x4C] = "Ki-hunter spit / eye door acid spit / Draygon goop",
        [0x4D] = "Gunship hover",
        [0x4E] = "High priority. Ceres Ridley getaway",
        [0x4F] = "Unused",
        [0x50] = "High priority. Metroid draining Samus / random metroid cry",
        [0x51] = "High priority. Shot coven",
        [0x52] = "Shitroid feels remorse",
        [0x53] = "Shot mini-Crocomire",
        [0x54] = "High priority. Unused. Shot Crocomire(?)",
        [0x55] = "Shot beetom",
        [0x56] = "Acquired suit",
        [0x57] = "Shot door/gate with dud shot / shot reflec / shot oum",
        [0x58] = "Shot mochtroid / random metroid cry",
        [0x59] = "High priority. Ridley's roar",
        [0x5A] = "Shot metroid / random metroid cry",
        [0x5B] = "Skree launches attack",
        [0x5C] = "Skree hits the ground",
        [0x5D] = "Sidehopper jumped",
        [0x5E] = "Sidehopper landed / fire arc part spawns / evir spit / alcoon spawns",
        [0x5F] = "Shot holtz / desgeega / viola / alcoon / Botwoon",
        [0x60] = "Unused",
        [0x61] = "Dragon / magdollite spit / fire pillar",
        [0x62] = "Unused",
        [0x63] = "Mother Brain's death beam",
        [0x64] = "Holtz cry",
        [0x65] = "Rio cry",
        [0x66] = "Shot ki-hunter / shot walking space pirate / space pirate attack",
        [0x67] = "Space pirate / Mother Brain / torizo / work robot laser",
        [0x68] = "Work robot",
        [0x69] = "Shot Shaktool",
        [0x6A] = "Shot powamp",
        [0x6B] = "Unused",
        [0x6C] = "Kago bug",
        [0x6D] = "Ceres tiles falling from ceiling",
        [0x6E] = "High priority. Shot Mother Brain phase 1",
        [0x6F] = "High priority. Mother Brain's cry - low pitch",
        [0x70] = "Yard bounce",
        [0x71] = "Silence",
        [0x72] = "High priority. Shitroid's cry",
        [0x73] = "High priority. Phantoon's cry / Draygon's cry",
        [0x74] = "High priority. Crocomire's cry",
        [0x75] = "High priority. Crocomire's skeleton collapses",
        [0x76] = "Quake",
        [0x77] = "High priority. Crocomire melting cry",
        [0x78] = "Shitroid draining",
        [0x79] = "Phantoon appears 1",
        [0x7A] = "Phantoon appears 2",
        [0x7B] = "Phantoon appears 3",
        [0x7C] = "High priority. Botwoon spit",
        [0x7D] = "High priority. Shitroid feels guilty",
        [0x7E] = "High priority. Mother Brain's cry - high pitch / Phantoon's dying cry",
        [0x7F] = "Mother Brain charging her rainbow"
    },
    {
        [1] = "Silence",
        [2] = "Low health beep",
        [3] = "Speed booster",
        [4] = "Samus landed hard",
        [5] = "Samus landed / wall-jumped",
        [6] = "Samus' footsteps",
        [7] = "High priority. Door opened",
        [8] = "High priority. Door closed",
        [9] = "Missile door shot with missile / shot zebetite",
        [0xA] = "High priority. Enemy frozen",
        [0xB] = "Elevator",
        [0xC] = "Stored shinespark",
        [0xD] = "Typewriter stroke - intro",
        [0xE] = "High priority. Gate opening/closing",
        [0xF] = "Shinespark",
        [0x10] = "Shinespark ended",
        [0x11] = "(shorter version of shinespark ended)",
        [0x12] = "High priority. (Empty)",
        [0x13] = "Mother Brain's / torizo's projectile hits surface / Shitroid exploding / Mother Brain exploding",
        [0x14] = "High priority. Gunship elevator activated",
        [0x15] = "High priority. Gunship elevator deactivated",
        [0x16] = "Unused. Crunchy footstep",
        [0x17] = "Mother Brain's blue rings",
        [0x18] = "(Empty)",
        [0x19] = "High priority. Shitroid dies",
        [0x1A] = "(Empty)",
        [0x1B] = "High priority. Draygon dying cry",
        [0x1C] = "Crocomire spit",
        [0x1D] = "Phantoon's flame",
        [0x1E] = "Kraid's earthquake",
        [0x1F] = "Kraid fires lint",
        [0x20] = "High priority. (Empty)",
        [0x21] = "High priority. Ridley whips its tail",
        [0x22] = "Crocomire acid damage",
        [0x23] = "Baby metroid cry 1",
        [0x24] = "High priority. Baby metroid cry - Ceres",
        [0x25] = "Silence (clear speed booster / elevator sound)",
        [0x26] = "Baby metroid cry 2",
        [0x27] = "Baby metroid cry 3",
        [0x28] = "Phantoon materialises attack",
        [0x29] = "Phantoon's super missiled attack",
        [0x2A] = "Pause menu ambient beep",
        [0x2B] = "Resume speed booster / shinespark",
        [0x2C] = "High priority. Ceres door opening",
        [0x2D] = "Gaining/losing incremental health",
        [0x2E] = "High priority. Mother Brain's glass shattering",
        [0x2F] = "(Empty)"
    }
}

function formatValue(v)
    if v < 0xA then
        return string.format("%X", v)
    else
        return string.format("%Xh", v)
    end
end

function init()
    local x = 0
    local y = 0
    local width = 500
    local height = 440
    local fixedWidth = true
    local boxType = nil
    local multiline = true
    --local scrollbars = "both"
    local scrollbars = nil

    superform_sound = forms.newform(width * 3, height, "ARAM - sound")
    form_sound1 = forms.label(superform_sound, "", x,             y, width, height, fixedWidth)
    form_sound2 = forms.label(superform_sound, "", x + width,     y, width, height, fixedWidth)
    form_sound3 = forms.label(superform_sound, "", x + width * 2, y, width, height, fixedWidth)
    
    width = 760
    height = 780
    superform_music = forms.newform(width, height, "ARAM - music")
    form_music = forms.label(superform_music, "", x, y, width, height, fixedWidth)

    width = 708
    height = 240
    superform_soundTrackers = forms.newform(width * 2, height * 2, "Sound trackers")
    -- int forms.textbox(int formhandle, [string caption = null], [int? width = null], [int? height = null], [string boxtype = null],
    --     [int? x = null], [int? y = null], [bool multiline = False], [bool fixedwidth = False], [string scrollbars = null])
    form_sound1tracker = forms.textbox(superform_soundTrackers, "", width, height * 2, boxType, x,         y,          multiline, fixedWidth, scrollbars)
    form_sound2tracker = forms.textbox(superform_soundTrackers, "", width, height,     boxType, x + width, y,          multiline, fixedWidth, scrollbars)
    form_sound3tracker = forms.textbox(superform_soundTrackers, "", width, height,     boxType, x + width, y + height, multiline, fixedWidth, scrollbars)
    
    width = 800
    height = 780
    superform_musicTracks = forms.newform(width * 2, height, "Music tracks")
    form_musicTrack0 = forms.textbox(superform_musicTracks, "", width, height, boxType, x,         y, multiline, fixedWidth, scrollbars)
    form_musicTrack4 = forms.textbox(superform_musicTracks, "", width, height, boxType, x + width, y, multiline, fixedWidth, scrollbars)
end

function updateForm_sound(form, i_sound, n_voices)
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
        text_soundInstructionListPointers           = text_soundInstructionListPointers           .. separator .. string.format("$%04X", sm.getAram_sound_p_instructionList(i_sound)(i)())
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
        text_soundAdsrSettings                      = text_soundAdsrSettings                      .. separator .. string.format("% 4Xh", sm.getAram_sound_adsrSettings(i_sound)(i))
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

    sound = sm.getAram_sound(i_sound)()
    if sound == 0 then
        soundName = 'None'
    else
        soundName = soundNames[i_sound + 1][sound]
    end
    
    forms.settext(form, ""
        .. string.format("Current sound %d: %Xh. %s\n",  i_sound + 1, sound, soundName)
        .. string.format("Sound %d initialisation flag: %Xh\n", i_sound + 1, sm.getAram_sound_initialisationFlag(i_sound)())
        .. string.format("Sound %d enabled voices:      %Xh\n", i_sound + 1, sm.getAram_sound_enabledVoices(i_sound)())
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

function updateForm_music(form)
    n_voices = 8

    local text_trackDisabled                          = "Track disabled:                             "
    local text_trackPointers                          = "Track pointers:                             "
    local text_trackNoteTimers                        = "Track note timers:                          "
    local text_trackNoteRingTimers                    = "Track note ring timers:                     "
    local text_trackRepeatedSubsectionCounters        = "Track repeated subsection counters:         "
    local text_trackDynamicVolumeTimers               = "Track dynamic volume timers:                "
    local text_trackDynamicPanningTimers              = "Track dynamic panning timers:               "
    local text_trackPitchSlideTimers                  = "Track pitch slide timers:                   "
    local text_trackPitchSlideDelayTimers             = "Track pitch slide delay timers:             "
    local text_trackVibratoDelayTimers                = "Track vibrato delay timers:                 "
    local text_trackVibratoExtents                    = "Track vibrato extents:                      "
    local text_trackTremoloDelayTimers                = "Track tremolo delay timers:                 "
    local text_trackTremoloExtents                    = "Track tremolo extents:                      "
    local text_trackDynamicVibratoTimers              = "Track dynamic vibrato timers:               "
    local text_trackNoteLengths                       = "Track note lengths:                         "
    local text_trackNoteRingLengths                   = "Track note ring lengths:                    "
    local text_trackNoteVolume                        = "Track note volumes:                         "
    local text_trackInstrumentIndices                 = "Track instrument indices:                   "
    local text_trackInstrumentPitches                 = "Track instrument pitches:                   "
    local text_trackRepeatedSubsectionReturnAddresses = "Track repeated subsection return addresses: "
    local text_trackRepeatedSubsectionAddresses       = "Track repeated subsection addresses:        "
    local text_trackSlideLengths                      = "Track slide lengths:                        "
    local text_trackSlideDelays                       = "Track slide delays:                         "
    local text_trackSlideDirections                   = "Track slide directions:                     "
    local text_trackSlideExtents                      = "Track slide extents:                        "
    local text_trackVibratoPhases                     = "Track vibrato phases:                       "
    local text_trackVibratoRates                      = "Track vibrato rates:                        "
    local text_trackVibratoDelays                     = "Track vibrato delays:                       "
    local text_trackDynamicVibratoLengths             = "Track dynamic vibrato lengths:              "
    local text_trackVibratoExtentDeltas               = "Track vibrato extent deltas:                "
    local text_trackStaticVibratoExtents              = "Track static vibrato extents:               "
    local text_trackTremoloPhases                     = "Track tremolo phases:                       "
    local text_trackTremoloRates                      = "Track tremolo rates:                        "
    local text_trackTremoloDelays                     = "Track tremolo delays:                       "
    local text_trackTransposes                        = "Track transposes:                           "
    local text_trackVolumes                           = "Track volumes:                              "
    local text_trackVolumeDeltas                      = "Track volumes deltas:                       "
    local text_trackTargetVolumes                     = "Track target volumes:                       "
    local text_trackOutputVolumes                     = "Track output volumes:                       "
    local text_trackPanningBiases                     = "Track panning biases:                       "
    local text_trackPanningBiasDeltas                 = "Track panning bias deltas:                  "
    local text_trackTargetPanningBiases               = "Track target panning biases:                "
    local text_trackPhaseInversionOptions             = "Track phase inversion options:              "
    local text_trackSubnotes                          = "Track subnotes:                             "
    local text_trackNotes                             = "Track notes:                                "
    local text_trackNoteDeltas                        = "Track note deltas:                          "
    local text_trackTargetNotes                       = "Track target notes:                         "
    local text_trackSubtransposes                     = "Track subtransposes:                        "

    local tracksDisabled = sm.getAram_enabledSoundVoices()

    local separator = ""
    for i = 0, n_voices - 1 do
        local trackDisabled = xemu.and_(xemu.rshift(tracksDisabled, i), 1)
        
        text_trackDisabled                          = text_trackDisabled                          .. separator .. string.format("% 5X", trackDisabled)
        text_trackPointers                          = text_trackPointers                          .. separator .. string.format("$%04X", sm.getAram_trackPointers(i))
        text_trackNoteTimers                        = text_trackNoteTimers                        .. separator .. string.format("% 4Xh", sm.getAram_trackNoteTimers(i))
        text_trackNoteRingTimers                    = text_trackNoteRingTimers                    .. separator .. string.format("% 4Xh", sm.getAram_trackNoteRingTimers(i))
        text_trackRepeatedSubsectionCounters        = text_trackRepeatedSubsectionCounters        .. separator .. string.format("% 4Xh", sm.getAram_trackRepeatedSubsectionCounters(i))
        text_trackDynamicVolumeTimers               = text_trackDynamicVolumeTimers               .. separator .. string.format("% 4Xh", sm.getAram_trackDynamicVolumeTimers(i))
        text_trackDynamicPanningTimers              = text_trackDynamicPanningTimers              .. separator .. string.format("% 4Xh", sm.getAram_trackDynamicPanningTimers(i))
        text_trackPitchSlideTimers                  = text_trackPitchSlideTimers                  .. separator .. string.format("% 4Xh", sm.getAram_trackPitchSlideTimers(i))
        text_trackPitchSlideDelayTimers             = text_trackPitchSlideDelayTimers             .. separator .. string.format("% 4Xh", sm.getAram_trackPitchSlideDelayTimers(i))
        text_trackVibratoDelayTimers                = text_trackVibratoDelayTimers                .. separator .. string.format("% 4Xh", sm.getAram_trackVibratoDelayTimers(i))
        text_trackVibratoExtents                    = text_trackVibratoExtents                    .. separator .. string.format("% 4Xh", sm.getAram_trackVibratoExtents(i))
        text_trackTremoloDelayTimers                = text_trackTremoloDelayTimers                .. separator .. string.format("% 4Xh", sm.getAram_trackTremoloDelayTimers(i))
        text_trackTremoloExtents                    = text_trackTremoloExtents                    .. separator .. string.format("% 4Xh", sm.getAram_trackTremoloExtents(i))
        text_trackDynamicVibratoTimers              = text_trackDynamicVibratoTimers              .. separator .. string.format("% 4Xh", sm.getAram_trackDynamicVibratoTimers(i))
        text_trackNoteLengths                       = text_trackNoteLengths                       .. separator .. string.format("% 4Xh", sm.getAram_trackNoteLengths(i))
        text_trackNoteRingLengths                   = text_trackNoteRingLengths                   .. separator .. string.format("% 4Xh", sm.getAram_trackNoteRingLengths(i))
        text_trackNoteVolume                        = text_trackNoteVolume                        .. separator .. string.format("% 4Xh", sm.getAram_trackNoteVolume(i))
        text_trackInstrumentIndices                 = text_trackInstrumentIndices                 .. separator .. string.format("% 4Xh", sm.getAram_trackInstrumentIndices(i))
        text_trackInstrumentPitches                 = text_trackInstrumentPitches                 .. separator .. string.format("% 4Xh", sm.getAram_trackInstrumentPitches(i))
        text_trackRepeatedSubsectionReturnAddresses = text_trackRepeatedSubsectionReturnAddresses .. separator .. string.format("$%04X", sm.getAram_trackRepeatedSubsectionReturnAddresses(i))
        text_trackRepeatedSubsectionAddresses       = text_trackRepeatedSubsectionAddresses       .. separator .. string.format("$%04X", sm.getAram_trackRepeatedSubsectionAddresses(i))
        text_trackSlideLengths                      = text_trackSlideLengths                      .. separator .. string.format("% 4Xh", sm.getAram_trackSlideLengths(i))
        text_trackSlideDelays                       = text_trackSlideDelays                       .. separator .. string.format("% 4Xh", sm.getAram_trackSlideDelays(i))
        text_trackSlideDirections                   = text_trackSlideDirections                   .. separator .. string.format("% 4Xh", sm.getAram_trackSlideDirections(i))
        text_trackSlideExtents                      = text_trackSlideExtents                      .. separator .. string.format("% 4Xh", sm.getAram_trackSlideExtents(i))
        text_trackVibratoPhases                     = text_trackVibratoPhases                     .. separator .. string.format("% 4Xh", sm.getAram_trackVibratoPhases(i))
        text_trackVibratoRates                      = text_trackVibratoRates                      .. separator .. string.format("% 4Xh", sm.getAram_trackVibratoRates(i))
        text_trackVibratoDelays                     = text_trackVibratoDelays                     .. separator .. string.format("% 4Xh", sm.getAram_trackVibratoDelays(i))
        text_trackDynamicVibratoLengths             = text_trackDynamicVibratoLengths             .. separator .. string.format("% 4Xh", sm.getAram_trackDynamicVibratoLengths(i))
        text_trackVibratoExtentDeltas               = text_trackVibratoExtentDeltas               .. separator .. string.format("% 4Xh", sm.getAram_trackVibratoExtentDeltas(i))
        text_trackStaticVibratoExtents              = text_trackStaticVibratoExtents              .. separator .. string.format("% 4Xh", sm.getAram_trackStaticVibratoExtents(i))
        text_trackTremoloPhases                     = text_trackTremoloPhases                     .. separator .. string.format("% 4Xh", sm.getAram_trackTremoloPhases(i))
        text_trackTremoloRates                      = text_trackTremoloRates                      .. separator .. string.format("% 4Xh", sm.getAram_trackTremoloRates(i))
        text_trackTremoloDelays                     = text_trackTremoloDelays                     .. separator .. string.format("% 4Xh", sm.getAram_trackTremoloDelays(i))
        text_trackTransposes                        = text_trackTransposes                        .. separator .. string.format("% 4Xh", sm.getAram_trackTransposes(i))
        text_trackVolumes                           = text_trackVolumes                           .. separator .. string.format("% 4Xh", sm.getAram_trackVolumes(i))
        text_trackVolumeDeltas                      = text_trackVolumeDeltas                      .. separator .. string.format("% 4Xh", sm.getAram_trackVolumeDeltas(i))
        text_trackTargetVolumes                     = text_trackTargetVolumes                     .. separator .. string.format("% 4Xh", sm.getAram_trackTargetVolumes(i))
        text_trackOutputVolumes                     = text_trackOutputVolumes                     .. separator .. string.format("% 4Xh", sm.getAram_trackOutputVolumes(i))
        text_trackPanningBiases                     = text_trackPanningBiases                     .. separator .. string.format("% 4Xh", sm.getAram_trackPanningBiases(i))
        text_trackPanningBiasDeltas                 = text_trackPanningBiasDeltas                 .. separator .. string.format("% 4Xh", sm.getAram_trackPanningBiasDeltas(i))
        text_trackTargetPanningBiases               = text_trackTargetPanningBiases               .. separator .. string.format("% 4Xh", sm.getAram_trackTargetPanningBiases(i))
        text_trackPhaseInversionOptions             = text_trackPhaseInversionOptions             .. separator .. string.format("% 4Xh", sm.getAram_trackPhaseInversionOptions(i))
        text_trackSubnotes                          = text_trackSubnotes                          .. separator .. string.format("% 4Xh", sm.getAram_trackSubnotes(i))
        text_trackNotes                             = text_trackNotes                             .. separator .. string.format("% 4Xh", sm.getAram_trackNotes(i))
        text_trackNoteDeltas                        = text_trackNoteDeltas                        .. separator .. string.format("% 4Xh", sm.getAram_trackNoteDeltas(i))
        text_trackTargetNotes                       = text_trackTargetNotes                       .. separator .. string.format("% 4Xh", sm.getAram_trackTargetNotes(i))
        text_trackSubtransposes                     = text_trackSubtransposes                     .. separator .. string.format("% 4Xh", sm.getAram_trackSubtransposes(i))

        separator = " | "
    end
    
    forms.settext(form, ""
        .. string.format("Tracker pointer: $%04X\n", sm.getAram_p_tracker())
        .. string.format("Tracker timer:   %02Xh\n", sm.getAram_trackerTimer())
        .. "\n"
        .. text_trackDisabled                          .. "\n"
        .. text_trackPointers                          .. "\n"
        .. text_trackNoteTimers                        .. "\n"
        .. text_trackNoteRingTimers                    .. "\n"
        .. text_trackRepeatedSubsectionCounters        .. "\n"
        .. text_trackDynamicVolumeTimers               .. "\n"
        .. text_trackDynamicPanningTimers              .. "\n"
        .. text_trackPitchSlideTimers                  .. "\n"
        .. text_trackPitchSlideDelayTimers             .. "\n"
        .. text_trackVibratoDelayTimers                .. "\n"
        .. text_trackVibratoExtents                    .. "\n"
        .. text_trackTremoloDelayTimers                .. "\n"
        .. text_trackTremoloExtents                    .. "\n"
        .. text_trackDynamicVibratoTimers              .. "\n"
        .. text_trackNoteLengths                       .. "\n"
        .. text_trackNoteRingLengths                   .. "\n"
        .. text_trackNoteVolume                        .. "\n"
        .. text_trackInstrumentIndices                 .. "\n"
        .. text_trackInstrumentPitches                 .. "\n"
        .. text_trackRepeatedSubsectionReturnAddresses .. "\n"
        .. text_trackRepeatedSubsectionAddresses       .. "\n"
        .. text_trackSlideLengths                      .. "\n"
        .. text_trackSlideDelays                       .. "\n"
        .. text_trackSlideDirections                   .. "\n"
        .. text_trackSlideExtents                      .. "\n"
        .. text_trackVibratoPhases                     .. "\n"
        .. text_trackVibratoRates                      .. "\n"
        .. text_trackVibratoDelays                     .. "\n"
        .. text_trackDynamicVibratoLengths             .. "\n"
        .. text_trackVibratoExtentDeltas               .. "\n"
        .. text_trackStaticVibratoExtents              .. "\n"
        .. text_trackTremoloPhases                     .. "\n"
        .. text_trackTremoloRates                      .. "\n"
        .. text_trackTremoloDelays                     .. "\n"
        .. text_trackTransposes                        .. "\n"
        .. text_trackVolumes                           .. "\n"
        .. text_trackVolumeDeltas                      .. "\n"
        .. text_trackTargetVolumes                     .. "\n"
        .. text_trackOutputVolumes                     .. "\n"
        .. text_trackPanningBiases                     .. "\n"
        .. text_trackPanningBiasDeltas                 .. "\n"
        .. text_trackTargetPanningBiases               .. "\n"
        .. text_trackPhaseInversionOptions             .. "\n"
        .. text_trackSubnotes                          .. "\n"
        .. text_trackNotes                             .. "\n"
        .. text_trackNoteDeltas                        .. "\n"
        .. text_trackTargetNotes                       .. "\n"
        .. text_trackSubtransposes                     .. "\n"
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
        text = text .. string.format("Sound %d voice %d:\r\n", i_sound + 1, i_voice)
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

function updateForm_musicTrack(form, i_voice_begin)
    local text_00              = "00          ; EOF\r\n"
    local text_C8              = "C8          ; Tie\r\n"
    local text_C9              = "C9          ; Rest\r\n"
    local text_E0              = "E0 %02X       ; Select instrument %s\r\n"
    local text_E1              = "E1 %02X       ; Panning bias = %s / 14h with %s phase inversion\r\n"
    local text_E2              = "E2 %02X %02X    ; Dynamic panning over %s tics with target panning bias %s / 14h\r\n"
    local text_E3              = "E3 %02X %02X %02X ; Static vibrato after %s tics at rate %s with extent %s\r\n"
    local text_E4              = "E4          ; End vibrato\r\n"
    local text_E5              = "E5 %02X       ; Music volume multiplier = %s\r\n"
    local text_E6              = "E6 %02X %02X    ; Dynamic music volume over %s tics with target volume %s\r\n"
    local text_E7              = "E7 %02X       ; Music tempo = %f tics per second\r\n"
    local text_E8              = "E8 %02X %02X    ; Dynamic music tempo over %s tics with target tempo %s tics per second\r\n"
    local text_E9              = "E9 %02X       ; Set music transpose of %s semitones\r\n"
    local text_EA              = "EA %02X       ; Set transpose of %s semitones\r\n"
    local text_EB              = "EB %02X %02X %02X ; Tremolo after %s tics at rate %s with extent %s\r\n"
    local text_EC              = "EC          ; End tremolo\r\n"
    local text_ED              = "ED %02X       ; Volume multiplier = %s\r\n"
    local text_EE              = "EE %02X %02X    ; Dynamic volume over %s tics with target volume %s\r\n"
    local text_EF              = "EF %04X %02X  ; Repeat subsection $%04X, %s times\r\n"
    local text_F0              = "F0 %02X       ; Dynamic vibrato over %s tics with target extent 0\r\n"
    local text_F1              = "F1 %02X %02X %02X ; Slide out after %s tics for %s tics by %s semitones\r\n"
    local text_F2              = "F2 %02X %02X %02X ; Slide in after %s tics for %s tics by %s semitones\r\n"
    local text_F3              = "F3          ; End slide\r\n"
    local text_F4              = "F4 %02X       ; Set subtranspose of %s / 100h semitones\r\n"
    local text_F5              = "F5 %02X %02X %02X ; Static echo on voices %s with echo volume left = %s and echo volume right = %s\r\n"
    local text_F6              = "F6          ; End echo\r\n"
    local text_F7              = "F7 %02X %02X %02X ; Set echo parameters: echo delay = %s, feedback volume = %s, FIR filter index = %d\r\n"
    local text_F8              = "F8 %02X %02X %02X ; Dynamic echo volume after %s tics with target echo volume left = %s, right = %s\r\n"
    local text_F9              = "F9 %02X %02X %02X ; Pitch slide after %s tics over %s tics by %s semitones\r\n"
    local text_FA              = "FA %02X       ; Percussion instruments base index = %s\r\n"
    local text_FB              = "FB          ; Skip next byte\r\n"
    local text_FC              = "FC          ; Skip all new notes\r\n"
    local text_FD              = "FD          ; Stop sound effects and disable music note processing\r\n"
    local text_FE              = "FE          ; Resume sound effects and enable music note processing\r\n"
    
    local text_noteLength      = "%02X          ; Note length = %s tics\r\n"
    local text_noteLengthExtra = "%02X %02X       ; Note length = %s tics, volume = %Xh, ring length = %Xh\r\n"
    local text_note            = "%02X          ; Note %s_%d\r\n"
    local text_percussionNote  = "%02X          ; Percussion note %s\r\n"
    
    local text = ""
    for i_voice = i_voice_begin, i_voice_begin + 3 do
        text = text .. string.format("Music voice %d:\r\n", i_voice)
        local p_track = sm.getAram_trackPointers(i_voice)
        if p_track == 0 then
            text = text .. "[disabled]\r\n"
        else
            local p_tracker = sm.getAram_p_tracker()
            local p_trackSet = xemu.read_aram_u16_le(p_tracker - 2)
            local p_begin_track = xemu.read_aram_u16_le(p_trackSet + i_voice * 2)
            
            local text_lines = {}
            local p = p_begin_track
            n_trailing_lines = 0
            while true do
                text_line = ""
                if p == p_track then
                    text_line = text_line .. "> "
                else
                    text_line = text_line .. "  "
                end
                
                text_line = text_line .. string.format("$%04X: ", p)
                
                local command = xemu.read_aram_u8(p)
                p = p + 1
                
                -- Terminator
                if command == 0 then
                    text_line = text_line .. text_00
                
                -- Note length ( + volume + ring length)
                elseif 1 <= command and command < 0x80 then
                    local extra = xemu.read_aram_u8(p)
                    if extra >= 0x80 then
                        text_line = text_line .. string.format(text_noteLength, command, formatValue(command))
                    else
                        local volumes = {[0] = 0x19, 0x32, 0x4C, 0x65, 0x72, 0x7F, 0x8C, 0x98, 0xA5, 0xB2, 0xBF, 0xCB, 0xD8, 0xE5, 0xF2, 0xFC}
                        local volume = volumes[xemu.and_(extra, 0xF)]
                        local ringLengths = {[0] = 0x32, 0x65, 0x7F, 0x98, 0xB2, 0xCB, 0xE5, 0xFC}
                        local ringLength = ringLengths[xemu.and_(xemu.rshift(extra, 4), 7)]
                        p = p + 1
                        text_line = text_line .. string.format(text_noteLengthExtra, command, extra, formatValue(command), volume, ringLength)
                    end
                
                -- Note
                elseif 0x80 <= command and command < 0xC8 then
                    local octave = math.floor((command - 0x80) / 12) + 1
                    local notes = {[0] = 'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'}
                    local note = notes[(command - 0x80) % 12]
                    text_line = text_line .. string.format(text_note, command, note, octave)
                
                -- Tie
                elseif command == 0xC8 then
                    text_line = text_line .. string.format(text_C8)
                
                -- Rest
                elseif command == 0xC9 then
                    text_line = text_line .. string.format(text_C9)
                
                -- Percussion note
                elseif 0xCA <= command and command < 0xE0 then
                    text_line = text_line .. string.format(text_percussionNote, command, formatValue(command))
                
                -- Commands
                elseif command == 0xE0 then
                    local v = xemu.read_aram_u8(p)
                    p = p + 1
                    text_line = text_line .. string.format(text_E0, v, formatValue(v))
                
                elseif command == 0xE1 then
                    local v = xemu.read_aram_u8(p)
                    p = p + 1
                    local inversions = {[0] = 'no', 'right side', 'left side', 'both side'}
                    local inversion = inversions[xemu.rshift(v, 6)]
                    text_line = text_line .. string.format(text_E1, v, formatValue(xemu.and_(v, 0x1F)), inversion)
                
                elseif command == 0xE2 then
                    local timer = xemu.read_aram_u8(p)
                    local bias = xemu.read_aram_u8(p + 1)
                    p = p + 2
                    text_line = text_line .. string.format(text_E2, timer, bias, formatValue(timer), formatValue(bias))
                
                elseif command == 0xE3 then
                    local delay = xemu.read_aram_u8(p)
                    local rate = xemu.read_aram_u8(p + 1)
                    local extent = xemu.read_aram_u8(p + 2)
                    p = p + 3
                    text_line = text_line .. string.format(text_E3, delay, rate, extent, formatValue(delay), formatValue(rate), formatValue(extent))
                
                elseif command == 0xE4 then
                    text_line = text_line .. text_E4
                
                elseif command == 0xE5 then
                    local volume = xemu.read_aram_u8(p)
                    p = p + 1
                    text_line = text_line .. string.format(text_E5, volume, formatValue(volume))
                
                elseif command == 0xE6 then
                    local timer = xemu.read_aram_u8(p)
                    local volume = xemu.read_aram_u8(p + 1)
                    p = p + 2
                    text_line = text_line .. string.format(text_E6, timer, volume, formatValue(timer), formatValue(volume))
                
                elseif command == 0xE7 then
                    local tempo = xemu.read_aram_u8(p)
                    p = p + 1
                    local ticRate = tempo / (0x100 * 0.002)
                    text_line = text_line .. string.format(text_E7, tempo, ticRate)
                
                elseif command == 0xE8 then
                    local timer = xemu.read_aram_u8(p)
                    local tempo = xemu.read_aram_u8(p + 1)
                    p = p + 2
                    local ticRate = tempo / (0x100 * 0.002)
                    text_line = text_line .. string.format(text_E8, timer, tempo, formatValue(timer), ticRate)
                
                elseif command == 0xE9 then
                    local transpose = xemu.read_aram_u8(p)
                    p = p + 1
                    text_line = text_line .. string.format(text_E9, transpose, formatValue(transpose))
                
                elseif command == 0xEA then
                    local transpose = xemu.read_aram_u8(p)
                    p = p + 1
                    text_line = text_line .. string.format(text_EA, transpose, formatValue(transpose))
                
                elseif command == 0xEB then
                    local delay = xemu.read_aram_u8(p)
                    local rate = xemu.read_aram_u8(p + 1)
                    local extent = xemu.read_aram_u8(p + 2)
                    p = p + 3
                    text_line = text_line .. string.format(text_EB, delay, rate, extent, formatValue(delay), formatValue(rate), formatValue(extent))
                
                elseif command == 0xEC then
                    text_line = text_line .. text_EC
                
                elseif command == 0xED then
                    local volume = xemu.read_aram_u8(p)
                    p = p + 1
                    text_line = text_line .. string.format(text_ED, volume, formatValue(volume))
                
                elseif command == 0xEE then
                    local timer = xemu.read_aram_u8(p)
                    local volume = xemu.read_aram_u8(p + 1)
                    p = p + 2
                    text_line = text_line .. string.format(text_EE, timer, volume, formatValue(timer), formatValue(volume))
                
                elseif command == 0xEF then
                    local p_subsection = xemu.read_aram_u16_le(p)
                    local counter = xemu.read_aram_u8(p + 2)
                    p = p + 3
                    text_line = text_line .. string.format(text_EF, p_subsection, counter, p_subsection, formatValue(counter - 1))
                
                elseif command == 0xF0 then
                    local length = xemu.read_aram_u8(p)
                    p = p + 1
                    text_line = text_line .. string.format(text_F0, length, formatValue(length))
                
                elseif command == 0xF1 then
                    local delay = xemu.read_aram_u8(p)
                    local length = xemu.read_aram_u8(p + 1)
                    local extent = xemu.read_aram_u8(p + 2)
                    p = p + 3
                    text_line = text_line .. string.format(text_F1, delay, length, extent, formatValue(delay), formatValue(length), formatValue(extent))
                
                elseif command == 0xF2 then
                    local delay = xemu.read_aram_u8(p)
                    local length = xemu.read_aram_u8(p + 1)
                    local extent = xemu.read_aram_u8(p + 2)
                    p = p + 3
                    text_line = text_line .. string.format(text_F2, delay, rate, extent, formatValue(delay), formatValue(rate), formatValue(extent))
                
                elseif command == 0xF3 then
                    text_line = text_line .. text_F3
                
                elseif command == 0xF4 then
                    local subtranspose = xemu.read_aram_u8(p)
                    p = p + 1
                    text_line = text_line .. string.format(text_F4, subtranspose, formatValue(subtranspose))
                
                elseif command == 0xF5 then
                    local enable = xemu.read_aram_u8(p)
                    local left = xemu.read_aram_u8(p + 1)
                    local right = xemu.read_aram_u8(p + 2)
                    
                    local voices = '(none)'
                    for i = 0, 7 do
                        if xemu.and_(xemu.rshift(enable, i), 1) then
                            if voices == '(none)' then
                                voices = string.format("%d", i)
                            else
                                voices = voices .. string.format("/%d", i)
                            end
                        end
                    end
                    
                    p = p + 3
                    text_line = text_line .. string.format(text_F5, enable, left, right, voices, formatValue(left), formatValue(right))
                
                elseif command == 0xF6 then
                    text_line = text_line .. text_F6
                
                elseif command == 0xF7 then
                    local delay = xemu.read_aram_u8(p)
                    local feedback = xemu.read_aram_u8(p + 1)
                    local i_fir = xemu.read_aram_u8(p + 2)
                    p = p + 3
                    text_line = text_line .. string.format(text_F7, delay, feedback, i_fir, formatValue(delay), formatValue(feedback), i_fir)
                
                elseif command == 0xF8 then
                    local timer = xemu.read_aram_u8(p)
                    local left = xemu.read_aram_u8(p + 1)
                    local right = xemu.read_aram_u8(p + 2)
                    p = p + 3
                    text_line = text_line .. string.format(text_F8, timer, left, right, formatValue(timer), formatValue(left), formatValue(right))
                
                elseif command == 0xF9 then
                    local delay = xemu.read_aram_u8(p)
                    local length = xemu.read_aram_u8(p + 1)
                    local target = xemu.read_aram_u8(p + 2)
                    p = p + 3
                    text_line = text_line .. string.format(text_F9, delay, length, target, formatValue(delay), formatValue(length), formatValue(target))
                
                elseif command == 0xFA then
                    local i_instruments = xemu.read_aram_u8(p)
                    p = p + 1
                    text_line = text_line .. string.format(text_FA, i_instruments, formatValue(i_instruments))
                
                elseif command == 0xFB then
                    text_line = text_line .. text_FB
                elseif command == 0xFC then
                    text_line = text_line .. text_FC
                elseif command == 0xFD then
                    text_line = text_line .. text_FD
                elseif command == 0xFE then
                    text_line = text_line .. text_FE
                end
                
                text_lines[#text_lines + 1] = text_line
                if #text_lines > 11 then
                    table.remove(text_lines, 1)
                end
                
                if command == 0 then
                    break
                end
                
                if p > p_track then
                    n_trailing_lines = n_trailing_lines + 1
                    if n_trailing_lines >= 6 then
                        break
                    end
                end
            end

            if p == p_track and n_trailing_lines < 6 then
                text_line = ">\r\n"
                text_lines[#text_lines + 1] = text_line
                if #text_lines > 11 then
                    table.remove(text_lines, 1)
                end
            end
            
            for _, text_line in ipairs(text_lines) do
                text = text .. text_line
            end
        end
        
        text = text .. "\r\n"
    end

    forms.settext(form, text)
    forms.refresh(form)
end

function main()
    updateForm_sound(form_sound1, 0, 4)
    updateForm_sound(form_sound2, 1, 2)
    updateForm_sound(form_sound3, 2, 2)
    updateForm_soundTracker(form_sound1tracker, 0, 4)
    updateForm_soundTracker(form_sound2tracker, 1, 2)
    updateForm_soundTracker(form_sound3tracker, 2, 2)
    
    updateForm_music(form_music)
    updateForm_musicTrack(form_musicTrack0, 0)
    updateForm_musicTrack(form_musicTrack4, 4)
end

init()
while true do
    main()
    emu.frameadvance()
end