Vector = require("vector")

local left = Vector.new(-1, 0)
local up = Vector.new(0, -1)
local right = -left
local down = -up

local TypeEnum = {
    WALL = 1,
    BRICK = 2,
    PADDLE = 3
}

local module = {}
module.TypeEnum = TypeEnum

local function findClosestCollision(ballPosition, collisions)
    local closestCollision
    local closestDistance = math.huge

    for _, collision in pairs(collisions) do
        local distance = ballPosition:getDistanceTo(collision.point)

        if distance < closestDistance then
            closestCollision = collision
            closestDistance = distance
        end
    end

    return closestCollision
end

local function calculateLineSegmentsIntersectionPoint(posA0, posA1, posB0, posB1)
    assert(Vector.isVector(posA0), "posA0 must be a vector")
    assert(Vector.isVector(posA1), "posA1 must be a vector")
    assert(Vector.isVector(posB0), "posB0 must be a vector")
    assert(Vector.isVector(posB1), "posB1 must be a vector")

    -- algorithm and variable names taken from:
    -- https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
    -- p == posA0
    -- q == posB0
    local r = posA1 - posA0
    local s = posB1 - posB0

    if r:getLength() == 0 or s:getLength() == 0 then
        return false
    end

    local rscp = r:crossProduct(s)

    if math.abs(rscp) < Vector.ZERO then
        -- parallel
        return false
    end

    local qp = (posB0 - posA0)

    local t = qp:crossProduct(s) / rscp
    local u = qp:crossProduct(r) / rscp

    if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
        return posA0 + r * t
    else
        return false
    end
end

local function calculateBallEdgesCollision(ball, newBallPosition, edges, collisionType)
    -- calculate collisions between ball and each edge and return the one closest to the ball
    local collisions = {}
    local index = 0

    for _, edge in ipairs(edges) do
        local offset = edge.normal * ball.radius
        local collisionPoint = calculateLineSegmentsIntersectionPoint(ball.position, newBallPosition,
            edge.pos0 + offset, edge.pos1 + offset)

        if collisionPoint then
            index = index + 1
            collisions[index] = { point = collisionPoint, normal = edge.normal, type = collisionType }
        end
    end

    return findClosestCollision(ball.position, collisions)
end

local function calculateLineSegmentCircleIntersectionPoint(pos0, pos1, origin, radius)
    assert(Vector.isVector(pos0), "pos0 must be a vector")
    assert(Vector.isVector(pos1), "pos1 must be a vector")
    assert(Vector.isVector(origin), "origin must be a vector")
    assert(type(radius) == "number" and radius > 0, "radius must be a positive number")

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

local function calculateBallVerticesCollision(ball, newBallPosition, vertices, collisionType)
    -- calculate collisions between ball and each vertex and return the one closest to the ball
    local collisions = {}
    local index = 0

    for _, vertex in ipairs(vertices) do
        local collisionPoint = calculateLineSegmentCircleIntersectionPoint(ball.position,
            newBallPosition, vertex.pos, ball.radius)

        if collisionPoint then
            -- calculate normal
            local normal

            local d0 = math.abs(vertex.normal0:dotProduct(ball.velocity))
            local d1 = math.abs(vertex.normal1:dotProduct(ball.velocity))

            if math.abs(d0 - d1) < Vector.ZERO then
                normal = vertex.normal1 + vertex.normal0
                normal:normalize()
            elseif math.abs(d0) >= math.abs(d1) then
                normal = vertex.normal0
            else
                normal = vertex.normal1
            end

            index = index + 1
            collisions[index] = { point = collisionPoint, normal = normal, type = collisionType}
        end
    end

    return findClosestCollision(ball.position, collisions)
end

