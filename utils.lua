local utils = {}

function utils.clamp(min, value, max)
    return math.max(min, math.min(value, max))
end

return utils
