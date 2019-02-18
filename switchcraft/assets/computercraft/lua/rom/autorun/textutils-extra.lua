--[[
Features:

- All arguments are put into a table, so that they don't have to be put in any particular order, like how it is in read().
- Type error protection has been condensed into a more understandable form.
- Adds a few arguments, including those from read(), and others that would never make it into read():
  - replaceChar (_sReplaceChar)
  - history (_tHistory)
  - complete (_fnComplete)
  - prefix (_sDefault)
  - limit (number): Size of the input box, defaults to the end of the screen
  - newline (boolean): If set to false will remove the newline read appends
  - completeBGColor (number): Changes the Background color of the suggested completion values
  - completeTextColor (number): Changes the Text color of the suggested completion values
  - filter (function): takes the current input string and feeds it to a function. The function can then manipulate the string and return it.
  - writer (function): changes the function that is used to write to the screen.
  - customkeys (table): a table consisting of all the "special" keys, any and all of which can now be redirected to any other key. Keys that can be redirected (if not redirected, their default is just the key name, prefixed by "keys."): 
    - enter
    - up
    - down
    - left
    - right
    - backspace
    - home
    - delete
    - tab
    - end (["end"])
]]
function textutils.prompt( _tOptions )
    local tVerify = {replaceChar = "string", history = "table", complete = "function", prefix = "string", limit = "number", newline = "boolean", completeBGColor = "number", completeTextColor = "number", filter = "function", customkeys = "table", writer = "function"}
    if not _tOptions then
        _tOptions = {}
    end
    for k, v in pairs(tVerify) do
        if _tOptions[k] ~= nil and type( _tOptions[k] ) ~= v then
            error( "bad argument " .. k .. " (expected " .. v .. " got ".. type( _tOptions[k] ) .. ")", 2)
        end
    end
    
    term.setCursorBlink( true )

    local sLine
    if type( _tOptions.prefix ) == "string" then
        sLine = _tOptions.prefix
    else
        sLine = ""
    end
    local nhistoryPos
    local nPos = #sLine
    if _tOptions.replaceChar then
        _tOptions.replaceChar = string.sub( _tOptions.replaceChar, 1, 1 )
    end
    if not _tOptions.customkeys then
        _tOptions.customkeys = {}
    end
    local tCustomKeyNames = {enter = keys.enter, up = keys.up, down = keys.down, left = keys.left, right = keys.right, backspace = keys.backspace, home = keys.home, delete = keys.delete, tab = keys.tab, ["end"] = keys["end"]}
    for k, v in pairs(tCustomKeyNames) do
        if not _tOptions.customkeys[k] then
            _tOptions.customkeys[k] = v
        end
    end

    local tCompletions
    local nCompletion
    local function recomplete()
        if _tOptions.complete and nPos == string.len(sLine) then
            tCompletions = _tOptions.complete( sLine )
            if tCompletions and #tCompletions > 0 then
                nCompletion = 1
            else
                nCompletion = nil
            end
        else
            tCompletions = nil
            nCompletion = nil
        end
    end

    local function uncomplete()
        tCompletions = nil
        nCompletion = nil
    end
    
    local sx = term.getCursorPos()
    
    local w
    if not _tOptions.limit then
        w = term.getSize()
    else
        w = _tOptions.limit+sx
    end
    
    local writeFunc = term.write
    
    if _tOptions.writer then
        writeFunc = _tOptions.writer
    end

    local function redraw( _bClear )
        local nScroll = 0
        if sx + nPos >= w then
            nScroll = (sx + nPos) - w
        end

        local cx,cy = term.getCursorPos()
        term.setCursorPos( sx, cy )
        local sReplace = (_bClear and " ") or _tOptions.replaceChar
        if sReplace then
            writeFunc( string.sub( string.rep( sReplace, math.max( string.len(sLine) + 1, 0 ) ),  nScroll + 1, nScroll + w ) )
        else
            writeFunc( string.sub( sLine, nScroll + 1, nScroll + w ) )
        end

        if nCompletion then
            local sCompletion = tCompletions[ nCompletion ]
            local oldText, oldBg
            if not _bClear then
                oldText = term.getTextColor()
                oldBg = term.getBackgroundColor()
                if not _tOptions.completeTextColor then
                    term.setTextColor( colors.white )
                else
                    term.setTextColor( _tOptions.completeTextColor )
                end
                if not _tOptions.completeBGColor then
                    term.setBackgroundColor( colors.gray )
                else
                    term.setBackgroundColor( _tOptions.completeBGColor )
                end
            end
            if sReplace then
                writeFunc( string.rep( sReplace, string.len( sCompletion ) ) )
            else
                writeFunc( sCompletion )
            end
            if not _bClear then
                term.setTextColor( oldText )
                term.setBackgroundColor( oldBg )
            end
        end

        term.setCursorPos( sx + nPos - nScroll, cy )
    end
    
    local function clear()
        redraw( true )
    end
    
    recomplete()
    redraw()

    local function acceptCompletion()
        if nCompletion then
            -- Clear
            clear()

            -- Find the common prefix of all the other suggestions which start with the same letter as the current one
            local sCompletion = tCompletions[ nCompletion ]
            sLine = sLine .. sCompletion
            nPos = string.len( sLine )

            -- Redraw
            recomplete()
            redraw()
        end
    end
    while true do
        local sEvent, param = os.pullEvent()

        if sEvent == "char" then
            -- Typed key
            clear()
            sLine = string.sub( sLine, 1, nPos ) .. param .. string.sub( sLine, nPos + 1 )
            nPos = nPos + 1
            recomplete()
            redraw()

        elseif sEvent == "paste" then
            -- Pasted text
            clear()
            sLine = string.sub( sLine, 1, nPos ) .. param .. string.sub( sLine, nPos + 1 )
            nPos = nPos + string.len( param )
            recomplete()
            redraw()

        elseif sEvent == "key" then
            if _tOptions.customkeys.enter == param then
                -- Enter
                if nCompletion then
                    clear()
                    uncomplete()
                    redraw()
                end
                break
                
            elseif _tOptions.customkeys.left == param then
                -- Left
                if nPos > 0 then
                    clear()
                    nPos = nPos - 1
                    recomplete()
                    redraw()
                end
                
            elseif _tOptions.customkeys.right == param then
                -- Right                
                if nPos < string.len(sLine) then
                    -- Move right
                    clear()
                    nPos = nPos + 1
                    recomplete()
                    redraw()
                else
                    -- Accept autocomplete
                    acceptCompletion()
                end

            elseif  _tOptions.customkeys.up == param or _tOptions.customkeys.down == param then
                -- Up or down
                if nCompletion then
                    -- Cycle completions
                    clear()
                    if _tOptions.customkeys.up == param then
                        nCompletion = nCompletion - 1
                        if nCompletion < 1 then
                            nCompletion = #tCompletions
                        end
                    elseif _tOptions.customkeys.down == param then
                        nCompletion = nCompletion + 1
                        if nCompletion > #tCompletions then
                            nCompletion = 1
                        end
                    end
                    redraw()

                elseif _tOptions.history then
                    -- Cycle history
                    clear()
                    if _tOptions.customkeys.up == param then
                        -- Up
                        if nhistoryPos == nil then
                            if #_tOptions.history > 0 then
                                nhistoryPos = #_tOptions.history
                            end
                        elseif nhistoryPos > 1 then
                            nhistoryPos = nhistoryPos - 1
                        end
                    elseif _tOptions.customkeys.down == param then
                        -- Down
                        if nhistoryPos == #_tOptions.history then
                            nhistoryPos = nil
                        elseif nhistoryPos ~= nil then
                            nhistoryPos = nhistoryPos + 1
                        end                        
                    end
                    if nhistoryPos then
                        sLine = _tOptions.history[nhistoryPos]
                        nPos = string.len( sLine ) 
                    else
                        sLine = ""
                        nPos = 0
                    end
                    uncomplete()
                    redraw()

                end

            elseif _tOptions.customkeys.backspace == param then
                -- Backspace
                if nPos > 0 then
                    clear()
                    sLine = string.sub( sLine, 1, nPos - 1 ) .. string.sub( sLine, nPos + 1 )
                    nPos = nPos - 1
                    recomplete()
                    redraw()
                end

            elseif _tOptions.customkeys.home == param then
                -- Home
                if nPos > 0 then
                    clear()
                    nPos = 0
                    recomplete()
                    redraw()
                end

            elseif _tOptions.customkeys.delete == param then
                -- Delete
                if nPos < string.len(sLine) then
                    clear()
                    sLine = string.sub( sLine, 1, nPos ) .. string.sub( sLine, nPos + 2 )
                    recomplete()
                    redraw()
                end

            elseif _tOptions.customkeys["end"] == param then
                -- End
                if nPos < string.len(sLine ) then
                    clear()
                    nPos = string.len(sLine)
                    recomplete()
                    redraw()
                end

            elseif _tOptions.customkeys.tab == param then
                -- Tab (accept autocomplete)
                acceptCompletion()

            end
        
        elseif sEvent == "term_resize" then
            -- Terminal resized
            if not _tOptions.limit then
                w = term.getSize()
            else
                w = _tOptions.limit
            end
            redraw()

        end

        if _tOptions.filter then
            -- Filter out all unwanted characters/strings using a function defined by the user
            local sPreFilterLine = sLine
            sLine = _tOptions.filter( sLine )
            if string.len( sPreFilterLine ) ~= string.len( sLine ) then
                local sPreClearLine = sLine
                sLine = sPreFilterLine
                clear()
                sLine = sPreClearLine
            end
            if not sLine then
                sLine = sPreFilterLine
            else
                if nPos >= ( string.len( sPreFilterLine ) - string.len( sLine ) ) then
                    nPos = nPos - ( string.len( sPreFilterLine ) - string.len( sLine ) )
                else
                    nPos = 0
                end
            end
            redraw()
        end
    end

    local cx, cy = term.getCursorPos()
    term.setCursorBlink( false )
    if _tOptions.newline == nil or _tOptions.newline == true then
        term.setCursorPos( 1, cy + 1)
    end
    
    return sLine
end