local function calculateBallBrickCollision(ball, newBallPosition, brick)
    -- calculate all collisions between ball and brick and return the one closest to ball position

    -- precalculate halves of brick dimensions
    local halfWidth = brick.width / 2
    local halfHeight = brick.height / 2

    -- list of brick vertices
    local vertices = { -- vertices listed clockwise, below names are for brick.rotation == 0
        { pos = brick.position + Vector.new(-halfWidth, halfHeight):getRotated(brick.rotation) }, -- bottom left
        { pos = brick.position + Vector.new(-halfWidth, -halfHeight):getRotated(brick.rotation) }, -- top left
        { pos = brick.position + Vector.new(halfWidth, -halfHeight):getRotated(brick.rotation) }, -- top right
        { pos = brick.position + Vector.new(halfWidth, halfHeight):getRotated(brick.rotation) }, -- bottom right
    }

    -- list of brick edges
    local edges = {}

    -- calculate edges and normals
    for index, vertex in ipairs(vertices) do
        local pos0 = vertex.pos
        local pos1 = vertices[index % 4 + 1].pos -- index + 1 looped to (1, 4)
        local normal = (pos1 - pos0)
        normal:rotate(-math.pi / 2)
        normal:normalize()

        edges[index] = {
            pos0 = pos0,
            pos1 = pos1,
            normal = normal,
        }
    end

    -- append vertices with normals for both edges coming out of it
    for index, vertex in ipairs(vertices) do
        vertex.normal0 = edges[index].normal
        vertex.normal1 = edges[(index - 2) % 4 + 1].normal -- index - 1 looped to (1, 4)
    end

    local collisions = {
        calculateBallEdgesCollision(ball, newBallPosition, edges, TypeEnum.BRICK),
        calculateBallVerticesCollision(ball, newBallPosition, vertices, TypeEnum.BRICK),
    }

    return findClosestCollision(ball.position, collisions)
end

local function calculateBallBricksCollisions(ball, newBallPosition, bricks)
    -- calculate all collision points for every brick and return the one closest to ball position
    local collisions = {}
    local index = 0

    for _, brick in ipairs(bricks) do
        local collision = calculateBallBrickCollision(ball, newBallPosition, brick)

        if collision then
            -- append collision table with brick
            collision.hitElement = brick

            index = index + 1
            collisions[index] = collision
        end
    end

    return findClosestCollision(ball.position, collisions)
end

local function calculateBallPaddleCollisions(ball, newBallPosition, paddle)
    -- list of all collision points with normal vectors
    local collisions = {}

    local paddleLeft = paddle.position + Vector.new(-paddle.width / 2, -paddle.height / 2)
    local paddleRight = paddle.position + Vector.new(paddle.width / 2, -paddle.height / 2)
    local offset = up * ball.radius

    -- absolute max angle for reflected ball velocity from vertical up
    local angleRange = 45

    local collisionPoint
    local newAngle

    -- vertical collision
    collisionPoint = calculateLineSegmentsIntersectionPoint(ball.position, newBallPosition,
        paddleLeft + offset, paddleRight + offset)

    if collisionPoint then
        -- calculate relative offset from paddle center; resulting number is in range [-1, 1];
        -- -1 is left end of paddle, 0 is middle, +1 is right end of paddle
        local xOffset = (collisionPoint.x - paddle.position.x) / (paddle.width / 2)
        newAngle = math.rad(-90 + angleRange * xOffset)

        table.insert(collisions, { point = collisionPoint, newAngle = newAngle, type = TypeEnum.PADDLE })
    end

    -- corner collisions

    -- left corner
    collisionPoint = calculateLineSegmentCircleIntersectionPoint(ball.position, newBallPosition,
        paddleLeft, ball.radius)

    if collisionPoint and collisionPoint.y <= paddleLeft.y then
        newAngle = math.rad(-90 - angleRange)

        table.insert(collisions, { point = collisionPoint, newAngle = newAngle, type = TypeEnum.PADDLE })
    end

    -- right corner
    collisionPoint = calculateLineSegmentCircleIntersectionPoint(ball.position, newBallPosition,
        paddleRight, ball.radius)

    if collisionPoint and collisionPoint.y <= paddleRight.y then
        newAngle = math.rad(-90 + angleRange)

        table.insert(collisions, { point = collisionPoint, newAngle = newAngle, type = TypeEnum.PADDLE  })
    end


    -- horizontal collisions
    local ballYInsidePaddleYRange = (
        ball.position.y + ball.radius > paddle.position.y and
        ball.position.y - ball.radius <= paddle.position.y + paddle.height / 2
    )
    if ballYInsidePaddleYRange then

        local ballXInsideLeftPaddleSide = ball.position.x < paddle.position.x and ball.position.x + ball.radius > paddleLeft.x
        local ballXInsideRightPaddleSide = ball.position.x > paddle.position.x and ball.position.x - ball.radius < paddleRight.x
        local leftDegs, rightDegs

        if ballXInsideLeftPaddleSide then
            leftDegs = 180
        end

        if ballXInsideRightPaddleSide then
            rightDegs = 0
        end

        if leftDegs ~= nil or rightDegs ~= nil then
            local yOffset = (ball.position.y - paddle.position.y) / (paddle.height)
            local horizontalDegs = leftDegs or rightDegs

            local sign
            if leftDegs ~= nil then sign = -1 else sign = 1 end

            -- compute new angle - in case it is 0 or 180 degs, lift it up 5 degrees
            local degs = horizontalDegs + (angleRange * yOffset) * sign
            if degs < horizontalDegs + 1.0 and degs > horizontalDegs - 1.0 then newAngle = math.rad(horizontalDegs - (5 * sign)) else newAngle = math.rad(degs) end

            -- if paddle speeds towards the ball, increase the ball's velocity
            local dVelocity
            local paddleMovesToBall = (leftDegs ~= nil and paddle.velocity.x < 0) or (rightDegs ~= nil and paddle.velocity.x > 0)
            if paddleMovesToBall then
                local velocityBoost = 1.3
                dVelocity = math.max(ball.dVelocity, math.abs(paddle.dVelocity) * velocityBoost)
            end

            table.insert(collisions, { point = Vector.new((paddle.position.x + (paddle.width / 2) * sign) + ball.radius * sign, ball.position.y), newAngle = newAngle, type = TypeEnum.PADDLE, newDVelocity = dVelocity })
        end

    end


    return findClosestCollision(ball.position, collisions)
