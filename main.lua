iffy = require("libraries.iffy")

-- screen size
MAX_WIDTH = false
MAX_HEIGHT = false

-- paddle movement directions
KEY_LEFT = "left"
KEY_RIGHT = "right"
PaddleDirectionEnum = {
    STILL = 0,
    LEFT = -1,
    RIGHT = 1
}

PaddleDirection = PaddleDirectionEnum.STILL

-- images, sprites
Paddle = {
    path = "assets/png/paddleRed.png",
    name = "paddle",
    width = 104,
    height = 24,
    x = false,
    y = false,
}

Ball = {
    path = "assets/png/ballBlue.png",
    name = "ball",
    width = 22,
    height = 22,
    x = false,
    y = false,
    angle = false, -- counter clockwise, beginning at straight down
}


function prepareSprite(sprite)
    iffy.newImage(sprite.name, sprite.path)

    iffy.newSprite(sprite.name, sprite.name, 0, 0, sprite.width, sprite.height)
end

function love.load()
    math.randomseed(os.time())
    Ball.angle = math.rad(math.random(0, 359))

    prepareSprite(Paddle)
    prepareSprite(Ball)

    MAX_WIDTH, MAX_HEIGHT = love.window.getMode()
    Paddle.x = (MAX_WIDTH - Paddle.width) / 2
    Paddle.y = MAX_HEIGHT - 50

    Ball.x = Paddle.x
    Ball.y = (MAX_HEIGHT - Ball.height) / 2
end

function love.keypressed(key, scancode, is_repeat)
    if is_repeat then
        return
    end

    if key == KEY_LEFT then
        PaddleDirection = PaddleDirection + PaddleDirectionEnum.LEFT
    elseif key == KEY_RIGHT then
        PaddleDirection = PaddleDirection + PaddleDirectionEnum.RIGHT
    end
end

function love.keyreleased(key, scancode)
    if key == KEY_LEFT then
        PaddleDirection = PaddleDirection - PaddleDirectionEnum.LEFT
    elseif key == KEY_RIGHT then
        PaddleDirection = PaddleDirection - PaddleDirectionEnum.RIGHT
    end
end

function love.update(dt)
    local dx = math.sin(Ball.angle)
    local dy = math.cos(Ball.angle)

    Ball.x = Ball.x + dt * dx * 250
    Ball.y = Ball.y + dt * dy * 250

    if Ball.x < 0 or Ball.x + Ball.width > MAX_WIDTH then
        Ball.angle = math.rad(360) - Ball.angle
    end

    if Ball.y < 0 or Ball.y + Ball.height > MAX_HEIGHT then
        Ball.angle = math.rad(180) - Ball.angle
    end

    Ball.x = math.min(MAX_WIDTH - Ball.width, math.max(0, Ball.x))
    Ball.y = math.min(MAX_HEIGHT - Ball.height, math.max(0, Ball.y))

    Paddle.x = Paddle.x + dt * PaddleDirection * 1000
    Paddle.x = math.min(MAX_WIDTH - Paddle.width, math.max(0, Paddle.x))
end

function love.draw()
    iffy.drawSprite(Ball.name, Ball.x, Ball.y, 0, 1, 1)
    iffy.drawSprite(Paddle.name, Paddle.x, Paddle.y, 0, 1, 1)
end
