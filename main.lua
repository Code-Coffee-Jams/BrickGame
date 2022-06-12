Utils = require("utils")
Vector = require("vector")
Sprites = require("sprites")
Collisions = require("collisions")

-- screen size
local window = {
    width = 800,
    height = 600,
}

-- keyboard key names
local KeyEnum = {
    LEFT = "left",
    RIGHT = "right",
    SPACE = "space",
    ESC = "escape",
    ENTER = "return",
}

-- game states
local GameStateEnum = {
    MENU = 0,
    STARTING = 1,
    PLAYING = 2,
    FINISHED = 3,
    WINNER = 4,
    GAMEOVER = 5,
}

-- paddle movement directions
local left = Vector.new(-1, 0)
local right = -left

-- global state
local gameState = GameStateEnum.MENU
local level = 1
local finishTimer = 0
local finishDelay = 3 -- delay between finishing a level and starting a new one; in seconds
local livesLeft = 0

-- images, sprites, game entities/objects
local PADDLE_Y_OFFSET = 64

local paddle = {
    imagePath = "assets/png/paddleRed.png",
    spriteName = "paddle",
    width = 104,
    height = 24,
    position = Vector.new(),
    velocity = Vector.new(),
    acceleration = Vector.new(),
    dVelocity = 500,
    dAcceleration = 5,
    dFrictionDeceleration = 1.5,
}

local ball = {
    imagePath = "assets/png/ballBlue.png",
    spriteName = "ball",
    radius = 22 / 2,
    width = 22,
    height = 22,
    position = Vector.new(),
    velocity = Vector.new(),
    dVelocity = 300,
}

-- template for bricks
local brickTemplate = {
    imagePath = "assets/png/element_grey_rectangle.png",
    spriteName = "brick_grey",
    width = 64,
    height = 32,
}

-- list of actual brick objects used in game
local bricks = {}

-- list of levels
local HPI = math.pi / 2
local QPI = math.pi / 4
local SQ2 = math.sqrt(2)

local levels = {
    [1] = {
        { -3, 0, 0 },
        { -2, 0, 0 },
        { -1, 0, 0 },
        { 0, 0, 0 },
        { 1, 0, 0 },
        { 2, 0, 0 },
        { 3, 0, 0 },
        { -3, -1, 0 },
        { -2, -1, 0 },
        { -1, -1, 0 },
        { 0, -1, 0 },
        { 1, -1, 0 },
        { 2, -1, 0 },
        { 3, -1, 0 },
    },
    [2] = {
        { -3, 0, HPI },
        { -2.25, 0.5, 0 },
        { -2.25, -0.5, 0 },
        { -1.5, 0, HPI },
        { -0.75, 0.5, 0 },
        { -0.75, -0.5, 0 },
        { 0, 0, HPI },
        { 0.75, 0.5, 0 },
        { 0.75, -0.5, 0 },
        { 1.5, 0, HPI },
        { 2.25, 0.5, 0 },
        { 2.25, -0.5, 0 },
        { 3, 0, HPI },
    },
    [3] = {
        { -2 * SQ2, 0, QPI },
        { -1.5 * SQ2, 0, QPI },
        { -SQ2, 0, QPI },
        { -SQ2 / 2, 0, QPI },
        { 0, 0, QPI },
        { SQ2 / 2, 0, QPI },
        { SQ2, 0, QPI },
        { 1.5 * SQ2, 0, QPI },
        { 2 * SQ2, 0, QPI },
        { -2 * SQ2, -SQ2, QPI },
        { -1.5 * SQ2, -SQ2, QPI },
        { -SQ2, -SQ2, QPI },
        { -SQ2 / 2, -SQ2, QPI },
        { 0, -SQ2, QPI },
        { SQ2 / 2, -SQ2, QPI },
        { SQ2, -SQ2, QPI },
        { 1.5 * SQ2, -SQ2, QPI },
        { 2 * SQ2, -SQ2, QPI },
    },
}

local function createBrick(x, y, rotation)
    assert(type(x) == "number")
    assert(type(y) == "number")
    if rotation ~= nil then assert(type(rotation) == "number") else rotation = 0.0 end

    return {
        spriteName = brickTemplate.spriteName,
        width = brickTemplate.width,
        height = brickTemplate.height,
        position = Vector.new(x, y),
        rotation = rotation,
    }
