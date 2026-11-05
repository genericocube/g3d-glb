local g3d = require "g3d"
local glb = require "g3d-cube-tools.g3d-glb"

-- modelo ANIMADO (as funções em português também funcionam: tocar, pausar, continuar, parar...)
local cubo = glb.newModel("modelos/cubo_magico.glb", {0, 0, 0})
cubo:play("Rotacao")       -- tocar("Rotacao")

-- o mesmo arquivo como modelo ESTÁTICO (parado, sem animação)
local verts, tex = glb.load("modelos/cubo_magico.glb")
local parado = g3d.newModel(verts, tex, {-4.5, 0, 0}, nil, 1)

local speed = 1
local msg = ""
cubo:onFinish(function(self, name) msg = name .. " terminou / finished" end) -- aoTerminar

love.graphics.setBackgroundColor(0.5, 0.7, 1)
g3d.camera.lookAt(-2.25, -11, 3, -2.25, 0, 0.3)

function love.update(dt)
    cubo:update(dt)        -- atualizar(dt)
    parado:setRotation(0, 0, love.timer.getTime() * 0.5)
end

function love.draw()
    cubo:draw()            -- desenhar()
    parado:draw()

    love.graphics.setColor(0, 0, 0)
    love.graphics.print(string.format("animacao: %s   tempo: %.2f / %.2f   velocidade: %.2f   %s",
        tostring(cubo:getCurrent()), cubo:getTime(), cubo:getDuration(), speed,
        cubo:isPlaying() and "" or "(parado)"), 10, 10)
    love.graphics.print("1 Rotacao (loop)   2 Balanco (loop)   3 Pulo (sem loop)   espaco pausa/continua", 10, 30)
    love.graphics.print("cima/baixo velocidade   S para (stop)   esc sai   " .. msg, 10, 50)
    love.graphics.setColor(1, 1, 1)
end

function love.keypressed(key)
    if key == "1" then msg = ""; cubo:play("Rotacao")
    elseif key == "2" then msg = ""; cubo:play("Balanco")
    elseif key == "3" then msg = ""; cubo:play("Pulo", false, true) -- false = sem loop, true = reinicia
    elseif key == "space" then
        if cubo:isPlaying() then cubo:pause() else cubo:resume() end
    elseif key == "up" then speed = speed + 0.25; cubo:setSpeed(speed)
    elseif key == "down" then speed = speed - 0.25; cubo:setSpeed(speed)
    elseif key == "s" then cubo:stop()
    elseif key == "escape" then love.event.quit()
    end
end
