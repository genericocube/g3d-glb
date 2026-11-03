-- glb.lua: carregador de .glb para o g3d (LÖVE), com animações por esqueleto
-- Feito por generico_cube (MIT) / Made by generico_cube (MIT)
--
-- ESTÁTICO / STATIC (modelo parado):
--   local g3d = require "g3d"
--   local glb = require "g3d.glb"
--   local verts, tex = glb.load("modelo.glb")
--   local model = g3d.newModel(verts, tex, {0, 0, 0}, nil, 1)
--
-- ANIMADO / ANIMATED:
--   local personagem = glb.newModel("personagem.glb", {0, 0, 0})   -- ou glb.novoModelo
--   personagem:play("Walk")        -- ou personagem:tocar("Walk")
--   function love.update(dt) personagem:update(dt) end             -- ou :atualizar(dt)
--   function love.draw()     personagem:draw()   end               -- ou :desenhar()
--
-- Comandos / Commands (EN / PT):
--   play(nome, loop)   / tocar(nome, repetir)  toca uma animação (nome ou número)
--   pause()            / pausar()
--   resume()           / continuar()
--   stop()             / parar()               volta para a pose parada
--   setSpeed(v)        / velocidade(v)         1 = normal, 2 = dobro, -1 = ao contrário
--   setTime(t)         / tempo(t)              pula para o tempo t (segundos)
--   getTime()          / tempo()               tempo atual
--   getDuration()      / duracao()             duração da animação atual
--   getAnimations()    / animacoes()           lista com os nomes das animações
--   getCurrent()       / atual()               nome da animação atual
--   isPlaying()        / tocando()
--   onFinish(fn)       / aoTerminar(fn)        chamada quando uma animação sem loop acaba
--
-- Qualquer função do model do g3d também funciona direto no personagem:
--   personagem:setTranslation(x, y, z), personagem:setRotation(...), personagem:setScale(...)
--
-- Limitações / Limitations: uma textura por modelo (baseColor), sem morph targets,
-- sem mistura (blend) entre animações. A animação é calculada na CPU (ok para low-poly).

local modname = ...
local glb = {}