end

local function resetBall()
    ball.position:setXY(window.width / 2, paddle.position.y - (ball.height + 8))
    ball.velocity:setXY(0, 1)
end

local function resetPaddle()
    paddle.position:setXY(window.width / 2, window.height - PADDLE_Y_OFFSET)
    paddle.velocity:setXY(0, 0)
    paddle.acceleration:setXY(0, 0)

    -- check for keys pressed and not released before resetting
    if love.keyboard.isDown(KeyEnum.LEFT) then paddle.acceleration:transform(left) end
    if love.keyboard.isDown(KeyEnum.RIGHT) then paddle.acceleration:transform(right) end
end

local function loadLevel(level)
    assert(levels[level] ~= nil)
    assert(levels[level][1] ~= nil)

    bricks = {}

    local centerX = window.width / 2
    local centerY = window.height / 3

    for index, brick in ipairs(levels[level]) do
        local x = centerX + brick[1] * brickTemplate.width
        local y = centerY + brick[2] * brickTemplate.height
        local r = brick[3]

        bricks[index] = createBrick(x, y, r)
    end

    return true
end

local function resetGame()
    -- setup global state
    livesLeft = 3

    -- setup paddle and ball
    resetPaddle()
    resetBall()

    -- setup bricks
    loadLevel(level)
end

local function updateBall(dt)
    -- calculate ball position after this update
    local dBallPosition = ball.velocity * ball.dVelocity * dt
    local newBallPosition = ball.position + dBallPosition

    -- check ball outside playing area
    if newBallPosition.y > window.height then
        livesLeft = livesLeft - 1

        if livesLeft > 0 then
            resetBall()

            gameState = GameStateEnum.STARTING
        else
            gameState = GameStateEnum.GAMEOVER
        end

        return
    end

    local collisionPoint, newVelocity, hitElement = Collisions.calculateNextCollision(ball,
        newBallPosition, bricks, paddle, window)

    if not collisionPoint then
        -- no collision detected, simply move ball

        ball.position:transform(dBallPosition)
        return true
    else
        if hitElement then
            -- hit a brick, remove it from list
            for index, brick in ipairs(bricks) do
                if brick == hitElement then
                    table.remove(bricks, index)
                    break
                end
            end

            -- check if it was the last brick
            if not bricks[1] then
                gameState = GameStateEnum.FINISHED
                return true
            end
        end

        -- apply new reflected velocity
        ball.velocity = newVelocity

        -- calculate remaining dt after the collision
        local distanceTravelled = (collisionPoint - ball.position):getLength()
        dt = dt * (1 - distanceTravelled / dBallPosition:getLength())

        -- move ball to collision point and add a tiny nudge forwards to avoid repeated collisions
        ball.position = collisionPoint + newVelocity * 0.001

        if dt > 0 then
            -- call this function recursively with reduced dt
            return updateBall(dt)
        end

        return true
    end
end

function love.load()
    -- init random seed
    math.randomseed(os.time())

    -- init bigger font
    love.graphics.setFont(love.graphics.newFont(20))

    -- init used sprites
    for _, object in ipairs({ paddle, ball, brickTemplate }) do
        Sprites.init(object)
    end

    -- set window size
    love.window.setMode(window.width, window.height, {})

    -- setup game objects
    resetGame()
end

function love.keypressed(key, scancode, is_repeat)
    if is_repeat then
        -- ignore repeat presses
        return
    end

    if key == KeyEnum.ESC then
        love.event.quit()
        return
    end

    if key == KeyEnum.ENTER and gameState == GameStateEnum.MENU then
        gameState = GameStateEnum.STARTING
        resetGame()

        return
    end

    if key == KeyEnum.SPACE and gameState == GameStateEnum.STARTING then
        gameState = GameStateEnum.PLAYING
        return
    end

    if gameState == GameStateEnum.STARTING or gameState == GameStateEnum.PLAYING then
        if key == KeyEnum.LEFT then
            paddle.acceleration:transform(left)
            return
        elseif key == KeyEnum.RIGHT then
            paddle.acceleration:transform(right)
            return
        end
    end

    if key == KeyEnum.ENTER and (gameState == GameStateEnum.GAMEOVER or gameState == GameStateEnum.WINNER) then
        gameState = GameStateEnum.MENU
        return
    end
