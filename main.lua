-- Tic Tac Toe - Love2D
-- Papan 3x3 dengan tampilan modern: animasi tanda, pratinjau saat hover,
-- sorotan garis kemenangan, papan skor, dan lawan komputer.

-- ==== Konfigurasi tampilan ====
local CONFIG = {
    width      = 600,
    height     = 820,
    cellSize   = 160,
    boardX     = 60,
    boardY     = 150,
    panelPad   = 18,
    gridWidth  = 6,
    markWidth  = 13,
}

local COLORS = {
    bgTop     = {0.115, 0.125, 0.165},
    bgBottom  = {0.045, 0.050, 0.075},
    panel     = {0.145, 0.155, 0.200},
    panelEdge = {0.255, 0.275, 0.345},
    grid      = {0.330, 0.355, 0.435},
    text      = {0.940, 0.945, 0.975},
    dim       = {0.555, 0.585, 0.670},
    accent    = {0.450, 0.650, 1.000},
    x         = {1.000, 0.375, 0.400},
    o         = {0.330, 0.730, 1.000},
}

-- ==== Tata letak kontrol ====
local UI = {
    settingsY = 730,
    settingsH = 42,
    modeX     = 56,
    modeW     = 107,
    modeGap   = 6,
    levelX    = 292,
    levelW    = 80,
    levelGap  = 6,
}

local MODE_OPTIONS = {
    { value = "duo",      label = "2 Pemain" },
    { value = "computer", label = "Vs Komputer" },
}

local LEVEL_OPTIONS = {
    { value = "easy",   label = "Mudah" },
    { value = "medium", label = "Sedang" },
    { value = "hard",   label = "Sulit" },
}

local LEVEL_LABELS = { easy = "Mudah", medium = "Sedang", hard = "Sulit" }

-- ==== State permainan ====
local board
local currentPlayer
local gameState          -- "playing", "win", "draw"
local winner
local winLine            -- daftar 3 sel pemenang
local winProgress        -- animasi garis kemenangan (0..1)
local anims              -- animasi kemunculan tanda, per indeks sel

local HUMAN, COMPUTER = "X", "O"
local mode = "duo"             -- "duo" | "computer"
local difficulty = "medium"    -- "easy" | "medium" | "hard"
local aiTimer = nil            -- hitung mundur sebelum komputer melangkah

local allScores = {
    duo      = { X = 0, O = 0, draw = 0 },
    computer = { X = 0, O = 0, draw = 0 },
}
local scores = allScores.duo

local time = 0
local hoverRow, hoverCol
local hoverButtonKind, hoverButtonIndex

local bgMesh
local fontTitle, fontStatus, fontSub, fontScore
local cursorArrow, cursorHand
local cursorMode = "arrow"

local WIN_LINES = {
    { {1, 1}, {1, 2}, {1, 3} },
    { {2, 1}, {2, 2}, {2, 3} },
    { {3, 1}, {3, 2}, {3, 3} },
    { {1, 1}, {2, 1}, {3, 1} },
    { {1, 2}, {2, 2}, {3, 2} },
    { {1, 3}, {2, 3}, {3, 3} },
    { {1, 1}, {2, 2}, {3, 3} },
    { {1, 3}, {2, 2}, {3, 1} },
}

-- ==== Utilitas ====

local function cellTopLeft(row, col)
    return CONFIG.boardX + (col - 1) * CONFIG.cellSize,
           CONFIG.boardY + (row - 1) * CONFIG.cellSize
end

local function cellCenter(row, col)
    local x, y = cellTopLeft(row, col)
    return x + CONFIG.cellSize / 2, y + CONFIG.cellSize / 2
end

local function pointInRect(px, py, x, y, w, h)
    return px >= x and px < x + w and py >= y and py < y + h
end

local function segmentRect(kind, index)
    if kind == "mode" then
        return UI.modeX + (index - 1) * (UI.modeW + UI.modeGap), UI.settingsY,
               UI.modeW, UI.settingsH
    end
    return UI.levelX + (index - 1) * (UI.levelW + UI.levelGap), UI.settingsY,
           UI.levelW, UI.settingsH
end