----------------------------------------------------------------------------------------------------
-- JSON mínimo (suficiente para o chunk JSON do glTF)
----------------------------------------------------------------------------------------------------
local function jsonDecode(s)
    local pos = 1
    local function ws() pos = s:find("%S", pos) or #s + 1 end
    local value

    local esc = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
    local function str()
        local out, i = {}, pos + 1
        while true do
            local c = s:sub(i, i)
            if c == '"' then
                pos = i + 1
                return table.concat(out)
            elseif c == "\\" then
                local n = s:sub(i + 1, i + 1)
                if n == "u" then
                    out[#out + 1] = "?"
                    i = i + 6
                else
                    out[#out + 1] = esc[n] or n
                    i = i + 2
                end
            else
                out[#out + 1] = c
                i = i + 1
            end
        end
    end

    function value()
        ws()
        local c = s:sub(pos, pos)
        if c == "{" then
            local t = {}
            pos = pos + 1
            ws()
            if s:sub(pos, pos) == "}" then pos = pos + 1 return t end
            while true do
                ws()
                local k = str()
                ws()
                pos = pos + 1 -- ':'
                t[k] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == "}" then return t end
            end
        elseif c == "[" then
            local t = {}
            pos = pos + 1
            ws()
            if s:sub(pos, pos) == "]" then pos = pos + 1 return t end
            while true do
                t[#t + 1] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == "]" then return t end
            end
        elseif c == '"' then
            return str()
        elseif s:find("^true", pos) then
            pos = pos + 4
            return true
        elseif s:find("^false", pos) then
            pos = pos + 5
            return false
        elseif s:find("^null", pos) then
            pos = pos + 4
            return nil
        else
            local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
            pos = pos + #num
            return tonumber(num)
        end
    end

    return value()
end

----------------------------------------------------------------------------------------------------
-- Leitura do arquivo .glb
----------------------------------------------------------------------------------------------------
local compSize = { [5120] = 1, [5121] = 1, [5122] = 2, [5123] = 2, [5125] = 4, [5126] = 4 }
local compFmt = { [5120] = "b", [5121] = "B", [5122] = "<h", [5123] = "<H", [5125] = "<I4", [5126] = "<f" }
local compNorm = { [5120] = 127, [5121] = 255, [5122] = 32767, [5123] = 65535 }
local nComp = { SCALAR = 1, VEC2 = 2, VEC3 = 3, VEC4 = 4, MAT4 = 16 }

local function parseGlb(path)
    local data = assert(love.filesystem.read(path), "não achei o arquivo: " .. path)
    assert(data:sub(1, 4) == "glTF", "isso não é um arquivo .glb")

    -- chunks: JSON e BIN
    local json, bin
    local p = 13
    while p <= #data do
        local len = love.data.unpack("<I4", data, p)
        local typ = data:sub(p + 4, p + 7)
        local chunk = data:sub(p + 8, p + 7 + len)
        if typ == "JSON" then
            json = jsonDecode(chunk)
        elseif typ:sub(1, 3) == "BIN" then
            bin = chunk
        end
        p = p + 8 + len
    end
    assert(json and bin, "GLB sem chunk JSON ou BIN")
    assert(json.meshes and #json.meshes > 0, "GLB sem malhas (meshes)")
    return json, bin
end

-- devolve uma função que lê um accessor como lista simples de números
local function makeReader(json, bin)
    local cache = {}
    return function(i)
        if cache[i] then return cache[i] end
        local a = json.accessors[i + 1]
        local n = nComp[a.type]
        local out = {}
        if not a.bufferView then
            for k = 1, a.count * n do out[k] = 0 end
        else
            local bv = json.bufferViews[a.bufferView + 1]
            local cs = compSize[a.componentType]
            local stride = bv.byteStride or (n * cs)
            local base = (bv.byteOffset or 0) + (a.byteOffset or 0) + 1
            local fmt = compFmt[a.componentType]
            local div = a.normalized and compNorm[a.componentType]
            for e = 0, a.count - 1 do
                local q = base + e * stride
                for c = 0, n - 1 do
                    local v = love.data.unpack(fmt, bin, q + c * cs)
                    if div then
                        v = v / div
                        if v < -1 then v = -1 end
                    end
                    out[#out + 1] = v
                end
            end
        end
        cache[i] = out
        return out
    end
end

----------------------------------------------------------------------------------------------------
-- Matemática (matrizes 4x4 em lista de 16 números, ordem de colunas como no glTF)
----------------------------------------------------------------------------------------------------
-- o = a * b   (o precisa ser diferente de a e b)
local function mul(o, a, b)
    for c = 0, 3 do
        local b1, b2, b3, b4 = b[c * 4 + 1], b[c * 4 + 2], b[c * 4 + 3], b[c * 4 + 4]
        o[c * 4 + 1] = a[1] * b1 + a[5] * b2 + a[9] * b3 + a[13] * b4
        o[c * 4 + 2] = a[2] * b1 + a[6] * b2 + a[10] * b3 + a[14] * b4
        o[c * 4 + 3] = a[3] * b1 + a[7] * b2 + a[11] * b3 + a[15] * b4
        o[c * 4 + 4] = a[4] * b1 + a[8] * b2 + a[12] * b3 + a[16] * b4
    end
end

-- o = Translação * Rotação(quaternion x,y,z,w) * Escala
local function compose(o, t, r, s)
    local x, y, z, w = r[1], r[2], r[3], r[4]
    local xx, yy, zz = x * x, y * y, z * z
    local xy, xz, yz, xw, yw, zw = x * y, x * z, y * z, x * w, y * w, z * w
    o[1], o[2], o[3], o[4] = (1 - 2 * (yy + zz)) * s[1], 2 * (xy + zw) * s[1], 2 * (xz - yw) * s[1], 0
    o[5], o[6], o[7], o[8] = 2 * (xy - zw) * s[2], (1 - 2 * (xx + zz)) * s[2], 2 * (yz + xw) * s[2], 0
    o[9], o[10], o[11], o[12] = 2 * (xz + yw) * s[3], 2 * (yz - xw) * s[3], (1 - 2 * (xx + yy)) * s[3], 0
    o[13], o[14], o[15], o[16] = t[1], t[2], t[3], 1
end

local function copyMat(o, m)
    for i = 1, 16 do o[i] = m[i] end
end

local function normalize4(o)
    local l = math.sqrt(o[1] * o[1] + o[2] * o[2] + o[3] * o[3] + o[4] * o[4])
    if l > 0 then
        for i = 1, 4 do o[i] = o[i] / l end
    end
end

----------------------------------------------------------------------------------------------------
-- Animação: amostra um canal (translation / rotation / scale) num instante t
----------------------------------------------------------------------------------------------------
local function sampleChannel(ch, t, out)
    local times, vals, n = ch.times, ch.values, ch.n
    local cnt = #times
    if cnt == 0 then return end
    local interp = ch.interp
    local cubic = interp == "CUBICSPLINE"
    local stride = cubic and 3 * n or n
    local off = cubic and n or 0 -- onde fica o valor dentro de cada chave

    if cnt == 1 or t <= times[1] then
        for c = 1, n do out[c] = vals[off + c] end
        return
    end
    if t >= times[cnt] then
        local b = (cnt - 1) * stride + off
        for c = 1, n do out[c] = vals[b + c] end
        return
    end

    -- acha k tal que times[k] <= t < times[k+1]
    local lo, hi = 1, cnt
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if times[mid] <= t then lo = mid else hi = mid end
    end
    local k = lo
    local dt = times[k + 1] - times[k]
    local s = dt > 0 and (t - times[k]) / dt or 0
    local b0 = (k - 1) * stride + off
    local b1 = k * stride + off

    if interp == "STEP" then
        for c = 1, n do out[c] = vals[b0 + c] end
    elseif cubic then
        local s2 = s * s
        local s3 = s2 * s
        local h00, h10, h01, h11 = 2 * s3 - 3 * s2 + 1, s3 - 2 * s2 + s, -2 * s3 + 3 * s2, s3 - s2
        for c = 1, n do
            local p0, m0 = vals[b0 + c], dt * vals[b0 + n + c] -- valor e tangente de saída
            local p1, m1 = vals[b1 + c], dt * vals[b1 - n + c] -- valor e tangente de entrada
            out[c] = h00 * p0 + h10 * m0 + h01 * p1 + h11 * m1
        end
        if n == 4 then normalize4(out) end
    elseif n == 4 then
        -- slerp de quaternions
        local ax, ay, az, aw = vals[b0 + 1], vals[b0 + 2], vals[b0 + 3], vals[b0 + 4]
        local bx, by, bz, bw = vals[b1 + 1], vals[b1 + 2], vals[b1 + 3], vals[b1 + 4]
        local d = ax * bx + ay * by + az * bz + aw * bw
        if d < 0 then d, bx, by, bz, bw = -d, -bx, -by, -bz, -bw end
        local k0, k1
        if d > 0.9995 then
            k0, k1 = 1 - s, s
        else
            local th = math.acos(d)
            local sn = math.sin(th)
            k0, k1 = math.sin((1 - s) * th) / sn, math.sin(s * th) / sn
        end
        out[1], out[2], out[3], out[4] = k0 * ax + k1 * bx, k0 * ay + k1 * by, k0 * az + k1 * bz, k0 * aw + k1 * bw
        normalize4(out)
    else
        for c = 1, n do out[c] = vals[b0 + c] * (1 - s) + vals[b1 + c] * s end
    end
end

----------------------------------------------------------------------------------------------------
-- Monta o modelo: vértices, textura, esqueleto e animações
----------------------------------------------------------------------------------------------------
local function build(path, yUp)
    if yUp == nil then yUp = true end
    local json, bin = parseGlb(path)
    local readAccessor = makeReader(json, bin)

    local function loadTexture(materialIndex)
        local mat = materialIndex and json.materials and json.materials[materialIndex + 1]
        local info = mat and mat.pbrMetallicRoughness and mat.pbrMetallicRoughness.baseColorTexture
        if not info then return nil end
        local tex = json.textures[info.index + 1]
        local img = json.images and json.images[tex.source + 1]
        if not img or not img.bufferView then return nil end -- imagem externa não suportada
        local bv = json.bufferViews[img.bufferView + 1]
        local off = (bv.byteOffset or 0) + 1
        local bytes = bin:sub(off, off + bv.byteLength - 1)
        local fileData = love.filesystem.newFileData(bytes, "textura.png")
        return love.image.newImageData(fileData)
    end

    -- nós (hierarquia) --------------------------------------------------------------------------
    local jnodes = json.nodes
    if not jnodes then
        jnodes = {}
        for mi = 1, #json.meshes do jnodes[mi] = { mesh = mi - 1 } end
    end
    local nodes = {}
    for i, jn in ipairs(jnodes) do
        nodes[i] = {
            t = jn.translation or { 0, 0, 0 },
            r = jn.rotation or { 0, 0, 0, 1 },
            s = jn.scale or { 1, 1, 1 },
            matrix = jn.matrix,
            children = {},
            mesh = jn.mesh,
            skin = jn.skin,
        }
    end
    for i, jn in ipairs(jnodes) do
        for _, c in ipairs(jn.children or {}) do
            nodes[i].children[#nodes[i].children + 1] = c + 1
            nodes[c + 1].parent = i
        end
    end

    -- ordem: pais sempre antes dos filhos
    local order, stack = {}, {}
    for i = #nodes, 1, -1 do
        if not nodes[i].parent then stack[#stack + 1] = i end
    end
    while #stack > 0 do
        local i = table.remove(stack)
        order[#order + 1] = i
        local ch = nodes[i].children
        for k = #ch, 1, -1 do stack[#stack + 1] = ch[k] end
    end

    -- quais nós fazem parte da cena (só eles são desenhados)
    local inScene = {}
    local scene = json.scenes and json.scenes[(json.scene or 0) + 1]
    if scene and scene.nodes then
        local st = {}
        for _, ni in ipairs(scene.nodes) do st[#st + 1] = ni + 1 end
        while #st > 0 do
            local i = table.remove(st)
            inScene[i] = true
            for _, c in ipairs(nodes[i].children) do st[#st + 1] = c end
        end
    else
        for i = 1, #nodes do inScene[i] = true end
    end

    local curT, curR, curS, world = {}, {}, {}, {}
    for i = 1, #nodes do
        curT[i], curR[i], curS[i], world[i] = { 0, 0, 0 }, { 0, 0, 0, 1 }, { 1, 1, 1 }, {}
    end
    local localMat = {}

    -- skins (ossos) -----------------------------------------------------------------------------
    local skins = {}
    for si, sk in ipairs(json.skins or {}) do
        local flat = sk.inverseBindMatrices and readAccessor(sk.inverseBindMatrices)
        local s = { joints = {}, ibm = {}, mats = {} }
        for j, jn in ipairs(sk.joints) do
            s.joints[j] = jn + 1
            local ib = {}
            for k = 1, 16 do
                if flat then
                    ib[k] = flat[(j - 1) * 16 + k]
                else
                    ib[k] = (k == 1 or k == 6 or k == 11 or k == 16) and 1 or 0
                end
            end
            s.ibm[j] = ib
            s.mats[j] = {}
        end
        skins[si] = s
    end

    -- malhas ------------------------------------------------------------------------------------
    local verts, texture, noUV, prims = {}, nil, {}, {}

    for _, ni in ipairs(order) do
        local nd = nodes[ni]
        if inScene[ni] and nd.mesh then
            for _, prim in ipairs(json.meshes[nd.mesh + 1].primitives) do
                if (prim.mode or 4) == 4 and prim.attributes.POSITION then -- só triângulos
                    local at = prim.attributes
                    local pos = readAccessor(at.POSITION)
                    local nv = math.floor(#pos / 3)
                    local uv = at.TEXCOORD_0 and readAccessor(at.TEXCOORD_0)
                    local nor = at.NORMAL and readAccessor(at.NORMAL)
                    local idx = prim.indices and readAccessor(prim.indices)
                    local col = at.COLOR_0 and readAccessor(at.COLOR_0)
                    local colN = col and (json.accessors[at.COLOR_0 + 1].type == "VEC4" and 4 or 3)
                    local hasUV = uv ~= nil

                    if not nor then
                        nor = {}
                        for v = 0, nv - 1 do nor[v * 3 + 1], nor[v * 3 + 2], nor[v * 3 + 3] = 0, 1, 0 end
                    end

                    -- só usa a textura se o modelo tem UV
                    if hasUV then texture = texture or loadTexture(prim.material) end

                    local pr = {
                        node = ni,
                        pos = pos,
                        nor = nor,
                        nv = nv,
                        ids = {},
                        out = {},
                        start = #verts + 1,
                    }
                    if nd.skin and at.JOINTS_0 and at.WEIGHTS_0 and skins[nd.skin + 1] then
                        pr.skin = nd.skin + 1
                        pr.joints = readAccessor(at.JOINTS_0)
                        pr.weights = readAccessor(at.WEIGHTS_0)
                    end

                    local count = idx and #idx or nv
                    pr.count = count
                    for k = 1, count do
                        local i = idx and idx[k] or (k - 1)
                        pr.ids[k] = i
                        if not hasUV then noUV[#verts + 1] = true end
                        verts[#verts + 1] = {
                            0, 0, 0,
                            uv and uv[i * 2 + 1] or 0, uv and uv[i * 2 + 2] or 0,
                            0, 1, 0,
                            col and col[i * colN + 1] or 1,
                            col and col[i * colN + 2] or 1,
                            col and col[i * colN + 3] or 1,
                            col and colN == 4 and col[i * colN + 4] or 1,
                        }
                    end
                    prims[#prims + 1] = pr
                end
            end
        end
    end
    assert(#verts > 0, "nenhuma malha de triângulos encontrada no GLB")

    -- animações ---------------------------------------------------------------------------------
    local animations = {}
    for ai, a in ipairs(json.animations or {}) do
        local anim = { name = a.name or ("animacao_" .. ai), channels = {}, duration = 0 }
        for _, c in ipairs(a.channels or {}) do
            local path = c.target and c.target.path
            if c.target and c.target.node and (path == "translation" or path == "rotation" or path == "scale") then
                local sm = a.samplers[c.sampler + 1]
                local times = readAccessor(sm.input)
                anim.channels[#anim.channels + 1] = {
                    node = c.target.node + 1,
                    path = path,
                    times = times,
                    values = readAccessor(sm.output),
                    n = path == "rotation" and 4 or 3,
                    interp = sm.interpolation or "LINEAR",
                }
                if #times > 0 and times[#times] > anim.duration then anim.duration = times[#times] end
            end
        end
        animations[#animations + 1] = anim
    end

    -- calcula a pose (anim pode ser nil = pose parada) e escreve nos vértices -----------------
    local tmp = {}
    local function evaluate(anim, time)
        for i, nd in ipairs(nodes) do
            local t, r, s = curT[i], curR[i], curS[i]
            t[1], t[2], t[3] = nd.t[1], nd.t[2], nd.t[3]
            r[1], r[2], r[3], r[4] = nd.r[1], nd.r[2], nd.r[3], nd.r[4]
            s[1], s[2], s[3] = nd.s[1], nd.s[2], nd.s[3]
        end
        if anim then
            for _, ch in ipairs(anim.channels) do
                sampleChannel(ch, time, tmp)
                local dst = ch.path == "translation" and curT[ch.node]
                    or ch.path == "rotation" and curR[ch.node]
                    or curS[ch.node]
                for c = 1, ch.n do dst[c] = tmp[c] end
            end
        end

        for _, ni in ipairs(order) do
            local nd = nodes[ni]
            local L = localMat
            if nd.matrix then
                for k = 1, 16 do L[k] = nd.matrix[k] end
            else
                compose(L, curT[ni], curR[ni], curS[ni])
            end
            if nd.parent then
                mul(world[ni], world[nd.parent], L)
            else
                copyMat(world[ni], L)
            end
        end

        for _, sk in ipairs(skins) do
            for j, jn in ipairs(sk.joints) do
                mul(sk.mats[j], world[jn], sk.ibm[j])
            end
        end

        for _, pr in ipairs(prims) do
            local P, N, out = pr.pos, pr.nor, pr.out
            local M = (not pr.skin) and world[pr.node]
            local jm = pr.skin and skins[pr.skin].mats
            for v = 0, pr.nv - 1 do
                local px, py, pz = P[v * 3 + 1], P[v * 3 + 2], P[v * 3 + 3]
                local nx, ny, nz = N[v * 3 + 1], N[v * 3 + 2], N[v * 3 + 3]
                local X, Y, Z, NX, NY, NZ
                if M then
                    X = M[1] * px + M[5] * py + M[9] * pz + M[13]
                    Y = M[2] * px + M[6] * py + M[10] * pz + M[14]
                    Z = M[3] * px + M[7] * py + M[11] * pz + M[15]
                    NX = M[1] * nx + M[5] * ny + M[9] * nz
                    NY = M[2] * nx + M[6] * ny + M[10] * nz
                    NZ = M[3] * nx + M[7] * ny + M[11] * nz
                else
                    X, Y, Z, NX, NY, NZ = 0, 0, 0, 0, 0, 0
                    for j = 1, 4 do
                        local w = pr.weights[v * 4 + j]
                        if w > 0 then
                            local m = jm[pr.joints[v * 4 + j] + 1]
                            X = X + w * (m[1] * px + m[5] * py + m[9] * pz + m[13])
                            Y = Y + w * (m[2] * px + m[6] * py + m[10] * pz + m[14])
                            Z = Z + w * (m[3] * px + m[7] * py + m[11] * pz + m[15])
                            NX = NX + w * (m[1] * nx + m[5] * ny + m[9] * nz)
                            NY = NY + w * (m[2] * nx + m[6] * ny + m[10] * nz)
                            NZ = NZ + w * (m[3] * nx + m[7] * ny + m[11] * nz)
                        end
                    end
                end
                local nl = math.sqrt(NX * NX + NY * NY + NZ * NZ)
                if nl > 0 then NX, NY, NZ = NX / nl, NY / nl, NZ / nl end
                if yUp then -- Y-up (glTF) -> Z-up (g3d)
                    Y, Z = -Z, Y
                    NY, NZ = -NZ, NY
                end
                local o = v * 6
                out[o + 1], out[o + 2], out[o + 3], out[o + 4], out[o + 5], out[o + 6] = X, Y, Z, NX, NY, NZ
            end
            for k = 1, pr.count do
                local o = pr.ids[k] * 6
                local vt = verts[pr.start + k - 1]
                vt[1], vt[2], vt[3] = out[o + 1], out[o + 2], out[o + 3]
                vt[6], vt[7], vt[8] = out[o + 4], out[o + 5], out[o + 6]
            end
        end
    end

    evaluate(nil, 0)

    -- textura --------------------------------------------------------------------------------
    if not texture then
        local img = love.image.newImageData(1, 1)
        img:setPixel(0, 0, 1, 1, 1, 1)
        texture = love.graphics.newImage(img)
    else
        -- mistura de partes com e sem UV: adiciona uma linha branca embaixo da textura e aponta
        -- os vértices sem UV pra ela (a cor do vértice aparece pura, sem ser escurecida)
        if next(noUV) then
            local w, h = texture:getDimensions()
            local big = love.image.newImageData(w, h + 1)
            big:paste(texture, 0, 0, 0, 0, w, h)
            for x = 0, w - 1 do big:setPixel(x, h, 1, 1, 1, 1) end
            for _, v in ipairs(verts) do v[5] = v[5] * h / (h + 1) end
            for i in pairs(noUV) do
                verts[i][4] = 0.5 / w
                verts[i][5] = (h + 0.5) / (h + 1)
            end
            texture = big
        end
        texture = love.graphics.newImage(texture)
    end

    return { verts = verts, texture = texture, animations = animations, evaluate = evaluate }
end

----------------------------------------------------------------------------------------------------
-- API estática (compatível com a versão anterior)
----------------------------------------------------------------------------------------------------
-- yUp = true (padrão) converte do Y-up do glTF para o Z-up do g3d
function glb.load(path, yUp)
    local rig = build(path, yUp)
    return rig.verts, rig.texture
end

----------------------------------------------------------------------------------------------------
-- API animada
----------------------------------------------------------------------------------------------------
local Animated = {}

local function describe(self)
    local names = {}
    for i, a in ipairs(self.animations) do names[i] = a.name end
    return #names > 0 and table.concat(names, ", ") or "(nenhuma)"
end

-- procura por número, nome exato, nome sem diferenciar maiúsculas, ou parte do nome
local function find(self, name)
    if type(name) == "number" then
        if self.animations[name] then return self.animations[name] end
    elseif type(name) == "string" then
        for _, a in ipairs(self.animations) do
            if a.name == name then return a end
        end
        local low = name:lower()
        for _, a in ipairs(self.animations) do
            if a.name:lower() == low then return a end
        end
        for _, a in ipairs(self.animations) do
            if a.name:lower():find(low, 1, true) then return a end
        end
    end
    error("animação '" .. tostring(name) .. "' não existe / animation not found. Disponíveis: " .. describe(self), 3)
end

local function refresh(self)
    self.rig.evaluate(self.current, self.time)
    self.model.mesh:setVertices(self.model.verts)
end

-- toca uma animação. loop é true por padrão. Se essa animação já está tocando, não reinicia
-- (assim dá pra chamar play() todo frame sem problema).
function Animated:play(name, loop, restart)
    local anim = find(self, name)
    if self.current == anim and self.playing and not restart then
        if loop ~= nil then self.looping = loop end
        return self
    end
    self.current = anim
    self.time = 0
    self.playing = true
    self.looping = loop ~= false
    refresh(self)
    return self
end

function Animated:pause()
    self.playing = false
    return self
end

function Animated:resume()
    if self.current then self.playing = true end
    return self
end

function Animated:stop()
    self.current = nil
    self.playing = false
    self.time = 0
    refresh(self)
    return self
end

function Animated:setSpeed(v)
    self.speed = v
    return self
end

-- sem argumento devolve o tempo atual; com argumento pula para esse tempo
function Animated:setTime(t)
    if t == nil then return self.time end
    self.time = t
    if self.current then refresh(self) end
    return self
end

function Animated:getTime()
    return self.time
end

function Animated:getDuration()
    return self.current and self.current.duration or 0
end

function Animated:getAnimations()
    local names = {}
    for i, a in ipairs(self.animations) do names[i] = a.name end
    return names
end

function Animated:getCurrent()
    return self.current and self.current.name or nil
end

function Animated:isPlaying()
    return self.playing
end

function Animated:onFinish(fn)
    self.finishFn = fn
    return self
end

function Animated:update(dt)
    local anim = self.current
    if not self.playing or not anim then return end
    local d = anim.duration
    local ended = false
    self.time = self.time + dt * self.speed
    if d > 0 then
        if self.looping then
            self.time = self.time % d
        elseif self.time >= d then
            self.time, ended = d, true
        elseif self.time <= 0 and self.speed < 0 then
            self.time, ended = 0, true
        end
    end
    refresh(self)
    if ended then
        self.playing = false
        if self.finishFn then self.finishFn(self, anim.name) end
    end
end

function Animated:draw(shader)
    self.model:draw(shader)
end

-- nomes em português
Animated.tocar = Animated.play
Animated.pausar = Animated.pause
Animated.continuar = Animated.resume
Animated.parar = Animated.stop
Animated.velocidade = Animated.setSpeed
Animated.tempo = Animated.setTime
Animated.duracao = Animated.getDuration
Animated.animacoes = Animated.getAnimations
Animated.atual = Animated.getCurrent
Animated.tocando = Animated.isPlaying
Animated.aoTerminar = Animated.onFinish
Animated.atualizar = Animated.update
Animated.desenhar = Animated.draw

-- funções do model do g3d (setTranslation, setRotation...) funcionam direto no personagem
local mt = {}
mt.__index = function(t, k)
    local m = Animated[k]
    if m ~= nil then return m end
    local mv = rawget(t, "model")[k]
    if type(mv) == "function" then
        local f = function(self, ...) return mv(self.model, ...) end
        Animated[k] = f
        return f
    end
    return mv
end

local function loadG3d()
    local parent = modname and modname:match("^(.*)%.[^.]+$")
    return require(parent or "g3d")
end

-- cria um modelo (animado ou não) a partir de um .glb
function glb.newModel(path, translation, rotation, scale, yUp)
    local g3d = loadG3d()
    local rig = build(path, yUp)
    local model = g3d.newModel(rig.verts, rig.texture, translation, rotation, scale)
    return setmetatable({
        model = model,
        rig = rig,
        animations = rig.animations,
        current = nil,
        time = 0,
        speed = 1,
        playing = false,
        looping = true,
    }, mt)
end
glb.novoModelo = glb.newModel

return glb
