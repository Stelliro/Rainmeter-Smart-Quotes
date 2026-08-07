-- logic.lua (Version 1.1.0 — release polish)

function Initialize()
    math.randomseed(os.time())

    SKIN:Bang('!SetOption', 'MeterAuthor', 'Text', 'Ready')
    SKIN:Bang('!UpdateMeter', 'MeterAuthor')
    SKIN:Bang('!Redraw')

    filePath = SKIN:GetVariable('CURRENTPATH') .. "Favorites.txt"
    favTable = {}
    currentQ = "Loading..."
    currentA = ""
    scrollIndex = 1
    slots = 5
    updateCounter = 0
    menuOpen = false

    local file = io.open(filePath, "r")
    if not file then
        file = io.open(filePath, "w")
        if file then file:close() end
    else
        file:close()
    end

    LoadFavorites()

    local savedState = SKIN:GetVariable('MenuState')
    if savedState == '1' then
        menuOpen = true
        SKIN:Bang('!ShowMeterGroup', 'SettingsMenu')
        SKIN:Bang('!Delay', '50')
        SKIN:Bang('!CommandMeasure', 'MeasureScript', 'ApplySearch("")')
    else
        menuOpen = false
    end
end

-- --- UTILITIES ---

function CleanString(str)
    if not str then return "" end
    -- Strip UTF-8 BOM if present
    if string.byte(str, 1) == 239 and string.byte(str, 2) == 187 and string.byte(str, 3) == 191 then
        str = string.sub(str, 4)
    end
    return str
end

function CleanText(s)
    if not s then return "" end
    s = CleanString(s)
    s = s:gsub("^%s*(.-)%s*$", "%1")
    s = s:gsub("&quot;", "'")
    s = s:gsub("&ldquo;", "'")
    s = s:gsub("&rdquo;", "'")
    s = s:gsub("&mdash;", "-")
    s = s:gsub('\\"', "'")
    s = s:gsub("\n", " ")
    s = s:gsub("\r", " ")
    return s
end

-- Split "quote" - author on the last " - " separator
function SplitQuoteAuthor(raw)
    raw = CleanString(raw or "")
    local reversed = string.reverse(raw)
    local s, e = string.find(reversed, " - ")
    if not s then
        return raw, "Unknown"
    end
    local splitPoint = string.len(raw) - e + 1
    local q = string.sub(raw, 1, splitPoint - 1)
    local a = string.sub(raw, splitPoint + 3)
    q = q:gsub('^%s*"+', ''):gsub('"+%s*$', '')
    return q, a
end

-- --- MENU / PANELS ---

function OpenMenu()
    menuOpen = true
    SKIN:Bang('!WriteKeyValue', 'Variables', 'MenuState', '1')
    SKIN:Bang('!ShowMeterGroup', 'SettingsMenu')
    ApplySearch(SKIN:GetMeasure('MeasureInputSearch'):GetStringValue() or "")
    SKIN:Bang('!Redraw')
end

function CloseMenu()
    menuOpen = false
    SKIN:Bang('!WriteKeyValue', 'Variables', 'MenuState', '0')
    SKIN:Bang('!HideMeterGroup', 'SettingsMenu')
    SKIN:Bang('!HideMeterGroup', 'AddPanel')
    SKIN:Bang('!Redraw')
end

function OpenAddPanel()
    SKIN:Bang('!HideMeterGroup', 'SettingsMenu')
    SKIN:Bang('!ShowMeterGroup', 'AddPanel')
    SKIN:Bang('!SetVariable', 'TempQuote', '')
    SKIN:Bang('!SetVariable', 'TempAuthor', '')
    SKIN:Bang('!Update')
end

function CancelAdd()
    SKIN:Bang('!HideMeterGroup', 'AddPanel')
    SKIN:Bang('!ShowMeterGroup', 'SettingsMenu')
    if menuOpen then ApplySearch("") end
    SKIN:Bang('!Redraw')
end

-- --- FEATURES ---

