Vector = require("vector")

local left = Vector.new(-1, 0)
local up = Vector.new(0, -1)
local right = -left
local down = -up

local module = {}

local function fastCalculateCircleVectorCollision(origin, radius, pos0, pos1)
    assert(Vector.isVector(origin), "origin must be a vector")
    assert(type(radius) == "number" and radius > 0, "radius must be a positive number")
    assert(Vector.isVector(pos0), "pos0 must be a vector")
    assert(Vector.isVector(pos1), "pos1 must be a vector")

    local px = pos1.x - pos0.x
    local py = pos1.y - pos0.y

    local ox = pos0.x - origin.x
    local oy = pos0.y - origin.y

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

    -- intersection positions relative to vector (pos0, pos1)
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
        -- two intersections, find the one closer to pos0
        t = math.min(t0, t1)
    elseif check0 then
        -- intersection at t0
        t = t0
    else
        -- intersection at t1
        t = t1
    end

    return pos0 + (pos1 - pos0) * t
end

local function calculateBallBrickCollision(ball, newBallPosition, brick)
    -- calculates first collision between ball and a single brick

    -- list of all collision points with normal vectors
    local collisions = {}

    -- brick bounding box
    local b = {
        left = brick.position.x - brick.width / 2,
        top = brick.position.y - brick.height / 2,
        right = brick.position.x + brick.width / 2,
        bottom = brick.position.y + brick.height / 2,
    }

    local bottomLeft = Vector.new(b.left, b.bottom)
    local topLeft = Vector.new(b.left, b.top)
    local topRight = Vector.new(b.right, b.top)
    local bottomRight = Vector.new(b.right, b.bottom)

    -- brick edge collisions
    local brickEdges = {
        { pos0 = bottomLeft, pos1 = topLeft, normal = left }, -- left edge
        { pos0 = topLeft, pos1 = topRight, normal = up }, -- top edge
        { pos0 = topRight, pos1 = bottomRight, normal = right }, -- right edge
        { pos0 = bottomRight, pos1 = bottomLeft, normal = down }, -- bottom edge
    }

    for _, edge in ipairs(brickEdges) do
        local offset = edge.normal * ball.radius
        local collisionPoint = Vector.getIntersectionPoint(ball.position, newBallPosition,
            edge.pos0 + offset, edge.pos1 + offset)

        if collisionPoint then
            table.insert(collisions, { point = collisionPoint, normal = edge.normal })
        end
    end

    -- brick vertex collisions
    local brickVerticesOutline = {
        { origin = bottomLeft, vNormal = down, hNormal = left },
        { origin = topLeft, vNormal = up, hNormal = left },
        { origin = topRight, vNormal = up, hNormal = right },
        { origin = bottomRight, vNormal = down, hNormal = right },
    }

    for _, vertex in ipairs(brickVerticesOutline) do
        local collisionPoint = fastCalculateCircleVectorCollision(vertex.origin, ball.radius,
            ball.position, newBallPosition)

        if collisionPoint then
            local normal
            local dx = collisionPoint.x - vertex.origin.x
            local dy = collisionPoint.y - vertex.origin.y

            if math.abs(dx) < math.abs(dy) then
                normal = vertex.vNormal
            else
                normal = vertex.hNormal
            end

            table.insert(collisions, { point = collisionPoint, normal = normal })
        end
    end

    -- find the collision closest to ball.position
    local closestCollision = false
    local collisionDistance = math.huge

    for _, collision in ipairs(collisions) do
        local distance = ball.position:getDistanceTo(collision.point)

        if distance < collisionDistance then
            closestCollision = collision
        end
    end

    if not closestCollision then
        -- no collisions detected
        return false
    end

    -- calculate new ball velocity
    local newVelocity = ball.velocity:getReflected(closestCollision.normal)

    return closestCollision.point, newVelocity
end