end

local function calculateFlatAngleWallCollision(ball, wallCollision)
    local ballVelocityDegs = math.deg(ball.velocity:getAngle())
    local leftDegs = -180
    local rightDegs = 0

    local change
    local newAngle
    if ballVelocityDegs >= leftDegs and ballVelocityDegs < leftDegs + 25 then
        local diff = ballVelocityDegs - leftDegs
        change = -math.max(0, 15 - math.abs(diff))
    end

    if ballVelocityDegs <= rightDegs and ballVelocityDegs > rightDegs - 25 then
        local diff = ballVelocityDegs - rightDegs
        change = math.max(0, 15 - math.abs(diff))
    end

    if change and wallCollision then
        local newVelocity = ball.velocity:copy()
        newVelocity:reflect(wallCollision.normal)
        local angle = newVelocity:getAngle()

        newAngle = math.rad(math.deg(angle) + change)
    end

    return newAngle
end

local function calculateBallWallsCollisions(ball, newBallPosition, window)
    local minX = 0
    local maxX = window.width
    local minY = 0
    local maxY = window.height

    local bottomLeftCorner = Vector.new(minX, maxY)
    local topLeftCorner = Vector.new(minX, minY)
    local topRightCorner = Vector.new(maxX, minY)
    local bottomRightCorner = Vector.new(maxX, maxY)

    local walls = {
        { pos0 = bottomLeftCorner, pos1 = topLeftCorner, normal = right }, -- left wall
        { pos0 = topLeftCorner, pos1 = topRightCorner, normal = down }, -- top wall
        { pos0 = topRightCorner, pos1 = bottomRightCorner, normal = left }, -- right wall
    }

    local closestWallCollision = calculateBallEdgesCollision(ball, newBallPosition, walls, TypeEnum.WALL)

    -- change ball velocity angle when too "flat" on wall hit
    local newAngle = calculateFlatAngleWallCollision(ball, closestWallCollision)
    if newAngle then
        closestWallCollision.newAngle = newAngle
        closestWallCollision.normal = nil
    end


    -- prevent ball going through left border
    if ball.position.x - ball.radius < bottomLeftCorner.x then
        return { point = Vector.new(bottomLeftCorner.x + ball.radius, ball.position.y), normal=left, type = TypeEnum.Wall }
    end

    -- prevent ball going through left border
    if ball.position.x + ball.radius > bottomRightCorner.x then
        return { point = Vector.new(bottomRightCorner.x - ball.radius, ball.position.y), normal=right, type = TypeEnum.Wall }
    end



    return closestWallCollision
end

function module.calculateNextCollision(ball, newBallPosition, bricks, paddle, window)
    local collisions = {
        calculateBallWallsCollisions(ball, newBallPosition, window),
        calculateBallPaddleCollisions(ball, newBallPosition, paddle),
        calculateBallBricksCollisions(ball, newBallPosition, bricks),
    }

    local collision = findClosestCollision(ball.position, collisions)

    if not collision then return false end

    local newVelocity = ball.velocity:copy()

    local newDVelocity = collision.newDVelocity

    if collision.normal then
        -- calculate reflected velocity using normal
        newVelocity:reflect(collision.normal)
    elseif collision.newAngle then
        -- calculate reflected velocity using newAngle
        newVelocity:setAngle(collision.newAngle)
    else
        -- unexpected variant
        error()
    end

    return collision.point, newVelocity, collision.hitElement, collision.type, newDVelocity
end

return module
