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
GameState = GameStateEnum.PLAYING

-- images, sprites, game entities/objects
Paddle = { -- single object
    imagePath = "assets/png/paddleRed.png",
    spriteName = "paddle",
    width = 104,
    height = 24,
    position = false, -- vector
    velocity = false, -- vector
    acceleration = false, -- vector
    dVelocity = 500,
    dAcceleration = 3,
    dFrictionDeceleration = 2,
}

Ball = { -- single object
    imagePath = "assets/png/ballBlue.png",
    spriteName = "ball",
    radius = 22 / 2,
    width = 22,
    height = 22,
    position = false, -- vector
    velocity = false, -- vector
    dVelocity = 300,
}

Brick = { -- generic sprite used by multiple brick objects
    imagePath = "assets/png/element_grey_rectangle.png",
    spriteName = "brick_grey",
    width = 64,
    height = 32,
}

Bricks = {} -- list of actual brick objects used in game

function CreateBrick(centerX, centerY)
    local position = Vector.new(centerX - Brick.width / 2, centerY - Brick.height / 2)

    return {
        spriteName = "brick_grey",
        width = Brick.width,
        height = Brick.height,
        position = position,
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
            table.insert(Bricks, CreateBrick(centerX + dx * Brick.width, centerY + dy * Brick.height))
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

    local collisionPoint, normalVector

    -- check paddle collision
    collisionPoint, normalVector = Collisions.calculateBallPaddleCollision(Ball, newBallPosition, Paddle)

    if not collisionPoint then
        -- check wall collision
        collisionPoint, normalVector = Collisions.calculateBallWallsCollision(Ball, newBallPosition, Window)
    end

    if not collisionPoint and Bricks[1] then
        -- check brick collision
        for index, brick in ipairs(Bricks) do
            collisionPoint, normalVector = Collisions.calculateBallBrickCollision(Ball, newBallPosition, brick)
            if collisionPoint then
                table.remove(Bricks, index)
                break
            end
        end

        if not Bricks[1] then
            GameState = GameStateEnum.WINNER
            return
        end
    end

    if not collisionPoint then
        Ball.position:transform(dBallPosition)
        return true
    else
        -- call this function recursively, reducing dt
        dt = dt * (1 - (collisionPoint - Ball.position):getLength() / dBallPosition:getLength())
        Ball.position = collisionPoint + normalVector * 0.01

        -- equation taken from:
        -- https://math.stackexchange.com/questions/13261/how-to-get-a-reflection-vector
        Ball.velocity:transform(normalVector * (-2) * Ball.velocity:dotProduct(normalVector))
        -- GameState = GameStateEnum.MENU

        if dt > 0 then
            UpdateBall(dt)
        end
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
    end
end

function love.draw()
    if GameState == GameStateEnum.MENU then
        love.graphics.printf("Press ENTER to start game", 0, Window.height / 2, Window.width,
            "center", 0, 1, 1, 0, 0, 0, 0)
    elseif GameState == GameStateEnum.PLAYING then
        Sprites.draw(Ball)
        Sprites.draw(Paddle)
        -- Iffy.drawSprite(Ball.name, Ball.position.x, Ball.position.y, 0, 1, 1)
        -- Iffy.drawSprite(Paddle.name, Paddle.position.x, Paddle.position.y, 0, 1, 1)

        for _, brick in ipairs(Bricks) do
            Sprites.draw(brick)
            -- Iffy.drawSprite(brick.name, brick.position.x, brick.position.y, 0, 1, 1)
        end
    elseif GameState == GameStateEnum.WINNER then
        love.graphics.printf("YOUR WINNER!!!\nPress ENTER to go back to menu", 0, Window.height / 2,
            Window.width, "center", 0, 1, 1, 0, 0, 0, 0)
    elseif GameState == GameStateEnum.GAMEOVER then
        love.graphics.printf("GAME OVER\nPress ENTER to go back to menu", 0, Window.height / 2,
            Window.width, "center", 0, 1, 1, 0, 0, 0, 0)
    end
end
