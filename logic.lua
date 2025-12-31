-- logic.lua (Version 36.0 - Fix Loading Order)

function Initialize()
    SKIN:Bang('!SetOption', 'MeterAuthor', 'Text', 'Ready')
    SKIN:Bang('!UpdateMeter', 'MeterAuthor')
    SKIN:Bang('!Redraw')

    -- 1. Setup Variables
    filePath = SKIN:GetVariable('CURRENTPATH') .. "Favorites.txt"
    favTable = {}
    currentQ = "Loading..."
    currentA = ""
    scrollIndex = 1
    slots = 5
    updateCounter = 0

    -- 2. Ensure File Exists
    local file = io.open(filePath, "r")
    if not file then
        file = io.open(filePath, "w")
        file:close()
    else
        file:close()
    end
    
    -- 3. LOAD DATA FIRST (Crucial Fix)
    LoadFavorites()

    -- 4. Restore Menu State (Now that data is ready)
    local savedState = SKIN:GetVariable('MenuState')
    if savedState == '1' then
        menuOpen = true
        SKIN:Bang('!ShowMeterGroup', 'SettingsMenu')
        -- Small delay to let the visual elements settle
        SKIN:Bang('!Delay', '50')
        SKIN:Bang('!CommandMeasure', 'MeasureScript', 'ApplySearch("")')
    else
        menuOpen = false
    end
end

-- --- VISUALS ---

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
    SKIN:Bang('!Redraw')
end

function CleanText(s)
    if not s then return "" end
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

-- --- FEATURES ---

function WebSearch(query)
    if query == "" then return end
    SKIN:Bang('["https://www.google.com/search?q=quotes+by+' .. query .. '"]')
end

function AddManualQuote(q, a)
    if q == "" or a == "" then return end
    q = CleanText(q)
    a = CleanText(a)
    local fullString = '"' .. q .. '"' .. " - " .. a
    table.insert(favTable, 1, fullString)
    SaveFavorites()
    CancelAdd()
    if menuOpen then ApplySearch("") end
end

function OnWebUpdate()
    SKIN:Bang('!SetOption', 'MeterQuote', 'Text', 'Parsing...')
    SKIN:Bang('!Redraw')

    local measure = SKIN:GetMeasure('MeasureSite')
    if not measure then return end

    local rawData = measure:GetStringValue()
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
    SKIN:Bang('!CommandMeasure', 'MeasureTimer', 'ExecuteBatch 1')
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
    for _, quote in ipairs(favTable) do file:write(quote .. "\n") end
    file:close()
    if menuOpen then
        ApplySearch(SKIN:GetMeasure('MeasureInputSearch'):GetStringValue() or "")
    end
end

function ToggleFavorite()
    if currentQ == "Loading..." or currentQ == "Parsing..." or currentQ == "Parse Error" then return end
    local full = currentQ .. " - " .. currentA
    local found = false
    for i,v in ipairs(favTable) do
        if v == full then 
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
    local full = currentQ .. " - " .. currentA
    local isFav = false
    for _,v in ipairs(favTable) do
        if v == full then isFav = true break end
    end
    if isFav then
        SKIN:Bang('!SetOption', 'MeterHeart', 'ImageTint', '255,100,100,255')
        SKIN:Bang('!ShowMeter', 'MeterFavoriteStar')
    else
        SKIN:Bang('!SetOption', 'MeterHeart', 'ImageTint', '255,255,255,100')
        SKIN:Bang('!HideMeter', 'MeterFavoriteStar')
    end
    SKIN:Bang('!UpdateMeter', 'MeterHeart')
end

function ApplySearch(query)
    displayTable = {}
    query = string.lower(query)
    for i,v in ipairs(favTable) do
        if query == "" or string.find(string.lower(v), query) then
            table.insert(displayTable, {txt=v, realIndex=i})
        end
    end
    local max = #displayTable - slots + 1
    if max < 1 then max = 1 end
    if scrollIndex > max then scrollIndex = max end
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
    if displayTable[listPos] then
        local realIdx = displayTable[listPos].realIndex
        table.remove(favTable, realIdx)
        SaveFavorites()
    end
end

function UpdateListUI()
    if not menuOpen then return end
    for i=1, slots do
        local listPos = scrollIndex + i - 1
        local item = displayTable[listPos]
        if item then
            local cleanText = item.txt
            if string.len(cleanText) > 40 then cleanText = string.sub(cleanText, 1, 37) .. "..." end
            SKIN:Bang('!SetOption', 'MeterListSlot'..i, 'Text', cleanText)
            SKIN:Bang('!SetOption', 'MeterDelSlot'..i, 'Hidden', '0')
            SKIN:Bang('!SetOption', 'MeterDelBG'..i, 'Hidden', '0')
        else
            SKIN:Bang('!SetOption', 'MeterListSlot'..i, 'Text', "")
            SKIN:Bang('!SetOption', 'MeterDelSlot'..i, 'Hidden', '1')
            SKIN:Bang('!SetOption', 'MeterDelBG'..i, 'Hidden', '1')
        end
    end
    SKIN:Bang('!UpdateMeterGroup', 'ManagerList')
    SKIN:Bang('!Redraw')
end

function SetTimerInput(mins)
    local seconds = tonumber(mins) * 60
    SKIN:Bang('!SetVariable', 'CurrentTimer', seconds)
    SKIN:Bang('!WriteKeyValue', 'Variables', 'CurrentTimer', seconds)
    SKIN:Bang('!Refresh')
end

function SetFreqInput(val)
    local v = tonumber(val)
    if v < 0 then v = 0 end 
    SKIN:Bang('!WriteKeyValue', 'Variables', 'RecycleFrequency', v)
    SKIN:Bang('!Refresh')
end

function GetQuote()
    SKIN:Bang('!SetOption', 'MeasureTimer', 'Formula', '0')
    local freq = tonumber(SKIN:GetVariable('RecycleFrequency'))
    updateCounter = updateCounter + 1
    
    if #favTable > 0 and freq > 0 and (freq == 1 or updateCounter >= freq) then
        local randomFav = favTable[math.random(1, #favTable)]
        local s, e = string.find(randomFav, " %- ")
        if s then
            currentQ = string.sub(randomFav, 1, s-1)
            currentA = string.sub(randomFav, e+1)
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