function WebSearch(query)
    if not query or query == "" then return end
    query = CleanText(query)
    query = query:gsub("%s+", "+")
    SKIN:Bang('["https://www.google.com/search?q=quotes+by+' .. query .. '"]')
end

function AddManualQuote(q, a)
    if not q or not a or q == "" or a == "" then return end
    q = CleanText(q)
    a = CleanText(a)
    local fullString = '"' .. q .. '"' .. " - " .. a
    table.insert(favTable, 1, fullString)
    SaveFavorites()
    menuOpen = true
    CancelAdd()
end

function OnWebUpdate()
    SKIN:Bang('!SetOption', 'MeterQuote', 'Text', 'Parsing...')
    SKIN:Bang('!Redraw')

    local measure = SKIN:GetMeasure('MeasureSite')
    if not measure then return end

    local rawData = measure:GetStringValue() or ""
    rawData = string.gsub(rawData, "\n", " ")
    rawData = string.gsub(rawData, "\r", " ")

    local q = rawData:match('"q"%s*:%s*"(.-)"')
    local a = rawData:match('"a"%s*:%s*"(.-)"')

    if q and a then
        currentQ = CleanText(q)
        currentA = CleanText(a)
        UpdateDisplay()
    else
        currentQ = "Parse Error"
        currentA = "Retrying..."
        UpdateDisplay()
    end
end

function UpdateDisplay()
    SKIN:Bang('!SetOption', 'MeterQuote', 'Text', currentQ)
    SKIN:Bang('!SetOption', 'MeterAuthor', 'Text', "- " .. currentA)
    SKIN:Bang('!UpdateMeter', 'MeterQuote')
    SKIN:Bang('!UpdateMeter', 'MeterAuthor')
    CheckIfFavorite()
    SKIN:Bang('!Redraw')
end

function ManualRefresh()
    -- Reset countdown via formula only (Calc has no ExecuteBatch)
    SKIN:Bang('!SetOption', 'MeasureTimer', 'Formula', '0')
    SKIN:Bang('!UpdateMeasure', 'MeasureTimer')
    GetQuote()
end

function LoadFavorites()
    favTable = {}
    local file = io.open(filePath, "r")
    if file then
        for line in file:lines() do
            if line ~= "" then table.insert(favTable, line) end
        end
        file:close()
    end
end

function SaveFavorites()
    local file = io.open(filePath, "w")
    if not file then return end
    for _, quote in ipairs(favTable) do
        file:write(quote .. "\n")
    end
    file:close()
    if menuOpen then
        ApplySearch(SKIN:GetMeasure('MeasureInputSearch'):GetStringValue() or "")
    end
end

function ToggleFavorite()
    if currentQ == "Loading..." or currentQ == "Parsing..." or currentQ == "Parse Error" then return end
    local full = '"' .. currentQ .. '" - ' .. currentA
    local found = false
    for i, v in ipairs(favTable) do
        if string.find(v, currentQ, 1, true) then
            table.remove(favTable, i)
            found = true
            break
        end
    end
    if not found then table.insert(favTable, full) end
    SaveFavorites()
    CheckIfFavorite()
end

function CheckIfFavorite()
    local isFav = false
    for _, v in ipairs(favTable) do
        if string.find(v, currentQ, 1, true) then
            isFav = true
            break
        end
    end
    -- MeterHeart is a String meter — use FontColor, not ImageTint
    if isFav then
        SKIN:Bang('!SetOption', 'MeterHeart', 'FontColor', '255,100,100,255')
        SKIN:Bang('!ShowMeter', 'MeterFavoriteStar')
    else
        SKIN:Bang('!SetOption', 'MeterHeart', 'FontColor', '255,255,255,100')
        SKIN:Bang('!HideMeter', 'MeterFavoriteStar')
    end
    SKIN:Bang('!UpdateMeter', 'MeterHeart')
    SKIN:Bang('!UpdateMeter', 'MeterFavoriteStar')
end

