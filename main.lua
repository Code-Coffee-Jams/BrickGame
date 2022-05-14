iffy = require("libraries.iffy")

PADDLE_IMAGE = "assets/png/paddleRed.png"
PADDLE_SPRITE = "paddle"

BALL_IMAGE = "assets/png/ballBlue.png"
BALL_SPRITE = "ball"

function love.load()
    iffy.newImage(PADDLE_SPRITE, PADDLE_IMAGE)
    iffy.newImage(BALL_SPRITE, BALL_IMAGE)

    iffy.newSprite(PADDLE_SPRITE, PADDLE_SPRITE, 0, 0, 104, 24)
    iffy.newSprite(BALL_SPRITE, BALL_SPRITE, 0, 0, 22, 22)
end

function love.update(dt)

end

function love.draw()
    iffy.drawSprite(BALL_SPRITE, 0, 0, 0, 1, 1)
    iffy.drawSprite(PADDLE_SPRITE, 100, 100, 0, 1, 1)
end