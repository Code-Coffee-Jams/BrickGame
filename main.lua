iffy = require("libraries.iffy")

-- screen size
MAX_WIDTH = false
MAX_HEIGHT = false

-- keyboard key names
KEY_LEFT = "left"
KEY_RIGHT = "right"
KEY_ESC = "escape"
KEY_ENTER = "return"
-- fonts
FONT = false

PADDLE_Y_OFFSET = 100

-- game states
GameStateEnum = {
    MENU = 0,
    PLAYING = 1,
    WINNER = 2,
    GAMEOVER = 3,
}

GameState = GameStateEnum.PLAYING

-- paddle movement directions
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

    FONT = love.graphics.newFont(20)
    love.graphics.setFont(FONT)

    prepareSprite(Paddle)
    prepareSprite(Ball)

    MAX_WIDTH, MAX_HEIGHT = love.window.getMode()
    Paddle.x = (MAX_WIDTH - Paddle.width) / 2
    Paddle.y = MAX_HEIGHT - PADDLE_Y_OFFSET
    PaddleDirection = PaddleDirectionEnum.STILL

    Ball.x = Paddle.x
    Ball.y = (MAX_HEIGHT - Ball.height) / 2
    Ball.angle = math.rad(math.random(-60, 60))
end

function love.keypressed(key, scancode, is_repeat)
    if key == KEY_ESC then
        love.event.quit()
    end

    if GameState == GameStateEnum.MENU then
        if key == KEY_ENTER then
            GameState = GameStateEnum.PLAYING
        end
    elseif GameState == GameStateEnum.PLAYING then
        if is_repeat then
            return
        end

        if key == KEY_LEFT then
            PaddleDirection = PaddleDirection + PaddleDirectionEnum.LEFT
        elseif key == KEY_RIGHT then
            PaddleDirection = PaddleDirection + PaddleDirectionEnum.RIGHT
        end
    elseif GameState == GameStateEnum.GAMEOVER or GameState == GameStateEnum.WINNER then
        if key == KEY_ENTER then
            GameState = GameStateEnum.MENU

            Paddle.x = (MAX_WIDTH - Paddle.width) / 2
            Paddle.y = MAX_HEIGHT - PADDLE_Y_OFFSET

            Ball.x = Paddle.x
            Ball.y = (MAX_HEIGHT - Ball.height) / 2
            Ball.angle = math.rad(math.random(0, 359))
        end
    end
end

function love.keyreleased(key, scancode)
    if GameState == GameStateEnum.PLAYING then
        if key == KEY_LEFT then
            PaddleDirection = PaddleDirection - PaddleDirectionEnum.LEFT
        elseif key == KEY_RIGHT then
            PaddleDirection = PaddleDirection - PaddleDirectionEnum.RIGHT
        end
    end
end

function love.update(dt)
    if GameState == GameStateEnum.PLAYING then
        local dx = math.sin(Ball.angle)
        local dy = math.cos(Ball.angle)

        Ball.x = Ball.x + dt * dx * 250
        Ball.y = Ball.y + dt * dy * 250

        if Ball.y + Ball.height >= MAX_HEIGHT then
            GameState = GameStateEnum.GAMEOVER
            return
        end

        if Ball.x < 0 or Ball.x + Ball.width > MAX_WIDTH then
            Ball.angle = math.rad(360) - Ball.angle
        end

        if Ball.y < 0 then
            Ball.angle = math.rad(180) - Ball.angle
        end

        local offsetFromCenter = ((Ball.x + Ball.width / 2) - (Paddle.x + Paddle.width / 2)) / (Paddle.width / 2)
        if offsetFromCenter >= -1 and offsetFromCenter <= 1 then
            -- if Ball.x >= Paddle.x and Ball.x + Ball.width <= Paddle.x + Paddle.width then

            if Ball.y + Ball.height >= Paddle.y and Ball.y + Ball.height < Paddle.y + Paddle.height then
                Ball.y = Paddle.y - Ball.height
                -- Ball.angle = math.rad(180) - Ball.angle - math.rad(45) * offsetFromCenter
                Ball.angle = math.rad(180) - math.rad(60) * offsetFromCenter
            end
        end

        Ball.x = math.min(MAX_WIDTH - Ball.width, math.max(0, Ball.x))
        Ball.y = math.min(MAX_HEIGHT - Ball.height, math.max(0, Ball.y))

        Paddle.x = Paddle.x + dt * PaddleDirection * 500
        Paddle.x = math.min(MAX_WIDTH - Paddle.width, math.max(0, Paddle.x))
    end
end

function love.draw()
    if GameState == GameStateEnum.MENU then
        love.graphics.printf("Press ENTER to start game", 0, MAX_HEIGHT / 2, MAX_WIDTH, "center", 0, 1, 1, 0, 0, 0, 0)
    elseif GameState == GameStateEnum.PLAYING then
        iffy.drawSprite(Ball.name, Ball.x, Ball.y, 0, 1, 1)
        iffy.drawSprite(Paddle.name, Paddle.x, Paddle.y, 0, 1, 1)
    elseif GameState == GameStateEnum.GAMEOVER then
        love.graphics.printf("GAME OVER\nPress ENTER to go back to menu", 0, MAX_HEIGHT / 2, MAX_WIDTH, "center", 0, 1, 1, 0, 0, 0, 0)
    end
end
