Utils = require("utils")
Vector = require("vector")
Sprites = require("sprites")
Collisions = require("collisions")

-- screen size
Window = {
    width = false,
    height = false,
}

-- keyboard key names
KeyEnum = {
    LEFT = "left",
    RIGHT = "right",
    ESC = "escape",
    ENTER = "return",
}

-- game states
GameStateEnum = {
    MENU = 0,
    PLAYING = 1,
    WINNER = 2,
    GAMEOVER = 3,
}

-- paddle movement directions
LeftVector = Vector.new(-1, 0)
RightVector = -LeftVector

-- global state
GameState = GameStateEnum.MENU

-- images, sprites, game entities/objects
Paddle = { -- single object
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

Ball = { -- single object
    imagePath = "assets/png/ballBlue.png",
    spriteName = "ball",
    radius = 22 / 2,
    width = 22,
    height = 22,
    position = Vector.new(),
    velocity = Vector.new(),
    dVelocity = 300,
}

Brick = { -- generic sprite used by multiple brick objects
    imagePath = "assets/png/element_grey_rectangle.png",
    spriteName = "brick_grey",
    width = 64,
    height = 32,
}

Bricks = {} -- list of actual brick objects used in game

NextCollision = {
    position = false,
    object = false,
}

function CreateBrick(centerX, centerY, rotation)
    local position = Vector.new(centerX - Brick.width / 2, centerY - Brick.height / 2)

    return {
        spriteName = "brick_grey",
        width = Brick.width,
        height = Brick.height,
        position = position,
        rotation = rotation,
    }
end

function ResetGame()
    -- setup paddle
    Paddle.position = Vector.new((Window.width - Paddle.width) / 2, Window.height - 100)
    Paddle.velocity = Vector.new()
    Paddle.acceleration = Vector.new()

    -- check for keys pressed before game setup
    if love.keyboard.isDown(KeyEnum.LEFT) then
        Paddle.acceleration:transform(LeftVector)
    end
    if love.keyboard.isDown(KeyEnum.RIGHT) then
        Paddle.acceleration:transform(RightVector)
    end

    -- setup ball
    Ball.position = Vector.new((Window.width - Ball.width) / 2, (Window.height - Ball.height) / 2)
    Ball.velocity = Vector.fromAngle(math.rad(-90 + math.random(-30, 30)))

    -- setup bricks
    local centerX = Window.width / 2
    local centerY = Window.height / 2 - 100
    Bricks = {}
    for dx = -3, 4 do
        for dy = -3, 0 do
            local x = centerX + dx * Brick.width
            local y = centerY + dy * Brick.height
            local r = (dx - 0.5) / 3.5 * math.rad(22.5)

            table.insert(Bricks, CreateBrick(x, y, r))
        end
    end
end

function UpdateBall(dt)
    -- calculate ball position after this update
    local dBallPosition = Ball.velocity:copy() * Ball.dVelocity * dt
    local newBallPosition = Ball.position + dBallPosition

    -- check ball outside playing area
    if newBallPosition.y > Window.height then
        GameState = GameStateEnum.GAMEOVER
    end

    local collisionPoint, newVelocity, hitElement = Collisions.calculateNextCollision(Ball,
        newBallPosition, Bricks, Paddle, Window)

    if not collisionPoint then
        -- no collision detected, simply move ball
        Ball.position:transform(dBallPosition)
        return true
    else
        if hitElement then
            -- hit a brick, remove it from list
            for index, brick in ipairs(Bricks) do
                if brick == hitElement then
                    table.remove(Bricks, index)
                    break
                end
            end

            -- check if it was the last brick
            if not Bricks[1] then
                GameState = GameStateEnum.WINNER
                return true
            end
        end

        -- reflect ball
        Ball.velocity = newVelocity

        -- calculate remaining dt after the collision
        local distanceTravelled = (collisionPoint - Ball.position):getLength()
        dt = dt * (1 - distanceTravelled / dBallPosition:getLength())

        -- move ball to collision point and add a tiny nudge forwards to avoid repeated collisions
        Ball.position = collisionPoint + newVelocity * 0.001

        if dt > 0 then
            -- call this function recursively with reduced dt
            return UpdateBall(dt)
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
    for _, object in ipairs({ Paddle, Ball, Brick }) do
        Sprites.init(object)
    end

    -- save game window size
    Window.width, Window.height = love.window.getMode()

    -- setup game objects
    ResetGame()
end

function love.keypressed(key, scancode, is_repeat)
    if is_repeat then
        -- ignore repeat presses
        return
    end

    if key == KeyEnum.ESC then
        love.event.quit()
    end

    if GameState == GameStateEnum.MENU then
        if key == KeyEnum.ENTER then
            GameState = GameStateEnum.PLAYING
        end
    elseif GameState == GameStateEnum.PLAYING then
        if key == KeyEnum.LEFT then
            Paddle.acceleration:transform(LeftVector)
        elseif key == KeyEnum.RIGHT then
            Paddle.acceleration:transform(RightVector)
        end
    elseif GameState == GameStateEnum.GAMEOVER or GameState == GameStateEnum.WINNER then
        if key == KeyEnum.ENTER then
            GameState = GameStateEnum.MENU

            ResetGame()
        end
    end
end

function love.keyreleased(key, scancode)
    if GameState == GameStateEnum.PLAYING then
        if key == KeyEnum.LEFT then
            Paddle.acceleration:transform(RightVector)
        elseif key == KeyEnum.RIGHT then
            Paddle.acceleration:transform(LeftVector)
        end
    end
end

function love.update(dt)
    if GameState == GameStateEnum.PLAYING then
        -- move paddle
        local paddleSpeed = Paddle.velocity.x
        if Paddle.acceleration.x == 0 then
            -- friction deceleration
            if paddleSpeed > 0 then
                Paddle.velocity.x = (math.max(0, paddleSpeed - Paddle.dFrictionDeceleration * dt))
            else
                Paddle.velocity.x = (math.min(0, paddleSpeed + Paddle.dFrictionDeceleration * dt))
            end
        else
            -- player-initiated speed change
            Paddle.velocity.x = Utils.clamp(-1, paddleSpeed + Paddle.acceleration.x * Paddle.dAcceleration * dt, 1)
        end

        Paddle.position:transform(Paddle.velocity * Paddle.dVelocity * dt)
        Paddle.position.x = Utils.clamp(Paddle.width / 2, Paddle.position.x, Window.width - Paddle.width / 2)

        if Paddle.position.x <= Paddle.width / 2 or Paddle.position.x >= Window.width - Paddle.width / 2 then
            -- paddle outside window, perform a bounce
            Paddle.velocity = Paddle.velocity * (-0.7)
        end

        -- calculate new ball position and check collisions
        UpdateBall(dt)

        -- simulate next collision
        -- local extrapolatedPosition = Ball.position + Ball.velocity * 1000

        -- NextCollision.position = false
        -- NextCollision.object = false

        -- NextCollision.position = Collisions.calculateBallPaddleCollision(Ball, extrapolatedPosition, Paddle)

        -- if NextCollision.position then
        --     NextCollision.object = Paddle
        -- else
        --     if Bricks[1] then
        --         NextCollision.object, NextCollision.position, _ = Collisions.calculateBallBricksCollision(Ball, extrapolatedPosition, Bricks)
        --     end

        --     if not NextCollision.position then
        --         NextCollision.position = Collisions.calculateBallWallsCollision(Ball, extrapolatedPosition, Window)
        --     end
        -- end
    end
end

function love.draw()
    if GameState == GameStateEnum.MENU then
        local y0 = Window.height / 2

        love.graphics.printf({ { 1.0, 0.0, 0.0, 1.0 }, "BRICK GAME" }, 0, 16, Window.width / 1.5, "center", 0, 1.5, 1.5, 0, 0, 0, 0)
        love.graphics.printf("Use arrow keys to control the paddle and destroy all bricks with the ball", 0, y0 - 16, Window.width, "center", 0, 1, 1, 0, 0, 0, 0)
        love.graphics.printf("Press ENTER to start the game", 0, y0 + 16, Window.width, "center", 0, 1, 1, 0, 0, 0, 0)
    elseif GameState == GameStateEnum.PLAYING then
        Sprites.draw(Ball)
        Sprites.draw(Paddle)

        for _, brick in ipairs(Bricks) do
            Sprites.draw(brick)
        end
    elseif GameState == GameStateEnum.WINNER then
        love.graphics.printf("YOUR WINNER!!!\nPress ENTER to go back to menu", 0, Window.height / 2,
            Window.width, "center", 0, 1, 1, 0, 0, 0, 0)
    elseif GameState == GameStateEnum.GAMEOVER then
        love.graphics.printf("GAME OVER\nPress ENTER to go back to menu", 0, Window.height / 2,
            Window.width, "center", 0, 1, 1, 0, 0, 0, 0)
    end

    if false and NextCollision.position then
        love.graphics.setColor(1.0, 0.0, 0.0)

        love.graphics.line(Ball.position.x, Ball.position.y, NextCollision.position.x, NextCollision.position.y)

        if NextCollision.object then
            love.graphics.rectangle("line", NextCollision.object.position.x - NextCollision.object.width / 2, NextCollision.object.position.y - NextCollision.object.height / 2, NextCollision.object.width, NextCollision.object.height)
        end

        love.graphics.setColor(1.0, 1.0, 1.0)
    end
end
