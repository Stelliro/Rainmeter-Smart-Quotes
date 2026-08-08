-- logic.lua (Version 1.2.1 — batch cache, author split fix, rate limit)
--
-- Free ZenQuotes limit: 5 requests / 30 seconds / IP
-- Docs recommend /api/quotes batch + local cache, not /api/random every time.
-- We fetch a batch rarely, rotate quotes from memory/disk, and never blank the UI.

function Initialize()
    math.randomseed(os.time() + (math.floor(os.clock() * 1000) % 100000))

    filePath = SKIN:GetVariable('CURRENTPATH') .. "Favorites.txt"
    cachePath = SKIN:GetVariable('CURRENTPATH') .. "QuotesCache.txt"
    debugPath = SKIN:GetVariable('CURRENTPATH') .. "debug.log"

    favTable = {}
    quoteCache = {}
    currentQ = "Loading..."
    currentA = "Starting..."
    lastShownKey = ""
    scrollIndex = 1
    slots = 5
    updateCounter = 0
    menuOpen = false
    webInFlight = false
    lastApiCall = 0
    cacheFetchedAt = 0

    EnsureFile(filePath)
    LoadFavorites()
    LoadQuoteCache()

    DebugLog("Initialize: favorites=" .. tostring(#favTable)
        .. " cache=" .. tostring(#quoteCache)
        .. " DebugMode=" .. tostring(SKIN:GetVariable('DebugMode')))

    -- Always show something local first — never sit on "Fetching..."
    if not ShowNextQuote(false) then
        currentQ = "No quotes yet"
        currentA = "Add favorites or wait for cache"
        UpdateDisplay()
    end

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

-- --- CONFIG HELPERS ---

function MinApiInterval()
    -- Stay under free tier 5 / 30s (avg 6s). Default 10s = max ~3 / 30s.
    local v = tonumber(SKIN:GetVariable('MinApiInterval'))
    if not v or v < 8 then v = 10 end
    if v > 120 then v = 120 end
    return v
end

function CacheTtl()
    -- How long a batch is "fresh" before a background re-fetch is allowed.
    -- Default 45 minutes — plenty of local rotation without hammering the API.
    local v = tonumber(SKIN:GetVariable('CacheTtl'))
    if not v or v < 300 then v = 2700 end
    if v > 86400 then v = 86400 end
    return v
end

function BatchUrl()
    local url = SKIN:GetVariable('URL') or 'https://zenquotes.io/api/quotes'
    -- Normalize legacy /random installs to the recommended batch endpoint
    if url:find('/api/random', 1, true) then
        url = url:gsub('/api/random', '/api/quotes')
    end
    return url
end

-- --- UTILITIES ---

function EnsureFile(path)
    local file = io.open(path, "r")
    if not file then
        file = io.open(path, "w")
        if file then file:close() end
    else
        file:close()
    end
end

function DebugEnabled()
    return tostring(SKIN:GetVariable('DebugMode') or '0') == '1'
end

function DebugLog(msg)
    local line = os.date("%Y-%m-%d %H:%M:%S") .. " | " .. tostring(msg) .. "\n"
    local f = io.open(debugPath, "a")
    if f then
        f:write(line)
        f:close()
    end
    if DebugEnabled() then
        SKIN:Bang('!Log', 'SmartQuotes: ' .. tostring(msg), 'Notice')
    end
end

function CleanString(str)
    if not str then return "" end
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
    s = s:gsub('\\/', '/')
    s = s:gsub('\\"', "'")
    s = s:gsub("\\n", " ")
    s = s:gsub("\n", " ")
    s = s:gsub("\r", " ")
    return s
end

function SplitQuoteAuthor(raw)
    -- Split on the LAST plain " - " separator (quotes may contain hyphens).
    -- Avoid reverse-index math — it was off-by-one and ate the first author letter
    -- ("Stelliro" → "telliro") and left a trailing quote on the quote text.
    raw = CleanString(raw or "")
    local sep = " - "
    local idx = nil
    local from = 1
    while true do
        local s = string.find(raw, sep, from, true)
        if not s then break end
        idx = s
        from = s + 1
    end
    if not idx then
        local qOnly = raw:gsub('^[%s"“”]+', ''):gsub('[%s"“”]+$', '')
        return qOnly, "Unknown"
    end
    local q = string.sub(raw, 1, idx - 1)
    local a = string.sub(raw, idx + #sep)
    q = q:gsub('^[%s"“”]+', ''):gsub('[%s"“”]+$', '')
    a = a:gsub('^[%s"“”]+', ''):gsub('[%s"“”]+$', '')
    return q, a
end

function QuoteKey(q, a)
    return tostring(q) .. "\0" .. tostring(a)
end

function IsPlaceholderQuote()
    if not currentQ or currentQ == "" then return true end
    if currentQ == "Loading..." or currentQ == "Parsing..." then return true end
    if currentQ == "Parse Error" or currentQ == "Network Error" then return true end
    if currentQ == "No quotes yet" or currentQ == "Offline" then return true end
    return false
end

function FormatLine(q, a)
    return '"' .. q .. '" - ' .. a
end

-- --- CACHE I/O ---

function LoadQuoteCache()
    quoteCache = {}
    cacheFetchedAt = tonumber(SKIN:GetVariable('CacheFetchedAt')) or 0
    local file = io.open(cachePath, "r")
    if not file then
        DebugLog("LoadQuoteCache: no file yet")
        return
    end
    for line in file:lines() do
        if line and line ~= "" then
            local q, a = SplitQuoteAuthor(line)
            if q and q ~= "" and a and a ~= "" and a ~= "Unknown" then
                table.insert(quoteCache, {q = q, a = a})
            end
        end
    end
    file:close()
    -- Disk cache without a timestamp is still usable; treat as slightly stale so a quiet refresh can run later
    if #quoteCache > 0 and cacheFetchedAt <= 0 then
        cacheFetchedAt = os.time() - math.floor(CacheTtl() * 0.75)
    end
    DebugLog("LoadQuoteCache: loaded " .. tostring(#quoteCache)
        .. " age=" .. tostring(os.time() - (cacheFetchedAt or 0)) .. "s")
end

function SaveQuoteCache()
    local file = io.open(cachePath, "w")
    if not file then return end
    for _, item in ipairs(quoteCache) do
        file:write(FormatLine(item.q, item.a) .. "\n")
    end
    file:close()
    SKIN:Bang('!WriteKeyValue', 'Variables', 'CacheFetchedAt', tostring(cacheFetchedAt))
end

function CacheIsFresh()
    if #quoteCache < 1 then return false end
    if cacheFetchedAt <= 0 then return false end
    return (os.time() - cacheFetchedAt) < CacheTtl()
end

function CanCallApi()
    ClearStaleFlight()
    if webInFlight then
        DebugLog("CanCallApi: blocked (in flight)")
        return false
    end
    local elapsed = os.time() - (lastApiCall or 0)
    local need = MinApiInterval()
    if lastApiCall > 0 and elapsed < need then
        DebugLog("CanCallApi: rate wait " .. tostring(need - elapsed) .. "s left (min " .. tostring(need) .. "s)")
        return false
    end
    return true
end

function ClearStaleFlight()
    -- WebParser can hang with no callback; don't block the rate gate forever
    if webInFlight and lastApiCall > 0 and (os.time() - lastApiCall) >= 20 then
        webInFlight = false
        DebugLog("ClearStaleFlight: cleared hung request after 20s")
    end
end

-- --- DISPLAY PICKERS ---

function ShowRandomFavorite(resetCounter)
    if #favTable < 1 then return false end
    -- Prefer a different favorite than what's on screen
    local pick = favTable[math.random(1, #favTable)]
    if #favTable > 1 then
        for _ = 1, 8 do
            local q, a = SplitQuoteAuthor(pick)
            if QuoteKey(q, a) ~= lastShownKey then break end
            pick = favTable[math.random(1, #favTable)]
        end
    end
    local q, a = SplitQuoteAuthor(pick)
    if not q or q == "" then return false end
    currentQ = q
    currentA = a
    lastShownKey = QuoteKey(q, a)
    UpdateDisplay()
    if resetCounter then updateCounter = 0 end
    DebugLog("ShowRandomFavorite: " .. string.sub(q, 1, 50))
    return true
end

function ShowRandomCached()
    if #quoteCache < 1 then return false end
    local item = quoteCache[math.random(1, #quoteCache)]
    if #quoteCache > 1 then
        for _ = 1, 12 do
            if QuoteKey(item.q, item.a) ~= lastShownKey then break end
            item = quoteCache[math.random(1, #quoteCache)]
        end
    end
    if not item or not item.q or item.q == "" then return false end
    currentQ = item.q
    currentA = item.a
    lastShownKey = QuoteKey(item.q, item.a)
    UpdateDisplay()
    DebugLog("ShowRandomCached: pool=" .. tostring(#quoteCache) .. " | " .. string.sub(item.q, 1, 50))
    return true
end

-- Rotate using local data only. Optionally request a quiet background refresh.
function ShowNextQuote(allowBackgroundFetch)
    local freq = tonumber(SKIN:GetVariable('RecycleFrequency')) or 0
    local showed = false

    -- Prefer the online cache when it has quotes. Favorites only on the recycle cadence
    -- (or when the cache is empty). Old path fell through to favorites every click when
    -- cache=0, which looked like "only favorites work".
    local useFavorite = (#favTable > 0 and freq > 0 and (freq == 1 or updateCounter >= freq))

    if useFavorite then
        showed = ShowRandomFavorite(true)
    end

    if not showed then
        showed = ShowRandomCached()
    end

    if not showed then
        showed = ShowRandomFavorite(false)
    end

    if allowBackgroundFetch then
        -- Refresh when empty/stale; force attempt if we still have no cache
        MaybeRefreshCache(#quoteCache < 1)
    end

    return showed
end

function MaybeRefreshCache(force)
    ClearStaleFlight()
    -- force=true only when we have nothing useful locally
    if not force and CacheIsFresh() then
        return
    end
    if #quoteCache > 0 and CacheIsFresh() then
        return
    end
    local reason = force and "empty-or-forced" or "stale-or-empty"
    RequestBatch(reason)
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
    local fullString = FormatLine(q, a)
    table.insert(favTable, 1, fullString)
    SaveFavorites()
    menuOpen = true
    CancelAdd()
end

function ParseAllQuotes(rawData)
    local results = {}
    if not rawData or rawData == "" then
        return results, "empty response"
    end

    rawData = CleanString(rawData)
    rawData = rawData:gsub("\n", " "):gsub("\r", " ")

    -- Rate-limit / error pages often aren't JSON quote arrays
    local lower = string.lower(rawData)
    if lower:find('too many requests', 1, true)
        or lower:find('rate limit', 1, true)
        or lower:find('"error"', 1, true) then
        return results, "rate limited or error body: " .. string.sub(rawData, 1, 160)
    end

    for q, a in rawData:gmatch('"q"%s*:%s*"(.-)"%s*,%s*"a"%s*:%s*"(.-)"') do
        q = CleanText(q)
        a = CleanText(a)
        if q ~= "" and a ~= "" then
            table.insert(results, {q = q, a = a})
        end
    end

    if #results < 1 then
        return results, "no quotes parsed: " .. string.sub(rawData, 1, 160)
    end
    return results, nil
end

function OnWebUpdate()
    webInFlight = false
    local measure = SKIN:GetMeasure('MeasureSite')
    if not measure then
        DebugLog("OnWebUpdate: MeasureSite missing")
        OnWebError("nomeasure")
        return
    end

    local rawData = measure:GetStringValue() or ""
    DebugLog("OnWebUpdate: bytes=" .. tostring(#rawData)
        .. " num=" .. tostring(measure:GetValue())
        .. " preview=" .. string.sub(rawData, 1, 100))

    local batch, err = ParseAllQuotes(rawData)
    if batch and #batch > 0 then
        quoteCache = batch
        cacheFetchedAt = os.time()
        SaveQuoteCache()
        DebugLog("OnWebUpdate: cached " .. tostring(#batch) .. " quotes")

        -- If UI was still a placeholder, show one now; otherwise leave current quote
        if IsPlaceholderQuote() then
            ShowRandomCached()
        end
        return
    end

    DebugLog("OnWebUpdate: parse failed — " .. tostring(err))
    -- Keep whatever is already on screen
    if IsPlaceholderQuote() then
        if not ShowRandomCached() and not ShowRandomFavorite(false) then
            currentQ = "Parse Error"
            currentA = "See debug.log"
            UpdateDisplay()
        end
    end
end

function OnWebError(kind)
    webInFlight = false
    kind = kind or "unknown"
    DebugLog("OnWebError: " .. tostring(kind))

    if IsPlaceholderQuote() then
        if not ShowRandomCached() and not ShowRandomFavorite(false) then
            currentQ = "Network Error"
            currentA = tostring(kind) .. " — see debug.log"
            UpdateDisplay()
        end
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

function ResetTimer()
    SKIN:Bang('!SetOption', 'MeasureTimer', 'Formula', '0')
    SKIN:Bang('!UpdateMeasure', 'MeasureTimer')
    SKIN:Bang('!SetOption', 'MeasureTimer', 'Formula', '(MeasureTimer % #CurrentTimer#) + 1')
end

function RequestBatch(reason)
    if not CanCallApi() then
        DebugLog("RequestBatch skipped (" .. tostring(reason) .. ")")
        return false
    end

    -- Use the configured batch URL as-is (no query cache-bust).
    -- Changing URL + ForceReload every call was hanging WebParser with no FinishAction.
    local url = BatchUrl()
    url = url:match('^([^%?]+)') or url

    webInFlight = true
    lastApiCall = os.time()
    DebugLog("RequestBatch (" .. tostring(reason) .. "): " .. url
        .. " interval=" .. tostring(MinApiInterval())
        .. "s ttl=" .. tostring(CacheTtl()) .. "s"
        .. " pool=" .. tostring(#quoteCache))

    SKIN:Bang('!SetOption', 'MeasureSite', 'URL', url)
    SKIN:Bang('!CommandMeasure', 'MeasureSite', 'Update')
    return true
end

-- Double-click: instant local rotation; never wipe UI waiting on network
function ManualRefresh()
    ResetTimer()
    updateCounter = updateCounter + 1
    DebugLog("ManualRefresh (double-click) cache=" .. tostring(#quoteCache)
        .. " favs=" .. tostring(#favTable))

    if not ShowNextQuote(true) then
        -- Nothing local yet — one careful batch; keep a calm status line
        currentA = "Updating library..."
        UpdateDisplay()
        RequestBatch("manual-empty")
    end
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
    if IsPlaceholderQuote() then return end
    local full = FormatLine(currentQ, currentA)
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
    if not IsPlaceholderQuote() then
        for _, v in ipairs(favTable) do
            if string.find(v, currentQ, 1, true) then
                isFav = true
                break
            end
        end
    end
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
    -- Floor at 1 minute so the timer never thrash-requests the network path
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

-- Timer / startup: local rotation + optional quiet batch refresh
function GetQuote()
    ResetTimer()
    updateCounter = updateCounter + 1
    DebugLog("GetQuote: counter=" .. tostring(updateCounter)
        .. " cache=" .. tostring(#quoteCache)
        .. " fresh=" .. tostring(CacheIsFresh()))

    if not ShowNextQuote(true) then
        RequestBatch("getquote-empty")
    end
end