local function buttonAt(px, py)
    for i = 1, #MODE_OPTIONS do
        local x, y, w, h = segmentRect("mode", i)
        if pointInRect(px, py, x, y, w, h) then
            return "mode", i
        end
    end
    if mode == "computer" then
        for i = 1, #LEVEL_OPTIONS do
            local x, y, w, h = segmentRect("level", i)
            if pointInRect(px, py, x, y, w, h) then
                return "level", i
            end
        end
    end
end

-- Skala "pop" dengan sedikit lonjakan di akhir.
local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local p = t - 1
    return 1 + c3 * p * p * p + c1 * p * p
end

-- Garis dengan ujung membulat (LÖVE tidak punya line cap).
local function lineRound(x1, y1, x2, y2, width)
    love.graphics.setLineWidth(width)
    love.graphics.line(x1, y1, x2, y2)
    local r = width / 2
    love.graphics.circle("fill", x1, y1, r)
    love.graphics.circle("fill", x2, y2, r)
end

local function printCentered(text, font, y, color, alpha)
    love.graphics.setFont(font)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
    love.graphics.print(text, (CONFIG.width - font:getWidth(text)) / 2, y)
end

local function createGradientMesh()
    local top, bottom = COLORS.bgTop, COLORS.bgBottom
    return love.graphics.newMesh({
        {0,               0, 0, 0, top[1], top[2], top[3], 1},
        {CONFIG.width,    0, 0, 0, top[1], top[2], top[3], 1},
        {CONFIG.width, CONFIG.height, 0, 0, bottom[1], bottom[2], bottom[3], 1},
        {0,        CONFIG.height, 0, 0, bottom[1], bottom[2], bottom[3], 1},
    }, "fan", "static")
end

-- ==== Logika permainan ====

local function resetGame()
    board = {}
    for row = 1, 3 do
        board[row] = {}
    end
    currentPlayer = "X"
    gameState = "playing"
    winner = nil
    winLine = nil
    winProgress = 0
    anims = {}
    aiTimer = nil
end

local function findWin()
    for _, line in ipairs(WIN_LINES) do
        local a, b, c = line[1], line[2], line[3]
        local value = board[a[1]][a[2]]
        if value
            and value == board[b[1]][b[2]]
            and value == board[c[1]][c[2]] then
            return line
        end
    end
end

local function boardIsFull()
    for row = 1, 3 do
        for col = 1, 3 do
            if board[row][col] == nil then
                return false
            end
        end
    end
    return true
end

local function isHumanTurn()
    return gameState == "playing"
        and not (mode == "computer" and currentPlayer == COMPUTER)
end

-- Minimax dengan alpha-beta pruning. Skor dari sudut pandang komputer:
-- menang lebih cepat = skor lebih tinggi, kalah lebih lambat = skor lebih tinggi.
local function minimax(depth, computerTurn, alpha, beta)
    local line = findWin()
    if line then
        local symbol = board[line[1][1]][line[1][2]]
        if symbol == COMPUTER then
            return 10 - depth
        end
        return depth - 10
    end
    if boardIsFull() then
        return 0
    end

    if computerTurn then
        local best = -math.huge
        for row = 1, 3 do
            for col = 1, 3 do
                if board[row][col] == nil then
                    board[row][col] = COMPUTER
                    local score = minimax(depth + 1, false, alpha, beta)
                    board[row][col] = nil
                    if score > best then best = score end
                    if best > alpha then alpha = best end
                    if beta <= alpha then return best end
                end
            end
        end
        return best
    end

    local best = math.huge
    for row = 1, 3 do
        for col = 1, 3 do
            if board[row][col] == nil then
                board[row][col] = HUMAN
                local score = minimax(depth + 1, true, alpha, beta)
                board[row][col] = nil
                if score < best then best = score end
                if best < beta then beta = best end
                if beta <= alpha then return best end
            end
        end
    end
    return best
end

