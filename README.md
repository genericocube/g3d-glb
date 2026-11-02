# g3d-glb

Carregador de arquivos **.glb** (modelo 3D + textura embutida) para o [g3d](https://github.com/groverburger/g3d), feito em Lua para o [LÖVE](https://love2d.org).

A loader for **.glb** files (mesh + embedded texture) for [g3d](https://github.com/groverburger/g3d).

## Como usar / Usage

1. Copie [`example/g3d/glb.lua`](example/g3d/glb.lua) para dentro da pasta `g3d/` do seu projeto.
2. Carregue o modelo:

```lua
local g3d = require "g3d"
local glb = require "g3d.glb"

local verts, tex = glb.load("modelos/meu_modelo.glb")
local model = g3d.newModel(verts, tex, {0, 0, 0}, nil, 1)

function love.draw()
    model:draw()
end
```

`glb.load(path, yUp)` retorna `verts, texture`. Por padrão converte do eixo Y-up do glTF para o Z-up do g3d; se o modelo ficar deitado, use `glb.load(path, false)`.

## Exemplo / Example

```
love example
```

(precisa do LÖVE 11.x instalado)

## O que suporta / Supported

- Posição, UV, normais e cor de vértice (`COLOR_0`)
- Textura `baseColor` embutida no .glb (PNG/JPG)
- Índices (uint8/16/32) e malhas só de triângulos
- Várias malhas são juntadas em um único modelo
- Malhas sem UV continuam com a cor de vértice correta

## Limitações / Limitations

- Sem animações, esqueletos, nem transformações de nós (posição/rotação/escala dos nós são ignoradas)
- Só a textura de cor base; sem materiais PBR, normal map etc.
- Só `.glb` (binário) com imagem embutida; `.gltf` e texturas externas não funcionam
- Uma textura por modelo

## Licença

MIT, feito por **generico_cube**. O g3d (em `example/g3d/`) é de [groverburger](https://github.com/groverburger/g3d), também MIT (veja `example/g3d/LICENSE-g3d`).
