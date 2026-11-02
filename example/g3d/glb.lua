-- glb.lua: carregador simples de .glb para o g3d (LÖVE)
-- Feito por generico_cube (MIT) / Made by generico_cube (MIT)
--
-- Uso:
--   local g3d = require "g3d"
--   local glb = require "g3d.glb"
--   local verts, tex = glb.load("modelo.glb")
--   local model = g3d.newModel(verts, tex, {0, 0, 0}, nil, 1)
--
-- Limitações: ignora transformações de nós, animações e materiais além da
-- textura baseColor. Junta todas as malhas em uma só.

local glb = {}

-- JSON mínimo (suficiente para o chunk JSON do glTF)
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

local compSize = { [5120] = 1, [5121] = 1, [5122] = 2, [5123] = 2, [5125] = 4, [5126] = 4 }
local compFmt = { [5120] = "b", [5121] = "B", [5122] = "<h", [5123] = "<H", [5125] = "<I4", [5126] = "<f" }
local nComp = { SCALAR = 1, VEC2 = 2, VEC3 = 3, VEC4 = 4 }

-- yUp = true (padrão) converte do Y-up do glTF para o Z-up do g3d
function glb.load(path, yUp)
    if yUp == nil then yUp = true end

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

    local function readAccessor(i)
        local a = json.accessors[i + 1]
        local bv = json.bufferViews[a.bufferView + 1]
        local n, cs = nComp[a.type], compSize[a.componentType]
        local stride = bv.byteStride or (n * cs)
        local base = (bv.byteOffset or 0) + (a.byteOffset or 0) + 1
        local fmt = compFmt[a.componentType]
        local norm = a.normalized and ({ [5121] = 255, [5123] = 65535 })[a.componentType]
        local out = {}
        for e = 0, a.count - 1 do
            local q = base + e * stride
            for c = 0, n - 1 do
                local v = love.data.unpack(fmt, bin, q + c * cs)
                out[#out + 1] = norm and v / norm or v
            end
        end
        return out
    end

    local function loadTexture(materialIndex)
        local mat = materialIndex and json.materials and json.materials[materialIndex + 1]
        local info = mat and mat.pbrMetallicRoughness and mat.pbrMetallicRoughness.baseColorTexture
        if not info then return nil end
        local tex = json.textures[info.index + 1]
        local img = json.images[tex.source + 1]
        if not img.bufferView then return nil end -- imagem externa não suportada
        local bv = json.bufferViews[img.bufferView + 1]
        local off = (bv.byteOffset or 0) + 1
        local bytes = bin:sub(off, off + bv.byteLength - 1)
        local fileData = love.filesystem.newFileData(bytes, "textura.png")
        return love.image.newImageData(fileData)
    end

    local verts, texture = {}, nil
    local noUV = {} -- vértices sem UV (precisam de um pixel branco)

    for _, mesh in ipairs(json.meshes) do
        for _, prim in ipairs(mesh.primitives) do
            if (prim.mode or 4) == 4 then -- só triângulos
                local pos = readAccessor(prim.attributes.POSITION)
                local uv = prim.attributes.TEXCOORD_0 and readAccessor(prim.attributes.TEXCOORD_0)
                local nor = prim.attributes.NORMAL and readAccessor(prim.attributes.NORMAL)
                local idx = prim.indices and readAccessor(prim.indices)
                local col = prim.attributes.COLOR_0 and readAccessor(prim.attributes.COLOR_0)
                local colN = col and (json.accessors[prim.attributes.COLOR_0 + 1].type == "VEC4" and 4 or 3)
                local hasUV = uv ~= nil

                -- só usa a textura se o modelo tem UV (senão a textura pinta tudo errado)
                if hasUV then texture = texture or loadTexture(prim.material) end

                local count = idx and #idx or (#pos / 3)
                for k = 1, count do
                    local i = idx and idx[k] or (k - 1)
                    local x, y, z = pos[i * 3 + 1], pos[i * 3 + 2], pos[i * 3 + 3]
                    local nx, ny, nz = 0, 1, 0
                    if nor then nx, ny, nz = nor[i * 3 + 1], nor[i * 3 + 2], nor[i * 3 + 3] end
                    if yUp then
                        y, z = -z, y
                        ny, nz = -nz, ny
                    end
                    if not hasUV then noUV[#verts + 1] = true end
                    verts[#verts + 1] = {
                        x, y, z,
                        uv and uv[i * 2 + 1] or 0, uv and uv[i * 2 + 2] or 0,
                        nx, ny, nz,
                        col and col[i * colN + 1] or 1,
                        col and col[i * colN + 2] or 1,
                        col and col[i * colN + 3] or 1,
                        col and colN == 4 and col[i * colN + 4] or 1,
                    }
                end
            end
        end
    end

    if not texture then
        local img = love.image.newImageData(1, 1)
        img:setPixel(0, 0, 1, 1, 1, 1)
        return verts, love.graphics.newImage(img)
    end

    -- mistura de partes com e sem UV: adiciona uma linha branca embaixo da
    -- textura e aponta os vértices sem UV pra ela (assim a cor do vértice
    -- aparece pura, sem ser escurecida pela textura)
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

    return verts, love.graphics.newImage(texture)
end

return glb
