# g3d-glb

Carregador de arquivos **.glb** (malha, cores, textura e **animações de esqueleto**) para o [g3d](https://github.com/groverburger/g3d), feito em Lua para o [LÖVE](https://love2d.org).

A **.glb** loader (mesh, colors, texture and **skeletal animations**) for [g3d](https://github.com/groverburger/g3d), written in Lua for [LÖVE](https://love2d.org).

Feito por / Made by **generico_cube**.

## Instalação / Install

Copie [`example/g3d/glb.lua`](example/g3d/glb.lua) para dentro da pasta `g3d/` do seu projeto.
Copy `glb.lua` into the `g3d/` folder of your project.

## Modelo animado / Animated model

```lua
local glb = require "g3d.glb"

local personagem = glb.newModel("modelos/personagem.glb", {0, 0, 0})
personagem:play("Walk")

function love.update(dt)
    personagem:update(dt)
end

function love.draw()
    personagem:draw()
end
```

Todos os comandos têm nome em inglês e em português (use o que preferir):

| English | Português | O que faz / What it does |
|---|---|---|
| `glb.newModel(path, pos, rot, scale)` | `glb.novoModelo(...)` | carrega o .glb / loads the .glb |
| `m:play(name, loop)` | `m:tocar(nome, repetir)` | toca uma animação (nome ou número). `loop` é `true` por padrão |
| `m:pause()` | `m:pausar()` | pausa |
| `m:resume()` | `m:continuar()` | continua de onde parou |
| `m:stop()` | `m:parar()` | para e volta à pose parada |
| `m:setSpeed(v)` | `m:velocidade(v)` | `1` normal, `2` dobro, `-1` ao contrário |
| `m:setTime(t)` | `m:tempo(t)` | pula para `t` segundos |
| `m:getTime()` | `m:tempo()` | tempo atual |
| `m:getDuration()` | `m:duracao()` | duração da animação atual |
| `m:getAnimations()` | `m:animacoes()` | lista com os nomes das animações |
| `m:getCurrent()` | `m:atual()` | nome da animação atual |
| `m:isPlaying()` | `m:tocando()` | está tocando? |
| `m:onFinish(fn)` | `m:aoTerminar(fn)` | chama `fn(m, nome)` quando uma animação **sem loop** termina |
| `m:update(dt)` | `m:atualizar(dt)` | chame em `love.update` |
| `m:draw()` | `m:desenhar()` | chame em `love.draw` |

Dicas / Tips:

- O nome da animação não precisa ser exato: `play("walk")` acha `"Walk"` (ou `"Armature|Walk"`). Se não achar, o erro lista os nomes disponíveis.
- `play()` com a animação que **já está tocando** não reinicia, então dá pra chamar todo frame:
  ```lua
  if andando then personagem:play("Walk") else personagem:play("Idle") end
  ```
- Animação que toca uma vez só: `personagem:play("Attack", false)`; use `onFinish` pra voltar pro `Idle`.
- As funções do model do g3d funcionam direto: `personagem:setTranslation(x, y, z)`, `personagem:setRotation(...)`, `personagem:setScale(...)`. O model em si está em `personagem.model`.

## Modelo parado / Static model

```lua
local g3d = require "g3d"
local glb = require "g3d.glb"

local verts, tex = glb.load("modelos/cubo_magico.glb")
local model = g3d.newModel(verts, tex, {0, 0, 0}, nil, 1)
```

`glb.load(path, yUp)` converte do eixo Y-up do glTF para o Z-up do g3d. Se o modelo ficar deitado, use `glb.load(path, false)` (ou o 5º argumento de `glb.newModel`).

## Exemplo / Example

```
love example
```

Um cubo mágico com 3 animações (`Rotacao 360`, `Balanco`, `Pulo`) ao lado do mesmo arquivo carregado como modelo parado. Teclas: `1` `2` `3` trocam de animação, `espaço` pausa, `↑` `↓` velocidade, `S` para. Precisa do LÖVE 11.x.

O modelo `cubo_magico.glb` é de **generico_cube**.

## Como fazer o .glb animado / Making the .glb

No Blender: crie o esqueleto (Armature), anime e exporte em **glTF Binary (.glb)** com a opção de animação ligada. Para ter várias animações no mesmo arquivo, exporte as *Actions* (ou *NLA Tracks*); cada uma vira uma animação com o nome dela.

## O que suporta / Supported

- Posição, UV, normais e cor de vértice (`COLOR_0`)
- Textura `baseColor` embutida no .glb (PNG/JPG)
- Esqueleto com até 4 ossos por vértice (skinning), hierarquia de nós e transformações dos nós
- Animações de translação, rotação e escala (`LINEAR`, `STEP`, `CUBICSPLINE`)
- Várias animações no mesmo .glb
- Várias malhas são juntadas em um único modelo

## Limitações / Limitations

- Uma textura por modelo; só a cor base (sem PBR, normal map etc.)
- Sem morph targets (shape keys) e sem mistura (blend) entre animações
- Só `.glb` com imagem embutida; `.gltf` e texturas externas não funcionam
- A animação é calculada na CPU a cada frame: ótimo para low-poly e poucos personagens, pesado para modelos com muitos milhares de vértices

## Licença

MIT, feito por **generico_cube**. O g3d (em `example/g3d/`) é de [groverburger](https://github.com/groverburger/g3d), também MIT (veja `example/g3d/LICENSE-g3d`).
