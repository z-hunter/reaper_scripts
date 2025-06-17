--[[
  * ReaScript Name: Extract Chords from Selected Audio Item (Chordino)
  * Author: Michael Voitovich (zx.hunter@gmail.com)
  * Version: 1.0.1
  * Licence: MIT
  * REAPER: 6.0+
  * Extensions: None
  * About:
      Extracts chords from selected audio item using Sonic Annotator + Chordino,
      and creates a dedicated text items track with chord names.
      Requires: Sonic Annotator + Chordino VAMP plugin.
      Configure path to Sonic Annotator EXE in the script's USER CONFIG section.
      Project must be saved before running.
--]]

----------------------------------------
-- USER CONFIG -------------------------
----------------------------------------

local SONIC_ANNOTATOR_EXE = [[C:\Program Files\sonic-annotator-win64\sonic-annotator.exe]] -- <-- Set your path here!
local PLUGIN_ID           = "vamp:nnls-chroma:chordino:simplechord"

----------------------------------------
-- HELPERS ----------------------------
----------------------------------------
local function show(msg)
  -- reaper.ShowMessageBox(msg, "Chord Extractor", 0)
end

local function printf(fmt, ...)
 -- reaper.ShowConsoleMsg(string.format(fmt, ...))
end

local function prepareTemp(dirName)
  local sep = package.config:sub(1,1)
  local dir = reaper.GetResourcePath() .. sep .. dirName
  os.execute(string.format("mkdir \"%s\"", dir))
  local ts  = os.time() .. math.random(1000,9999)
  return string.format("%s%c%s", dir, sep:byte(), ts)
end

-- Parse Chordino CSV
local function parseChordinoCSV(path)
  local result, times, chords = {}, {}, {}
  local f = io.open(path, "r")
  if not f then return result end
  for line in f:lines() do
    local time, chord = line:match("([%d%.]+),\"?([^\"]+)\"?")
    if time and chord then
      table.insert(times, tonumber(time))
      table.insert(chords, chord)
    end
  end
  f:close()
  -- Convert to intervals: start, end, chord name
  for i = 1, #times - 1 do
    if chords[i] and chords[i] ~= "N" then
      table.insert(result, {s = times[i], e = times[i+1], ch = chords[i]})
    end
  end
  -- last chord till item end (if not N)
  if chords[#chords] and chords[#chords] ~= "N" then
    table.insert(result, {s = times[#chords], e = times[#chords], ch = chords[#chords]})
  end
  return result
end

local function wait_ms(ms)
  local t0 = os.clock()
  while os.clock() - t0 < ms / 1000 do end
end

----------------------------------------
-- MAIN --------------------------------
----------------------------------------
reaper.ClearConsole()
reaper.Undo_BeginBlock()

printf("[Chord Extractor] Start...\n")
if reaper.CountSelectedMediaItems(0) ~= 1 then show("Please select exactly one audio item") return end
local item = reaper.GetSelectedMediaItem(0,0)
if not item then show("Item is nil") return end
local take = reaper.GetActiveTake(item)
if not take or reaper.TakeIsMIDI(take) then show("Please select an audio item (not MIDI)") return end
local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
printf("[OK] Item selected. Position: %.3f sec\n", itemPos)

-- RENDER ➜ GLUE
reaper.Main_OnCommand(40635,0)              -- unselect all
reaper.SetMediaItemSelected(item, true)
reaper.Main_OnCommand(41588,0)              -- time selection = item
reaper.Main_OnCommand(40362,0)              -- glue to single wav

local gluedItem = reaper.GetSelectedMediaItem(0, 0)
local gluedTake = gluedItem and reaper.GetActiveTake(gluedItem) or nil
if not (gluedItem and gluedTake) then show("Could not get glued item/take") return end

local wavPathReal = reaper.GetMediaSourceFileName(reaper.GetMediaItemTake_Source(gluedTake), "")
if not wavPathReal or wavPathReal == "" then
  show("REAPER did not return glued file path.\n\nPossible reasons:\n- Current project was not saved to disk yet.")
  return
end
printf("[OK] Path to glued file: %s\n", wavPathReal)

-- COPY TO TEMP
local tmpBase = prepareTemp("ChordExtractTemp")
local wavTmp = tmpBase..".wav"
local srcF = io.open(wavPathReal, "rb")
local dstF = io.open(wavTmp,  "wb")
if not (srcF and dstF) then show("Could not create temp WAV") return end

dstF:write(srcF:read("*a")); srcF:close(); dstF:close()
printf("[OK] Temp WAV: %s\n", wavTmp)

--[[ Wait for system to release the file
local tries = 20
for i=1,tries do
  local f = io.open(wavTmp, "rb")
  if f then f:close(); break end
  wait_ms(250)
end
wait_ms(250)  -- give extra time ]]

-- ANALYZE
local cmd = string.format('cmd /C ""%s" -d %s -w csv "%s""', SONIC_ANNOTATOR_EXE, PLUGIN_ID, wavTmp )
printf("[INFO] sonic-annotator via cmd /C...\n%s\n", cmd)
local output = os.execute(cmd)
printf("[INFO] sonic-annotator os.execute output: %s\n", tostring(output))
printf("[INFO] Analysis finished\n")

-- Find CSV
local csvTmp = wavTmp:gsub("%.wav$", "_vamp_nnls-chroma_chordino_simplechord.csv")

local function cleanup()
  os.remove(csvTmp); os.remove(wavTmp)
  reaper.Main_OnCommand(40635,0)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Extract chords (Chordino)", -1)
  printf("[DONE] Script finished.\n")
end

-- 1. Проверка: анализатор не запустился
if not output or output == 0 or output == "0" then
  show("ERROR: Sonic Annotator not found.\n\nCheck path in the USER CONFIG section of this script.")
  cleanup() return
end

-- 2. Проверка: CSV не создан
local csvFile = io.open(csvTmp, "r")
if not csvFile then
  show("ERROR: Chordino analysis failed — CSV file was not created.\n\nPossible reasons:\n- Sonic Annotator misconfigured\n- VAMP plugin not found\n- File path issue")
  cleanup() return
end
csvFile:close()

-- 3. Проверка: CSV создан, но пуст или нет аккордов
local chords = parseChordinoCSV(csvTmp)
if #chords == 0 then
  show("Chordino found no chords in this audio (CSV was empty). Try with different material or settings.")
  cleanup() return
end

printf("[INFO] Chords found: %d\n", #chords)

-- CREATE OR FIND CHORD TRACK
local chordTrackName = "Chords (Extracted)"
local chordTrack = nil
for i = 0, reaper.CountTracks(0) - 1 do
  local tr = reaper.GetTrack(0, i)
  local _, name = reaper.GetTrackName(tr, "")
  if name == chordTrackName then chordTrack = tr break end
end 
if not chordTrack then
  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  chordTrack = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(chordTrack, "P_NAME", chordTrackName, true)
end

-- CREATE TEXT ITEMS
for _,c in ipairs(chords) do
  local pos = itemPos + c.s
  local len = math.max(0.05, (c.e > c.s and (c.e - c.s) or (itemLen - c.s)))
  local item = reaper.AddMediaItemToTrack(chordTrack)
  if item then
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", len)
    reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 0) -- disable looping
    reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", 0)
    reaper.ULT_SetMediaItemNote(item, c.ch)
  end
end

cleanup()
  