local function chooseComputerMove()
    local empties = {}
    for row = 1, 3 do
        for col = 1, 3 do
            if board[row][col] == nil then
                empties[#empties + 1] = { row, col }
            end
        end
    end
    if #empties == 0 then
        return nil
    end

    -- Mudah: acak. Sedang: 65% langkah terbaik. Sulit: selalu optimal.
    local useBest = difficulty == "hard"
        or (difficulty == "medium" and love.math.random() < 0.65)
    if not useBest then
        return empties[love.math.random(#empties)]
    end

    local bestScore = -math.huge
    local bestMoves = {}
    for _, cell in ipairs(empties) do
        board[cell[1]][cell[2]] = COMPUTER
        local score = minimax(1, false, -math.huge, math.huge)
        board[cell[1]][cell[2]] = nil

        if score > bestScore then
            bestScore = score
            bestMoves = { cell }
        elseif score == bestScore then
            bestMoves[#bestMoves + 1] = cell
        end
    end
    -- Pilih acak di antara langkah sama-sama optimal agar variatif.
    return bestMoves[love.math.random(#bestMoves)]
end

local function play(row, col)
    if gameState ~= "playing" or board[row][col] ~= nil then
        return
    end

    board[row][col] = currentPlayer
    anims[row * 3 + col] = { t = 0 }

    local line = findWin()
    if line then
        gameState = "win"
        winner = currentPlayer
        winLine = line
        winProgress = 0
        if winner == "X" then
            scores.X = scores.X + 1
        else
            scores.O = scores.O + 1
        end
    elseif boardIsFull() then
        gameState = "draw"
        scores.draw = scores.draw + 1
    else
        currentPlayer = (currentPlayer == "X") and "O" or "X"
        if mode == "computer" and currentPlayer == COMPUTER then
            -- Jeda singkat supaya terasa seperti sedang berpikir.
            aiTimer = 0.40 + love.math.random() * 0.30
        end
    end
end

local function setMode(value)
    if mode == value then
        return
    end
    mode = value
    scores = allScores[mode]
    resetGame()
end

local function setDifficulty(value)
    difficulty = value
end

-- ==== Menggambar ====

local function drawMark(symbol, cx, cy, scale, alpha, thickness)
    local color = (symbol == "X") and COLORS.x or COLORS.o
    local r = CONFIG.cellSize * 0.28 * scale

    -- Efek glow tipis di belakang tanda
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.10)
    if symbol == "X" then
        local glow = thickness * 2.2
        lineRound(cx - r, cy - r, cx + r, cy + r, glow)
        lineRound(cx + r, cy - r, cx - r, cy + r, glow)
    else
        love.graphics.setLineWidth(thickness * 2.2)
        love.graphics.circle("line", cx, cy, r, 48)
    end

    -- Tanda utama
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    if symbol == "X" then
        lineRound(cx - r, cy - r, cx + r, cy + r, thickness)
        lineRound(cx + r, cy - r, cx - r, cy + r, thickness)
    else
        love.graphics.setLineWidth(thickness)
        love.graphics.circle("line", cx, cy, r, 64)
    end
end

local function drawBackground()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bgMesh)
end

local function drawBoard()
    local pad = CONFIG.panelPad
    local px, py = CONFIG.boardX - pad, CONFIG.boardY - pad
    local size = CONFIG.cellSize * 3 + pad * 2

    -- Bayangan panel
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", px, py + 12, size, size, 26, 26)

    -- Panel papan
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", px, py, size, size, 26, 26)
    love.graphics.setColor(COLORS.panelEdge[1], COLORS.panelEdge[2], COLORS.panelEdge[3], 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", px, py, size, size, 26, 26)

    -- Sorotan sel pemenang
    if gameState == "win" and winLine then
        local c = (winner == "X") and COLORS.x or COLORS.o
        for _, cell in ipairs(winLine) do
            local x, y = cellTopLeft(cell[1], cell[2])
            love.graphics.setColor(c[1], c[2], c[3], 0.10 * winProgress)
            love.graphics.rectangle("fill", x + 5, y + 5,
                CONFIG.cellSize - 10, CONFIG.cellSize - 10, 16, 16)
        end
    end

    -- Sorotan sel yang sedang di-hover
    if hoverRow and hoverCol then
        local x, y = cellTopLeft(hoverRow, hoverCol)
        local pulse = 0.035 + 0.025 * math.sin(time * 5)
        love.graphics.setColor(1, 1, 1, pulse)
        love.graphics.rectangle("fill", x + 5, y + 5,
            CONFIG.cellSize - 10, CONFIG.cellSize - 10, 16, 16)
    end

    -- Garis kisi
    local g = COLORS.grid
    love.graphics.setColor(g[1], g[2], g[3], 0.85)
    local inset = 16
    local boardSize = CONFIG.cellSize * 3
    for i = 1, 2 do
        local gx = CONFIG.boardX + i * CONFIG.cellSize
        lineRound(gx, CONFIG.boardY + inset, gx, CONFIG.boardY + boardSize - inset,
            CONFIG.gridWidth)
        local gy = CONFIG.boardY + i * CONFIG.cellSize
        lineRound(CONFIG.boardX + inset, gy, CONFIG.boardX + boardSize - inset, gy,
            CONFIG.gridWidth)
    end

    -- Tanda X / O
    local winning = {}
    if winLine then
        for _, cell in ipairs(winLine) do
            winning[cell[1] * 3 + cell[2]] = true
        end
    end

    for row = 1, 3 do
        for col = 1, 3 do
            local symbol = board[row][col]
            if symbol then
                local key = row * 3 + col
                local anim = anims[key]
                local t = anim and anim.t or 1
                local scale = easeOutBack(t)
                local alpha = math.min(1, t * 2)
                if gameState == "win" and not winning[key] then
                    alpha = alpha * 0.35
                end
                local cx, cy = cellCenter(row, col)
                drawMark(symbol, cx, cy, scale, alpha, CONFIG.markWidth)
            end
        end
    end

    -- Pratinjau tanda saat kursor berada di sel kosong
    if hoverRow and hoverCol then
        local cx, cy = cellCenter(hoverRow, hoverCol)
        local pulse = 0.18 + 0.05 * math.sin(time * 5)
        drawMark(currentPlayer, cx, cy, 0.82, pulse, CONFIG.markWidth)
    end

    -- Garis kemenangan yang tumbuh dari sel pertama ke sel terakhir
    if gameState == "win" and winLine and winProgress > 0 then
        local c = (winner == "X") and COLORS.x or COLORS.o
        local x1, y1 = cellCenter(winLine[1][1], winLine[1][2])
        local x2, y2 = cellCenter(winLine[3][1], winLine[3][2])
        local ex = x1 + (x2 - x1) * winProgress
        local ey = y1 + (y2 - y1) * winProgress
        local fade = math.min(1, winProgress * 5)

        love.graphics.setColor(c[1], c[2], c[3], 0.10 * winProgress)
        lineRound(x1, y1, ex, ey, 30)
        love.graphics.setColor(c[1], c[2], c[3], 0.22 * winProgress)
        lineRound(x1, y1, ex, ey, 14)
        love.graphics.setColor(c[1], c[2], c[3], 0.95 * fade)
        lineRound(x1, y1, ex, ey, 5)
    end
end

local function drawTopText()
    printCentered("TIC TAC TOE", fontTitle, 22, COLORS.dim)

    love.graphics.setFont(fontStatus)
    local statusY = 46

    if gameState == "playing" then
        if mode == "computer" and currentPlayer == COMPUTER then
            local dots = string.rep(".", (math.floor(time * 2.5) % 3) + 1)
            printCentered("Komputer berpikir" .. dots, fontStatus, statusY, COLORS.o)
        else
            local left = "Giliran "
            local right = currentPlayer
            local lw = fontStatus:getWidth(left)
            local rw = fontStatus:getWidth(right)
            local x = (CONFIG.width - lw - rw) / 2
            local c = (currentPlayer == "X") and COLORS.x or COLORS.o

            love.graphics.setColor(COLORS.text)
            love.graphics.print(left, x, statusY)
            love.graphics.setColor(c)
            love.graphics.print(right, x + lw, statusY)
        end
    elseif gameState == "win" then
        local who, c
        if mode == "computer" then
            if winner == COMPUTER then
                who, c = "Komputer", COLORS.o
            else
                who, c = "Kamu", COLORS.x
            end
        else
            who = winner
            c = (winner == "X") and COLORS.x or COLORS.o
        end

        local right = " menang!"
        local lw = fontStatus:getWidth(who)
        local rw = fontStatus:getWidth(right)
        local x = (CONFIG.width - lw - rw) / 2
        love.graphics.setColor(c)
        love.graphics.print(who, x, statusY)
        love.graphics.setColor(COLORS.text)
        love.graphics.print(right, x + lw, statusY)
    else
        printCentered("Seri!", fontStatus, statusY, COLORS.text)
    end

    local sub
    if gameState ~= "playing" then
        sub = "Klik papan atau tekan R untuk main lagi"
    elseif mode == "computer" then
        sub = "Kamu: X   |   Komputer: O   |   Level: " .. LEVEL_LABELS[difficulty]
    else
        sub = "Klik kotak atau tekan 1-9"
    end
    printCentered(sub, fontSub, 92, COLORS.dim)
end

local function drawScores()
    local pillW, pillH, gap = 128, 46, 14
    local total = pillW * 3 + gap * 2
    local x0 = (CONFIG.width - total) / 2
    local y = 672

    local labels = { "X", "SERI", "O" }
    if mode == "computer" then
        labels = { "KAMU", "SERI", "KOMPUTER" }
    end

    local entries = {
        { label = labels[1], color = COLORS.x,   value = scores.X,    active = currentPlayer == "X" },
        { label = labels[2], color = COLORS.dim, value = scores.draw, active = false },
        { label = labels[3], color = COLORS.o,   value = scores.O,    active = currentPlayer == "O" },
    }

    love.graphics.setFont(fontScore)
    local textY = y + (pillH - fontScore:getHeight()) / 2

    for i, entry in ipairs(entries) do
        local x = x0 + (i - 1) * (pillW + gap)

        love.graphics.setColor(COLORS.panel)
        love.graphics.rectangle("fill", x, y, pillW, pillH, 14, 14)

        if gameState == "playing" and entry.active then
            local c = entry.color
            love.graphics.setColor(c[1], c[2], c[3], 0.55)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x + 1, y + 1, pillW - 2, pillH - 2, 13, 13)
        end

        local label = entry.label
        local value = tostring(entry.value)
        local lw = fontScore:getWidth(label)
        local vw = fontScore:getWidth(value)
        local space = 10
        local startX = x + (pillW - (lw + space + vw)) / 2

        love.graphics.setColor(entry.color)
        love.graphics.print(label, startX, textY)

        love.graphics.setColor(COLORS.text)
        love.graphics.print(value, startX + lw + space, textY)
    end
end

local function drawSegmentRow(x, y, w, gap, h, options, activeValue, enabled, kind)
    love.graphics.setFont(fontSub)
    local textY = y + (h - fontSub:getHeight()) / 2

    for i, option in ipairs(options) do
        local bx = x + (i - 1) * (w + gap)
        local active = (option.value == activeValue)
        local hovered = enabled and hoverButtonKind == kind and hoverButtonIndex == i

        if not enabled then
            love.graphics.setColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 0.45)
        elseif active then
            love.graphics.setColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.20)
        else
            love.graphics.setColor(COLORS.panel)
        end
        love.graphics.rectangle("fill", bx, y, w, h, 12, 12)

        if hovered and not active then
            love.graphics.setColor(1, 1, 1, 0.05)
            love.graphics.rectangle("fill", bx, y, w, h, 12, 12)
        end

        if active and enabled then
            love.graphics.setColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.75)
        elseif enabled then
            love.graphics.setColor(COLORS.panelEdge[1], COLORS.panelEdge[2], COLORS.panelEdge[3], 0.8)
        else
            love.graphics.setColor(COLORS.panelEdge[1], COLORS.panelEdge[2], COLORS.panelEdge[3], 0.3)
        end
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", bx, y, w, h, 12, 12)

        if not enabled then
            love.graphics.setColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3], 0.4)
        elseif active then
            love.graphics.setColor(COLORS.text)
        else
            love.graphics.setColor(COLORS.dim)
        end
        local tw = fontSub:getWidth(option.label)
        love.graphics.print(option.label, bx + (w - tw) / 2, textY)
    end
