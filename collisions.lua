Vector = require("vector")

local module = {}

local function fastCalculateCircleVectorCollision(origin, radius, position0, position1)
    assert(Vector.isVector(origin), "origin must be a vector")
    assert(type(radius) == "number" and radius > 0, "radius must be a positive number")
    assert(Vector.isVector(position0), "position0 must be a vector")
    assert(Vector.isVector(position1), "position1 must be a vector")

    local px = position1.x - position0.x
    local py = position1.y - position0.y

    local ox = position0.x - origin.x
    local oy = position0.y - origin.y

    -- algorithm and variable names taken from:
    -- https://math.stackexchange.com/questions/311921/get-location-of-vector-circle-intersection
    local a = px * px + py * py
    local b = 2 * px * ox + 2 * py * oy
    local c = ox * ox + oy * oy - radius * radius

    local sq = b * b - 4 * a * c

    -- ensure square root argument is non-negative
    if sq < 0 then
        return false
    end

    sq = math.sqrt(sq)

    -- intersection positions relative to vector (position0, position1)
    local t0 = (-b + sq) / (2 * a)
    local t1 = (-b - sq) / (2 * a)

    local check0 = (t0 >= 0 and t0 <= 1)
    local check1 = (t1 >= 0 and t1 <= 1)

    if not (check0 or check1) then
        -- no intersections
        return false
    end

    local t

    if check0 and check1 then
        -- two intersections, find the one closer to position0
        t = math.min(t0, t1)
    elseif check0 then
        -- intersection at t0
        t = t0
    else
        -- intersection at t1
        t = t1
    end

    return position0 + (position1 - position0) * t
end

function module.calculateBallPaddleCollision(ball, newBallPosition, paddle)
    local paddle0 = paddle.position + Vector.new(-paddle.width / 2, -paddle.height / 2)
    local paddle1 = paddle.position + Vector.new(paddle.width / 2, -paddle.height / 2)
    local offset = Vector.new(0, -ball.radius)

    local collisionPoint = false

    -- vertical collision
    collisionPoint = Vector.getIntersectionPoint(ball.position, newBallPosition, paddle0 + offset, paddle1 + offset)

    if collisionPoint then
        return collisionPoint, Vector.new(0, -1)
    end

    -- corner collisions
    local len = math.sqrt(0.5)

    -- left corner
    collisionPoint = fastCalculateCircleVectorCollision(paddle0, ball.radius, ball.position, newBallPosition)
    if collisionPoint and collisionPoint.y <= paddle0.y then
        return collisionPoint, Vector.new(-len, -len)
    end

    -- right corner
    collisionPoint = fastCalculateCircleVectorCollision(paddle1, ball.radius, ball.position, newBallPosition)
    if collisionPoint and collisionPoint.y <= paddle1.y then
        return collisionPoint, Vector.new(len, -len)
    end

    -- no collision found
    return false
end

function module.calculateBallWallsCollision(ball, newBallPosition, window)
    local wall0 = Vector.new()
    local wall1 = Vector.new()
    local offset = Vector.new(ball.radius, 0)

    local collisionPoint = false

    -- left wall
    wall0:setXY(0, window.height)
    wall1:setXY(0, 0)
    offset:setAngle(math.rad(0))

    collisionPoint = Vector.getIntersectionPoint(ball.position, newBallPosition, wall0 + offset, wall1 + offset)
    if collisionPoint then
        return collisionPoint, offset:getNormalized()
    end

    -- top wall
    wall0:setXY(0, 0)
    wall1:setXY(window.width, 0)
    offset:setAngle(math.rad(90))

    collisionPoint = Vector.getIntersectionPoint(ball.position, newBallPosition, wall0 + offset, wall1 + offset)
    if collisionPoint then
        return collisionPoint, offset:getNormalized()
    end

    -- right wall
    wall0:setXY(window.width, 0)
    wall1:setXY(window.width, window.height)
    offset:setAngle(math.rad(180))

    collisionPoint = Vector.getIntersectionPoint(ball.position, newBallPosition, wall0 + offset, wall1 + offset)
    if collisionPoint then
        return collisionPoint, offset:getNormalized()
    end

    return false
end

function module.calculateBallBrickCollision(ball, newBallPosition, brick)
    -- list of all collision points with respective normal vectors; the closest to ball.position
    -- will be returned
    local collisions = {}

    -- brick bounding box
    local left = brick.position.x - brick.width / 2
    local top = brick.position.y - brick.height / 2
    local right = brick.position.x + brick.width / 2
    local bottom = brick.position.y + brick.height / 2

    local bottomLeft = Vector.new(left, bottom)
    local topLeft = Vector.new(left, top)
    local topRight = Vector.new(right, top)
    local bottomRight = Vector.new(right, bottom)

    -- brick edge collisions
    local brickEdgesOutline = {
        { vector0 = bottomLeft, vector1 = topLeft, offset = Vector.new(-ball.radius, 0) },
        { vector0 = topLeft, vector1 = topRight, offset = Vector.new(0, -ball.radius) },
        { vector0 = topRight, vector1 = bottomRight, offset = Vector.new(ball.radius, 0) },
        { vector0 = bottomRight, vector1 = bottomLeft, offset = Vector.new(0, ball.radius) }
    }

    for _, edgeData in ipairs(brickEdgesOutline) do
        local collisionPoint = Vector.getIntersectionPoint(ball.position, newBallPosition,
            edgeData.vector0 + edgeData.offset, edgeData.vector1 + edgeData.offset)

        if collisionPoint then
            table.insert(collisions, { point = collisionPoint, normal = edgeData.offset:getNormalized() })
        end
    end

    -- bridge vertex collision
    local len = math.sqrt(0.5)

    local brickVerticesOutline = {
        { origin = bottomLeft, normal = Vector.new(-len, len) },
        { origin = topLeft, normal = Vector.new(-len, -len) },
        { origin = topRight, normal = Vector.new(len, -len) },
        { origin = bottomRight, normal = Vector.new(len, len) },
    }

    for _, vertexData in ipairs(brickVerticesOutline) do
        local collisionPoint = fastCalculateCircleVectorCollision(vertexData.origin, ball.radius, ball.position, newBallPosition)

        if collisionPoint then
            table.insert(collisions, { point = collisionPoint, normal = vertexData.normal })
        end
    end

    if not collisions[1] then
        return false
    end

    local collision
    local collisionDistance = math.huge

    for _, collisionData in ipairs(collisions) do
        local distance = ball.position:getDistanceTo(collisionData.point)

        if distance < collisionDistance then
            collision = collisionData
        end
    end

    return collision.point, collision.normal
end

return module