function module.calculateBallPaddleCollision(ball, newBallPosition, paddle)
    -- list of all collision points with normal vectors
    local collisions = {}

    local paddleLeft = paddle.position + Vector.new(-paddle.width / 2, -paddle.height / 2)
    local paddleRight = paddle.position + Vector.new(paddle.width / 2, -paddle.height / 2)
    local offset = up * ball.radius

    local velocity = ball.velocity:getLength()

    local collisionPoint = false
    local newVelocity = false

    -- vertical collision
    collisionPoint = Vector.getIntersectionPoint(ball.position, newBallPosition, paddleLeft + offset,
        paddleRight + offset)

    if collisionPoint then
        -- calculate relative offset from paddle center; resulting number is in range [-1, 1];
        -- -1 is left end of paddle, 0 is middle, +1 is right end of paddle
        local r = (collisionPoint.x - paddle.position.x) / (paddle.width / 2)

        newVelocity = Vector.fromAngle(math.rad(-90 + 45 * r), velocity)

        table.insert(collisions, { point = collisionPoint, newVelocity = newVelocity })
    end

    -- corner collisions

    -- left corner
    collisionPoint = fastCalculateCircleVectorCollision(paddleLeft, ball.radius, ball.position,
        newBallPosition)

    if collisionPoint and collisionPoint.y >= paddleLeft.y - ball.radius / 2 then
        newVelocity = Vector.fromAngle(math.rad(-90 - 45), velocity)

        table.insert(collisions, { point = collisionPoint, newVelocity = newVelocity })
    end

    -- right corner
    collisionPoint = fastCalculateCircleVectorCollision(paddleRight, ball.radius, ball.position,
        newBallPosition)

    if collisionPoint and collisionPoint.y <= paddleRight.y + ball.radius / 2 then
        newVelocity = Vector.fromAngle(math.rad(-90 + 45), velocity)

        table.insert(collisions, { point = collisionPoint, newVelocity = newVelocity })
    end

    -- find the collision closest to ball.position
    local closestCollision = false
    local collisionDistance = math.huge

    for _, collision in ipairs(collisions) do
        local distance = ball.position:getDistanceTo(collision.point)

        if distance < collisionDistance then
            closestCollision = collision
        end
    end

    if not closestCollision then
        -- no collisions detected
        return false
    end

    return closestCollision.point, closestCollision.newVelocity
end

function module.calculateBallWallsCollision(ball, newBallPosition, window)
    -- list of all collision points with normal vectors
    local collisions = {}

    -- local leftX = ball.radius
    -- local topY = ball.radius
    -- local rightX = window.width - ball.radius
    -- local bottomY = window.height
    local leftX = 0
    local topY = 0
    local rightX = window.width
    local bottomY = window.height


    local bottomLeftCorner = Vector.new(leftX, bottomY)
    local topLeftCorner = Vector.new(leftX, topY)
    local topRightCorner = Vector.new(rightX, topY)
    local bottomRightCorner = Vector.new(rightX, bottomY)

    local walls = {
        { pos0 = bottomLeftCorner, pos1 = topLeftCorner, normal = right }, -- left wall
        { pos0 = topLeftCorner, pos1 = topRightCorner, normal = down }, -- top wall
        { pos0 = topRightCorner, pos1 = bottomRightCorner, normal = left }, -- right wall
    }

    for _, wall in ipairs(walls) do
        local offset = wall.normal * ball.radius
        local collisionPoint = Vector.getIntersectionPoint(ball.position, newBallPosition, wall.pos0 + offset, wall.pos1 + offset)

        if collisionPoint then
            table.insert(collisions, { point = collisionPoint, normal = wall.normal })
        end
    end

    local closestCollision = false
    local collisionDistance = math.huge

    for _, collision in ipairs(collisions) do
        local distance = ball.position:getDistanceTo(collision.point)

        if distance < collisionDistance then
            closestCollision = collision
        end
    end

    if not closestCollision then
        -- no collision detected
        return false
    end

    -- calculate new ball velocity
    local newVelocity = ball.velocity:getReflected(closestCollision.normal)

    return closestCollision.point, newVelocity
end

function module.calculateBallBricksCollision(ball, newBallPosition, bricks)
    -- calculate all collision points for every brick and return the one closest to ball position
    local collisions = {}

    for index, brick in ipairs(bricks) do
        local point, newVelocity = calculateBallBrickCollision(ball, newBallPosition, brick)

        if point then
            local collision = {
                brick = brick,
                distance = (point - Ball.position):getLength(),
                point = point,
                newVelocity = newVelocity,
            }

            table.insert(collisions, collision)
        end
    end

    if not collisions[1] then
        return false
    end

    local closestCollision = collisions[1]

    for index, collision in ipairs(collisions) do
        if collision.distance < closestCollision.distance then
            closestCollision = collision
        end
    end

    return closestCollision.brick, closestCollision.point, closestCollision.newVelocity
end

return module