function ApplySearch(query)
    displayTable = {}
    query = string.lower(query or "")
    for i, v in ipairs(favTable) do
        if query == "" or string.find(string.lower(v), query, 1, true) then
            table.insert(displayTable, {txt = v, realIndex = i})
        end
    end
    local max = #displayTable - slots + 1
    if max < 1 then max = 1 end
    if scrollIndex > max then scrollIndex = max end
    if scrollIndex < 1 then scrollIndex = 1 end
    UpdateListUI()
end

function Scroll(dir)
    scrollIndex = scrollIndex + dir
    local max = #displayTable - slots + 1
    if max < 1 then max = 1 end
    if scrollIndex < 1 then scrollIndex = 1 end
    if scrollIndex > max then scrollIndex = max end
    UpdateListUI()
end

function DeleteByIndex(slotIndex)
    local listPos = scrollIndex + slotIndex - 1
    if displayTable and displayTable[listPos] then
        local realIdx = displayTable[listPos].realIndex
        table.remove(favTable, realIdx)
        SaveFavorites()
    end
end

function UpdateListUI()
    if not menuOpen then return end
    if not displayTable then displayTable = {} end

    for i = 1, slots do
        local listPos = scrollIndex + i - 1
        local item = displayTable[listPos]
        local slotName = 'MeterListSlot' .. i
        local delName = 'MeterDelSlot' .. i

        if item then
            local q, a = SplitQuoteAuthor(item.txt)
            local display = "\"" .. q .. "\" - " .. a
            SKIN:Bang('!SetOption', slotName, 'Text', display)
            SKIN:Bang('!SetOption', slotName, 'Hidden', '0')
            SKIN:Bang('!SetOption', delName, 'Hidden', '0')
        else
            SKIN:Bang('!SetOption', slotName, 'Text', "")
            SKIN:Bang('!SetOption', slotName, 'Hidden', '1')
            SKIN:Bang('!SetOption', delName, 'Hidden', '1')
        end
    end
    SKIN:Bang('!UpdateMeterGroup', 'ManagerList')
    SKIN:Bang('!Redraw')
end

function SetTimerInput(mins)
    local m = tonumber(mins)
    if not m or m < 1 then m = 1 end
    if m > 1440 then m = 1440 end
    local seconds = math.floor(m * 60)
    SKIN:Bang('!SetVariable', 'CurrentTimer', seconds)
    SKIN:Bang('!WriteKeyValue', 'Variables', 'CurrentTimer', seconds)
    SKIN:Bang('!Refresh')
end

function SetFreqInput(val)
    local v = tonumber(val)
    if not v or v < 0 then v = 0 end
    v = math.floor(v)
    SKIN:Bang('!WriteKeyValue', 'Variables', 'RecycleFrequency', v)
    SKIN:Bang('!Refresh')
end

function AdjustScale(delta)
    local s = tonumber(SKIN:GetVariable('Scale')) or 0.8
    s = s + (tonumber(delta) or 0)
    if s < 0.4 then s = 0.4 end
    if s > 1.6 then s = 1.6 end
    s = math.floor(s * 10 + 0.5) / 10
    SKIN:Bang('!WriteKeyValue', 'Variables', 'Scale', s)
    SKIN:Bang('!Refresh')
end

function GetQuote()
    SKIN:Bang('!SetOption', 'MeasureTimer', 'Formula', '0')
    local freq = tonumber(SKIN:GetVariable('RecycleFrequency')) or 0
    updateCounter = updateCounter + 1

    if #favTable > 0 and freq > 0 and (freq == 1 or updateCounter >= freq) then
        local randomFav = favTable[math.random(1, #favTable)]
        local q, a = SplitQuoteAuthor(randomFav)
        if q and q ~= "" then
            currentQ = q
            currentA = a
            UpdateDisplay()
            updateCounter = 0
        else
            SKIN:Bang('!CommandMeasure', 'MeasureSite', 'Update')
        end
    else
        SKIN:Bang('!CommandMeasure', 'MeasureSite', 'Update')
    end
    SKIN:Bang('!SetOption', 'MeasureTimer', 'Formula', '(MeasureTimer % #CurrentTimer#) + 1')
end