end

local function drawControls()
    drawSegmentRow(UI.modeX, UI.settingsY, UI.modeW, UI.modeGap, UI.settingsH,
        MODE_OPTIONS, mode, true, "mode")
    drawSegmentRow(UI.levelX, UI.settingsY, UI.levelW, UI.levelGap, UI.settingsH,
        LEVEL_OPTIONS, difficulty, mode == "computer", "level")
end

local function drawHint()
    printCentered("R: ulangi   |   M: ganti mode   |   C: hapus skor   |   Esc: keluar",
        fontSub, 792, COLORS.dim, 0.75)
end

-- ==== Callback LÖVE ====

function love.load()
    love.window.setMode(CONFIG.width, CONFIG.height, {
        resizable = false,
        minwidth = CONFIG.width,
        minheight = CONFIG.height,
    })
    love.window.setTitle("Tic Tac Toe - Love2D")
    love.graphics.setBackgroundColor(COLORS.bgBottom)

    fontTitle = love.graphics.newFont(13)
    fontStatus = love.graphics.newFont(30)
    fontSub = love.graphics.newFont(14)
    fontScore = love.graphics.newFont(18)

    bgMesh = createGradientMesh()

    cursorArrow = love.mouse.getSystemCursor("arrow")
    cursorHand = love.mouse.getSystemCursor("hand")

    resetGame()
