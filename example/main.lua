local g3d = require "g3d"
local glb = require "g3d.glb"

local verts, tex = glb.load("modelos/cubo_magico.glb")
local model = g3d.newModel(verts, tex, {0, 0, 0}, nil, 1)

love.graphics.setBackgroundColor(0.5, 0.7, 1)
-- câmera afastada olhando pro centro (padrão é dentro do cubo)
g3d.camera.lookAt(6, 6, 4, 0, 0, 0)

function love.update(dt)
    model:setRotation(0, 0, love.timer.getTime() * 0.5) -- gira devagar
end

function love.draw()
    model:draw()
end
