local module = {}

function module.clamp(min, value, max)
    assert(type(min) == "number" and type(value) == "number" and type(max) == "number" and min <= max)

    return math.max(min, math.min(value, max))
end

function module.copyList(list)
    assert(type(list) == "table")

    local copy = {}

    for index, value in ipairs(list) do
        copy[index] = value
    end

    return copy
end

function module.appendToList(list, ...)
    assert(type(list) == "table")

    local offset = #list

    for index, value in ipairs(arg) do
        list[offset + index] = value
    end

    return true
end

function module.findMax(list)
    assert(type(list) == "table")

    if list[1] == nil then
        error("List must not be empty")
    end

    local maxIndex = nil
    local maxValue = -math.huge

    for index, value in ipairs(list) do
        if value > maxValue then
            maxIndex = index
            maxValue = value
        end
    end

    return maxIndex, maxValue
end

function module.findMin(list)
    assert(type(list) == "table")

    if list[1] == nil then
        error("List must not be empty")
    end

    local minIndex = nil
    local minValue = math.huge

    for index, value in ipairs(list) do
        if value < minValue then
            minIndex = index
            minValue = value
        end
    end

    return minIndex, minValue
end

return module
