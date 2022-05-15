inspect = require("libraries.inspect")
iffy = require("libraries.iffy")
utils = require("utils")

-- screen size
MAX_WIDTH = false
MAX_HEIGHT = false

-- keyboard key names
KEY_LEFT = "left"
KEY_RIGHT = "right"
KEY_ESC = "escape"
KEY_ENTER = "return"
KEY_R = "r"
-- fonts
FONT = false

PADDLE_Y_OFFSET = 100
COLLISION_CHECK_INTERVAL = 10

-- game states
GameStateEnum = {
    MENU = 0,
    PLAYING = 1,
    WINNER = 2,
    GAMEOVER = 3,
}

GameState = GameStateEnum.PLAYING

-- paddle movement directions
HorizontalDirectionEnum = {
    STILL = 0,
    LEFT = -1,
    RIGHT = 1
}

-- images, sprites
Paddle = {
    path = "assets/png/paddleRed.png",
    name = "paddle",
    width = 104,
    height = 24,
    x = false,
    y = false,
    acceleration = HorizontalDirectionEnum.STILL,
    speed = 0,
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

function resetGame()
    Paddle.x = (MAX_WIDTH - Paddle.width) / 2
    Paddle.y = MAX_HEIGHT - PADDLE_Y_OFFSET
    Paddle.speed = 0

    Ball.x = Paddle.x
    Ball.y = (MAX_HEIGHT - Ball.height) / 2
    Ball.angle = math.rad(math.random(-60, 60))
end

function getCollisionCheckpoints(x1, y1, x2, y2)
    local result = {}
    local a = y1 - y2
    local b = x2 - x1
    local c = x1 * (y2 - y1) - y1 * (x2 - x1)

    local xs = math.min(x1, x2)
    local xe = math.max(x1, x2)

    for x = xe, xs, -COLLISION_CHECK_INTERVAL do
        local y = -(x * a + c) / b
        table.insert(result, { x, y })
    end

    return result

end

function checkPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

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
    resetGame()
end

function love.keypressed(key, scancode, is_repeat)
    if key == KEY_ESC then
        love.event.quit()
    elseif key == KEY_R then
        resetGame()
    elseif key == KEY_LEFT then
        Paddle.acceleration = Paddle.acceleration + HorizontalDirectionEnum.LEFT
    elseif key == KEY_RIGHT then
        Paddle.acceleration = Paddle.acceleration + HorizontalDirectionEnum.RIGHT
    end

    if GameState == GameStateEnum.MENU then
        if key == KEY_ENTER then
            GameState = GameStateEnum.PLAYING
        end
    elseif GameState == GameStateEnum.PLAYING then
        if is_repeat then
            return
        end
    elseif GameState == GameStateEnum.GAMEOVER or GameState == GameStateEnum.WINNER then
        if key == KEY_ENTER then
            GameState = GameStateEnum.MENU

            resetGame()
        end
    end
end

function love.keyreleased(key, scancode)
    if key == KEY_LEFT then
        Paddle.acceleration = Paddle.acceleration - HorizontalDirectionEnum.LEFT
    elseif key == KEY_RIGHT then
        Paddle.acceleration = Paddle.acceleration - HorizontalDirectionEnum.RIGHT
    end

    if GameState == GameStateEnum.PLAYING then

    end
end

function love.update(dt)
    if GameState == GameStateEnum.PLAYING then
        local dx = math.sin(Ball.angle)
        local dy = math.cos(Ball.angle)

        local oldx = Ball.x
        local oldy = Ball.y

        Ball.x = Ball.x + dt * dx * 500
        Ball.y = Ball.y + dt * dy * 500

        local collisionCheckpoints = getCollisionCheckpoints(oldx, oldy, Ball.x, Ball.y)

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

        -- local offsetFromCenter = ((Ball.x + Ball.width / 2) - (Paddle.x + Paddle.width / 2)) / (Paddle.width / 2)
        -- if offsetFromCenter >= -1 and offsetFromCenter <= 1 then
        --     if Ball.y + Ball.height >= Paddle.y and Ball.y + Ball.height < Paddle.y + Paddle.height then
        --         Ball.y = Paddle.y - Ball.height
        --
        --         Ball.angle = math.rad(180) - Ball.angle - math.rad(70) *
        --             offsetFromCenter * math.abs(offsetFromCenter)
        --     end
        -- end




        Ball.x = math.min(MAX_WIDTH - Ball.width, math.max(0, Ball.x))
        Ball.y = math.min(MAX_HEIGHT - Ball.height, math.max(0, Ball.y))

        if Paddle.acceleration == HorizontalDirectionEnum.STILL then
            if Paddle.speed > 0 then
                Paddle.speed = math.max(0, Paddle.speed - dt * 2)
            else
                Paddle.speed = math.min(0, Paddle.speed + dt * 2)
            end
        else
            Paddle.speed = utils.clamp(-1, Paddle.speed + dt * 3 * Paddle.acceleration, 1)
        end

        Paddle.x = Paddle.x + dt * Paddle.speed * 500

        Paddle.x = utils.clamp(0, Paddle.x, MAX_WIDTH - Paddle.width)
        if Paddle.x + Paddle.width == MAX_WIDTH or Paddle.x == 0 then
            Paddle.speed = -Paddle.speed * 0.7
        end

        local collision = false
        local cx
        local cy
        for _, checkpoint in ipairs(collisionCheckpoints) do
            cx, cy = unpack(checkpoint)
            cx = cx + Ball.width / 2
            cy = cy + Ball.height
            if checkPointInRect(cx, cy, Paddle.x, Paddle.y, Paddle.width, Paddle.height) then
                collision = true
            end
        end

        if collision then
            local offsetFromCenter = ((Ball.x + Ball.width / 2) - (Paddle.x + Paddle.width / 2)) / (Paddle.width / 2)

            local overshootY = (Ball.y - Paddle.y)
            if offsetFromCenter > -1 and offsetFromCenter < 1 then
                Ball.y = Paddle.y - (Paddle.y - oldy) - Ball.height - overshootY
            end
            Ball.angle = math.rad(180) - Ball.angle - math.rad(70) * offsetFromCenter * math.abs(offsetFromCenter)
        end


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