end

function love.update(dt)
    time = time + dt

    for _, anim in pairs(anims) do
        if anim.t < 1 then
            anim.t = math.min(1, anim.t + dt * 7)
        end
    end

    if gameState == "win" and winProgress < 1 then
        winProgress = math.min(1, winProgress + dt * 2.2)
    end

    -- Langkah komputer setelah jeda
    if aiTimer then
        aiTimer = aiTimer - dt
        if aiTimer <= 0 then
            aiTimer = nil
            if mode == "computer" and gameState == "playing"
                and currentPlayer == COMPUTER then
                local move = chooseComputerMove()
                if move then
                    play(move[1], move[2])
                end
            end
        end
    end

    -- Deteksi sel / tombol di bawah kursor
    local mx, my = love.mouse.getPosition()
    local bx, by = CONFIG.boardX, CONFIG.boardY
    local bs = CONFIG.cellSize * 3
    local overBoard = mx >= bx and mx < bx + bs and my >= by and my < by + bs

    local row, col
    if overBoard then
        col = math.floor((mx - bx) / CONFIG.cellSize) + 1
        row = math.floor((my - by) / CONFIG.cellSize) + 1
    end

    if not overBoard or not isHumanTurn() or board[row][col] ~= nil then
        row, col = nil, nil
    end
    hoverRow, hoverCol = row, col

    local bk, bi = buttonAt(mx, my)
    hoverButtonKind, hoverButtonIndex = bk, bi

    local boardClickable = overBoard and (
        (gameState == "playing" and row ~= nil) or gameState ~= "playing")
    local wantMode = (bk ~= nil or boardClickable) and "hand" or "arrow"
    if wantMode ~= cursorMode then
        cursorMode = wantMode
        love.mouse.setCursor(wantMode == "hand" and cursorHand or cursorArrow)
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    -- Kontrol mode dan level
    local kind, index = buttonAt(x, y)
    if kind == "mode" then
        setMode(MODE_OPTIONS[index].value)
        return
    elseif kind == "level" then
        setDifficulty(LEVEL_OPTIONS[index].value)
        return
    end

    if gameState ~= "playing" then
        resetGame()
        return
    end

    if not isHumanTurn() then
        return
    end

    local col = math.floor((x - CONFIG.boardX) / CONFIG.cellSize) + 1
    local row = math.floor((y - CONFIG.boardY) / CONFIG.cellSize) + 1
    if row >= 1 and row <= 3 and col >= 1 and col <= 3 then
        play(row, col)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
        return
    end

    if key == "c" then
        scores = allScores[mode]
        scores.X, scores.O, scores.draw = 0, 0, 0
        resetGame()
        return
    end

    if key == "r" or (gameState ~= "playing" and (key == "return" or key == "kpenter" or key == "space")) then
        resetGame()
        return
    end

    if key == "m" then
        setMode(mode == "duo" and "computer" or "duo")
        return
    end

    if key == "l" and mode == "computer" then
        local order = { "easy", "medium", "hard" }
        local index = 1
        for i, value in ipairs(order) do
            if value == difficulty then
                index = i
            end
        end
        setDifficulty(order[index % #order + 1])
        return
    end

    -- Main dengan keyboard: 1-9 (atau numpad)
    local num = tonumber((key:gsub("^kp", "")))
    if num and num >= 1 and num <= 9 and isHumanTurn() then
        local row = math.floor((num - 1) / 3) + 1
        local col = (num - 1) % 3 + 1
        play(row, col)
    end
end

function love.draw()
    drawBackground()
    drawBoard()
    drawTopText()
    drawScores()
    drawControls()
    drawHint()
end
