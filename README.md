# g3d-glb

**Selecione seu idioma / Select your language**

🇧🇷 [Português](#portugues) | 🇺🇸 [English](#english)

---

# Português

Carregador de arquivos **.glb** (malhas, cores, texturas e **animações de esqueleto**) para o [g3d](https://github.com/groverburger/g3d), feito em Lua para o [LÖVE](https://love2d.org).

Feito por **generico_cube**.

## Instalação

Copie [`example/g3d/glb.lua`](example/g3d/glb.lua) para dentro da pasta `g3d/` do seu projeto.

## Modelo animado

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

## Comandos disponíveis

Todos os comandos possuem nomes em inglês e português. Você pode utilizar o idioma que preferir.

| English | Português | Descrição |
|---|---|---|
| `glb.newModel(path, pos, rot, scale)` | `glb.novoModelo(...)` | Carrega o arquivo .glb |
| `m:play(name, loop)` | `m:tocar(nome, repetir)` | Reproduz uma animação. Loop ativado por padrão |
| `m:pause()` | `m:pausar()` | Pausa a animação |
| `m:resume()` | `m:continuar()` | Continua a animação |
| `m:stop()` | `m:parar()` | Para e volta à pose inicial |
| `m:setSpeed(v)` | `m:velocidade(v)` | Define a velocidade da animação |
| `m:setTime(t)` | `m:tempo(t)` | Define o tempo da animação |
| `m:getTime()` | `m:tempo()` | Retorna o tempo atual |
| `m:getDuration()` | `m:duracao()` | Retorna a duração |
| `m:getAnimations()` | `m:animacoes()` | Lista as animações disponíveis |
| `m:getCurrent()` | `m:atual()` | Retorna a animação atual |
| `m:isPlaying()` | `m:tocando()` | Verifica se está tocando |
| `m:onFinish(fn)` | `m:aoTerminar(fn)` | Executa uma função quando uma animação sem loop termina |
| `m:update(dt)` | `m:atualizar(dt)` | Atualiza a animação |
| `m:draw()` | `m:desenhar()` | Desenha o modelo |

## Dicas

- O nome da animação não precisa ser exato: `play("walk")` também encontra `"Walk"` ou `"Armature|Walk"`.
- Chamar `play()` com uma animação que já está tocando não reinicia a animação.
- Para reproduzir uma animação apenas uma vez, use `personagem:play("Attack", false)`.
- Utilize `onFinish` para executar algo quando a animação terminar.
- As funções originais do g3d continuam disponíveis, como `setTranslation`, `setRotation` e `setScale`.
- O modelo original do g3d fica disponível em `personagem.model`.

## Modelo parado

```lua
local g3d = require "g3d"
local glb = require "g3d.glb"

local verts, tex = glb.load("modelos/cubo_magico.glb")
local model = g3d.newModel(verts, tex, {0, 0, 0}, nil, 1)
```

`glb.load(path, yUp)` converte o eixo Y-up do glTF para o Z-up do g3d. Se o modelo ficar deitado, use `glb.load(path, false)`.

## Exemplo

```bash
love example
```

O exemplo inclui um cubo mágico com três animações (`Rotacao 360`, `Balanco` e `Pulo`), além do mesmo arquivo carregado como modelo estático.

**Controles:**
- `1`, `2` e `3`: Trocam de animação.
- `Espaço`: Pausa.
- `↑` e `↓`: Alteram a velocidade.
- `S`: Para a animação.

Requer LÖVE 11.x.

O modelo `cubo_magico.glb` foi criado por **generico_cube**.

## Como criar um .glb animado

No Blender, crie um esqueleto (Armature), adicione as animações e exporte como **glTF Binary (.glb)** com a opção de animações ativada.

Para exportar várias animações no mesmo arquivo, utilize Actions ou NLA Tracks.

## Recursos suportados

- Posição, UV, normais e cores de vértice (`COLOR_0`).
- Texturas `baseColor` embutidas no .glb (PNG/JPG).
- Esqueletos com até 4 ossos por vértice (skinning).
- Hierarquia de nós e transformações.
- Animações de translação, rotação e escala (`LINEAR`, `STEP`, `CUBICSPLINE`).
- Várias animações no mesmo arquivo.
- Várias malhas combinadas em um único modelo.

## Limitações

- Uma textura por modelo.
- Apenas cor base, sem PBR ou normal maps.
- Sem morph targets (shape keys).
- Sem mistura (blend) entre animações.
- Apenas arquivos `.glb` com imagens embutidas. `.gltf` e texturas externas não são suportados.
- A animação é calculada na CPU a cada frame, podendo pesar em modelos com muitos milhares de vértices.

## Licença

MIT. Feito por **generico_cube**.

O g3d, incluído em `example/g3d/`, pertence a [groverburger](https://github.com/groverburger/g3d) e também utiliza a licença MIT. Consulte `example/g3d/LICENSE-g3d`.

---

# English

A **.glb** file loader (meshes, colors, textures and **skeletal animations**) for [g3d](https://github.com/groverburger/g3d), written in Lua for [LÖVE](https://love2d.org).

Made by **generico_cube**.

## Installation

Copy [`example/g3d/glb.lua`](example/g3d/glb.lua) into the `g3d/` folder of your project.

## Animated model

```lua
local glb = require "g3d.glb"

local character = glb.newModel("models/character.glb", {0, 0, 0})
character:play("Walk")

function love.update(dt)
    character:update(dt)
end

function love.draw()
    character:draw()
end
```

## Available commands

All commands have English and Portuguese names. You can use whichever you prefer.

| English | Portuguese | Description |
|---|---|---|
| `glb.newModel(path, pos, rot, scale)` | `glb.novoModelo(...)` | Loads the .glb file |
| `m:play(name, loop)` | `m:tocar(nome, repetir)` | Plays an animation. Loop is enabled by default |
| `m:pause()` | `m:pausar()` | Pauses the animation |
| `m:resume()` | `m:continuar()` | Resumes the animation |
| `m:stop()` | `m:parar()` | Stops and returns to the initial pose |
| `m:setSpeed(v)` | `m:velocidade(v)` | Sets the animation speed |
| `m:setTime(t)` | `m:tempo(t)` | Sets the animation time |
| `m:getTime()` | `m:tempo()` | Returns the current time |
| `m:getDuration()` | `m:duracao()` | Returns the animation duration |
| `m:getAnimations()` | `m:animacoes()` | Lists available animations |
| `m:getCurrent()` | `m:atual()` | Returns the current animation |
| `m:isPlaying()` | `m:tocando()` | Checks whether the animation is playing |
| `m:onFinish(fn)` | `m:aoTerminar(fn)` | Calls a function when a non-looping animation finishes |
| `m:update(dt)` | `m:atualizar(dt)` | Updates the animation |
| `m:draw()` | `m:desenhar()` | Draws the model |

## Tips

- Animation names do not need to match exactly: `play("walk")` can also find `"Walk"` or `"Armature|Walk"`.
- Calling `play()` with an animation that is already playing will not restart it.
- To play an animation only once, use `character:play("Attack", false)`.
- Use `onFinish` to execute a function when an animation finishes.
- Original g3d model functions are still available, including `setTranslation`, `setRotation` and `setScale`.
- The original g3d model is accessible through `character.model`.

## Static model

```lua
local g3d = require "g3d"
local glb = require "g3d.glb"

local verts, tex = glb.load("models/magic_cube.glb")
local model = g3d.newModel(verts, tex, {0, 0, 0}, nil, 1)
```

`glb.load(path, yUp)` converts glTF's Y-up coordinate system to g3d's Z-up system. If the model appears tilted, use `glb.load(path, false)`.

## Example

```bash
love example
```

The example includes a magic cube with three animations (`Rotacao 360`, `Balanco` and `Pulo`), alongside the same file loaded as a static model.

**Controls:**
- `1`, `2` and `3`: Switch animations.
- `Space`: Pause.
- `↑` and `↓`: Change animation speed.
- `S`: Stop the animation.

Requires LÖVE 11.x.

The `cubo_magico.glb` model was created by **generico_cube**.

## Creating an animated .glb

In Blender, create an armature, add your animations and export as **glTF Binary (.glb)** with animation export enabled.

To include multiple animations in the same file, export your Actions or NLA Tracks.

## Supported features

- Position, UVs, normals and vertex colors (`COLOR_0`).
- Embedded `baseColor` textures in .glb files (PNG/JPG).
- Skeletal animation with up to 4 bones per vertex (skinning).
- Node hierarchy and transformations.
- Translation, rotation and scale animations (`LINEAR`, `STEP`, `CUBICSPLINE`).
- Multiple animations in a single .glb file.
- Multiple meshes combined into a single model.

## Limitations

- One texture per model.
- Base color only; no PBR or normal maps.
- No morph targets (shape keys).
- No animation blending.
- Only `.glb` files with embedded images are supported. `.gltf` and external textures are not supported.
- Animation is calculated on the CPU every frame, which may affect performance with models containing many thousands of vertices.

## License

MIT. Made by **generico_cube**.

The g3d library, included in `example/g3d/`, belongs to [groverburger](https://github.com/groverburger/g3d) and is also licensed under MIT. See `example/g3d/LICENSE-g3d`.