end

function love.keyreleased(key, scancode)
    if gameState == GameStateEnum.STARTING or gameState == GameStateEnum.PLAYING then
        if key == KeyEnum.LEFT then
            paddle.acceleration:transform(right)
        elseif key == KeyEnum.RIGHT then
            paddle.acceleration:transform(left)
        end
    end
end

function love.update(dt)
    if gameState == GameStateEnum.STARTING or gameState == GameStateEnum.PLAYING then
        -- calculate new paddle speed
        local paddleSpeed = paddle.velocity.x
        if paddle.acceleration.x ~= 0 then
            -- player-initiated speed change
            paddle.velocity.x = Utils.clamp(-1, paddleSpeed + paddle.acceleration.x * paddle.dAcceleration * dt, 1)
        else
            -- friction deceleration
            if paddleSpeed > 0 then
                paddle.velocity.x = (math.max(0, paddleSpeed - paddle.dFrictionDeceleration * dt))
            elseif paddleSpeed < 0 then
                paddle.velocity.x = (math.min(0, paddleSpeed + paddle.dFrictionDeceleration * dt))
            end
        end

        -- move paddle
        paddle.position:transform(paddle.velocity * paddle.dVelocity * dt)

        -- if paddle is out of bounds, perform a bounce
        if paddle.position.x <= paddle.width / 2 or paddle.position.x >= window.width - paddle.width / 2 then
            paddle.velocity = paddle.velocity * (-0.7)
        end

        -- clamp paddle position to bounds
        paddle.position.x = Utils.clamp(paddle.width / 2, paddle.position.x, window.width - paddle.width / 2)
    end

    if gameState == GameStateEnum.PLAYING then
        -- calculate new ball position and check collisions
        updateBall(dt)
    end

    if gameState == GameStateEnum.FINISHED then
        finishTimer = finishTimer + dt
        if finishTimer >= finishDelay then
            finishTimer = 0

            if level < #levels then
                level = level + 1
                gameState = GameStateEnum.STARTING
                resetGame()
            else
                gameState = GameStateEnum.WINNER
            end
        end
    end
end

function love.draw()
    if gameState == GameStateEnum.MENU then
        local y0 = window.height / 2

        love.graphics.printf({ { 1.0, 0.0, 0.0, 1.0 }, "BRICK GAME" }, 0, 16, window.width / 1.5, "center", 0, 1.5, 1.5, 0, 0, 0, 0)
        love.graphics.printf("Use arrow keys to control the paddle and destroy all bricks with the ball", 0, y0 - 16, window.width, "center", 0, 1, 1, 0, 0, 0, 0)
        love.graphics.printf("Press ENTER to start the game", 0, y0 + 16, window.width, "center", 0, 1, 1, 0, 0, 0, 0)
    elseif gameState == GameStateEnum.STARTING or gameState == GameStateEnum.PLAYING or gameState == GameStateEnum.FINISHED then
        Sprites.draw(ball)
        Sprites.draw(paddle)

        for _, brick in ipairs(bricks) do
            Sprites.draw(brick)
        end

        love.graphics.printf(string.format("Lives: %d", livesLeft), 16, 16, 128, "left", 0, 1, 1, 0, 0, 0, 0)

        if gameState == GameStateEnum.STARTING then
            love.graphics.printf("Press SPACE to launch ball", 0, window.height / 2, window.width, "center", 0, 1, 1, 0, 0, 0, 0)
        elseif gameState == GameStateEnum.FINISHED then
            love.graphics.printf(string.format("You won level %d!", level), 0, window.height / 2, window.width, "center", 0, 1, 1, 0, 0, 0, 0)
        end
    elseif gameState == GameStateEnum.WINNER then
        love.graphics.printf("YOUR WINNER!!!\nPress ENTER to go back to menu", 0, window.height / 2,
            window.width, "center", 0, 1, 1, 0, 0, 0, 0)
    elseif gameState == GameStateEnum.GAMEOVER then
        love.graphics.printf("GAME OVER\nPress ENTER to go back to menu", 0, window.height / 2,
            window.width, "center", 0, 1, 1, 0, 0, 0, 0)
    end
end
