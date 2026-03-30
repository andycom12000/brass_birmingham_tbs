local helpers = {}

function helpers.deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = helpers.deepCopy(v)  -- keys are strings/numbers, no need to deep copy
    end
    return setmetatable(copy, getmetatable(orig))
end

function helpers.tableFind(t, predicate)
    for _, v in ipairs(t) do
        if predicate(v) then return v end
    end
    return nil
end

function helpers.tableFilter(t, predicate)
    local result = {}
    for _, v in ipairs(t) do
        if predicate(v) then result[#result + 1] = v end
    end
    return result
end

function helpers.tableMap(t, fn)
    local result = {}
    for i, v in ipairs(t) do
        result[i] = fn(v, i)
    end
    return result
end

function helpers.tableContains(t, value)
    for _, v in ipairs(t) do
        if v == value then return true end
    end
    return false
end

function helpers.tableSum(t, fn)
    local sum = 0
    for _, v in ipairs(t) do sum = sum + fn(v) end
    return sum
end

function helpers.tableCount(t, predicate)
    local count = 0
    for _, v in ipairs(t) do
        if predicate(v) then count = count + 1 end
    end
    return count
end

function helpers.stableSort(t, comparator)
    local decorated = {}
    for i, v in ipairs(t) do decorated[i] = { value = v, index = i } end
    table.sort(decorated, function(a, b)
        if comparator(a.value, b.value) then return true end
        if comparator(b.value, a.value) then return false end
        return a.index < b.index
    end)
    for i, d in ipairs(decorated) do t[i] = d.value end
end

function helpers.shallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

function helpers.keys(t)
    local result = {}
    for k, _ in pairs(t) do result[#result + 1] = k end
    return result
end

return helpers
