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

    Iffy.drawSprite(object.spriteName, object.position.x, object.position.y, object.rotation or 0,
        1, 1, object.width / 2, object.height / 2)

    return true
end

return module
