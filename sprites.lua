Iffy = require("libraries.iffy")

local module = {}

function module.init(object)
    assert(type(object) == "table")

    Iffy.newImage(object.spriteName, object.imagePath)
    Iffy.newSprite(object.spriteName, object.spriteName, 0, 0, object.width, object.height)

    return true
end

function module.draw(object)
    assert(type(object) == "table")

    local spriteX = object.position.x - object.width / 2
    local spriteY = object.position.y - object.height / 2

    Iffy.drawSprite(object.spriteName, spriteX, spriteY, 0, 1, 1)

    return true
end

return module
