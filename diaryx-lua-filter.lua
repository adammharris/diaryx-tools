-- Show selected metadata fields at the top of the document as a DefinitionList.
-- Usage:
--   pandoc -f markdown -t html --standalone \
--     --lua-filter=diaryx-lua-filter.lua \
--     "Diaryx Writing Specification.md" -o out.html

local order = {
    'title', 'author', 'created', 'updated', 'visibility',
    'format', 'reachable'
}

local function meta_to_inlines(v)
    -- Convert Meta values to a list of Inlines, preserving links if present.
    if v == nil then
        return pandoc.Inlines {}
    end

    -- Check if it's a Pandoc Meta type
    if pandoc.utils.type(v) == 'Inlines' then
        return v
    elseif pandoc.utils.type(v) == 'string' then
        return pandoc.Inlines { pandoc.Str(v) }
    elseif pandoc.utils.type(v) == 'boolean' then
        return pandoc.Inlines { pandoc.Str(tostring(v)) }
    elseif pandoc.utils.type(v) == 'List' then
        -- MetaList - join items with commas
        local acc = pandoc.List()
        for i, item in ipairs(v) do
            local item_inlines = meta_to_inlines(item)
            acc:extend(item_inlines)
            if i < #v then
                acc:insert(pandoc.Str(','))
                acc:insert(pandoc.Space())
            end
        end
        return pandoc.Inlines(acc)
    elseif pandoc.utils.type(v) == 'Blocks' then
        -- MetaBlocks - extract inlines from blocks
        local inlines = pandoc.List()
        for _, block in ipairs(v) do
            if block.t == 'Para' or block.t == 'Plain' then
                inlines:extend(block.content)
            end
        end
        return pandoc.Inlines(inlines)
    else
        -- Fallback: stringify
        local str = pandoc.utils.stringify(v)
        if str and str ~= '' then
            return pandoc.Inlines { pandoc.Str(str) }
        end
        return pandoc.Inlines {}
    end
end

local function linkify(inlines)
    -- If the value is a single string that looks like a URL or email, make it a link.
    if #inlines == 1 and inlines[1].t == 'Str' then
        local s = inlines[1].text
        if type(s) == 'string' then
            if s:match('^https?://') then
                return pandoc.Inlines { pandoc.Link(inlines, s) }
            elseif s:match('^[%w%._%%+%-]+@[%w%.%-_]+%.[%a]+$') then
                return pandoc.Inlines { pandoc.Link(inlines, 'mailto:' .. s) }
            end
        end
    end
    return inlines
end

function Pandoc(doc)
    local items = {}
    local seen = {}

    -- First, add ordered properties
    for _, key in ipairs(order) do
        local v = doc.meta[key]
        if v ~= nil then
            local label = pandoc.Inlines { pandoc.Str(key) }
            local value = linkify(meta_to_inlines(v))
            table.insert(items, { label, { pandoc.Plain(value) } })
            seen[key] = true
        end
    end

    -- Then, add all remaining properties that weren't in the order list
    for key, v in pairs(doc.meta) do
        if not seen[key] then
            local label = pandoc.Inlines { pandoc.Str(key) }
            local value = linkify(meta_to_inlines(v))
            table.insert(items, { label, { pandoc.Plain(value) } })
        end
    end

    if #items > 0 then
        local header = pandoc.Header(2, 'Metadata')
        local dl = pandoc.DefinitionList(items)
        local hr = pandoc.HorizontalRule()
        local div = pandoc.Div({ header, dl, hr }, pandoc.Attr('', { 'diaryx-meta' }))
        table.insert(doc.blocks, 1, div)
    end

    return doc
end
