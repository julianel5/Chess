-- ChessEngine.lua
-- Motor de ajedrez para WoW 3.3.5 (Lua 5.1)

ChessEngine = nil
local M = {}
ChessEngine = M

local WHITE = 1
local BLACK = -1
local HUGE = 999999

M.WHITE = WHITE
M.BLACK = BLACK

M.P, M.N, M.B, M.R, M.Q, M.K = 1, 2, 3, 4, 5, 6
M.PIECE = { P = 1, N = 2, B = 3, R = 4, Q = 5, K = 6 }

M.LETTER = { [1] = "P", [2] = "N", [3] = "B", [4] = "R", [5] = "Q", [6] = "K" }

local VALUE = { 0, 100, 320, 330, 500, 900, 100000 }

local floor = math.floor

local function idx(r, c) return (r - 1) * 8 + c end
local function row(i) return floor((i - 1) / 8) + 1 end
local function col(i) return ((i - 1) % 8) + 1 end
local function onBoard(r, c) return r >= 1 and r <= 8 and c >= 1 and c <= 8 end

M.idx = idx
M.row = row
M.col = col
M.onBoard = onBoard

-- Tablas posicionales (perspectiva blanca; primera fila impresa = fila 8)
local PST = {}
PST[M.P] = {
  0,   0,   0,   0,   0,   0,   0,   0,
  50,  50,  50,  50,  50,  50,  50,  50,
  10,  10,  20,  30,  30,  20,  10,  10,
  5,   5,   10,  25,  25,  10,  5,   5,
  0,   0,   0,   20,  20,  0,   0,   0,
  5,   -5,  -10, 0,   0,   -10, -5,  5,
  5,   10,  10,  -20, -20, 10,  10,  5,
  0,   0,   0,   0,   0,   0,   0,   0,
}
PST[M.N] = {
  -50, -40, -30, -30, -30, -30, -40, -50,
  -40, -20, 0,   0,   0,   0,   -20, -40,
  -30, 0,   10,  15,  15,  10,  0,   -30,
  -30, 5,   15,  20,  20,  15,  5,   -30,
  -30, 0,   15,  20,  20,  15,  0,   -30,
  -30, 5,   10,  15,  15,  10,  5,   -30,
  -40, -20, 0,   5,   5,   0,   -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
}
PST[M.B] = {
  -20, -10, -10, -10, -10, -10, -10, -20,
  -10, 0,   0,   0,   0,   0,   0,   -10,
  -10, 0,   5,   10,  10,  5,   0,   -10,
  -10, 5,   5,   10,  10,  5,   5,   -10,
  -10, 0,   10,  10,  10,  10,  0,   -10,
  -10, 10,  10,  10,  10,  10,  10,  -10,
  -10, 5,   0,   0,   0,   0,   5,   -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
}
PST[M.R] = {
  0,   0,   0,   0,   0,   0,   0,   0,
  5,   10,  10,  10,  10,  10,  10,  5,
  -5,  0,   0,   0,   0,   0,   0,   -5,
  -5,  0,   0,   0,   0,   0,   0,   -5,
  -5,  0,   0,   0,   0,   0,   0,   -5,
  -5,  0,   0,   0,   0,   0,   0,   -5,
  -5,  0,   0,   0,   0,   0,   0,   -5,
  0,   0,   0,   5,   5,   0,   0,   0,
}
PST[M.Q] = {
  -20, -10, -10, -5,  -5,  -10, -10, -20,
  -10, 0,   0,   0,   0,   0,   0,   -10,
  -10, 0,   5,   5,   5,   5,   0,   -10,
  -5,  0,   5,   5,   5,   5,   0,   -5,
  0,   0,   5,   5,   5,   5,   0,   -5,
  -10, 5,   5,   5,   5,   5,   0,   -10,
  -10, 0,   5,   0,   0,   0,   0,   -10,
  -20, -10, -10, -5,  -5,  -10, -10, -20,
}
local KING_MG = {
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20,  20,  0,   0,   0,   0,   20,  20,
  20,  30,  10,  0,   0,   10,  30,  20,
}
local KING_EG = {
  -50, -40, -30, -20, -20, -30, -40, -50,
  -30, -20, -10, 0,   0,   -10, -20, -30,
  -30, -10, 20,  30,  30,  20,  -10, -30,
  -30, -10, 30,  40,  40,  30,  -10, -30,
  -30, -10, 30,  40,  40,  30,  -10, -30,
  -30, -10, 20,  30,  30,  20,  -10, -30,
  -30, -30, 0,   0,   0,   0,   -30, -30,
  -50, -30, -30, -30, -30, -30, -30, -50,
}

local KNIGHT_DIRS = { {1,2}, {2,1}, {2,-1}, {1,-2}, {-1,-2}, {-2,-1}, {-2,1}, {-1,2} }
local KING_DIRS = { {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1} }
local SLIDE_DIRS = {
  [M.B] = { {1,1}, {1,-1}, {-1,1}, {-1,-1} },
  [M.R] = { {1,0}, {-1,0}, {0,1}, {0,-1} },
  [M.Q] = { {1,1}, {1,-1}, {-1,1}, {-1,-1}, {1,0}, {-1,0}, {0,1}, {0,-1} },
}

local function setupBoard()
  local b = {}
  for i = 1, 64 do b[i] = 0 end
  local back = { M.R, M.N, M.B, M.Q, M.K, M.B, M.N, M.R }
  for c = 1, 8 do
    b[idx(1, c)] = back[c]
    b[idx(2, c)] = M.P
    b[idx(7, c)] = -M.P
    b[idx(8, c)] = -back[c]
  end
  return b
end

function M.newPosition()
  return {
    board = setupBoard(),
    turn = WHITE,
    castling = { WK = true, WQ = true, BK = true, BQ = true },
    ep = 0,
    half = 0,
    full = 1,
  }
end

-- ataque sobre una casilla
function M.isAttacked(pos, r, c, byColor)
  local b = pos.board
  -- peones
  local pr = r - byColor
  for _, dc in ipairs({ -1, 1 }) do
    local cc = c + dc
    if onBoard(pr, cc) and b[idx(pr, cc)] == byColor * M.P then return true end
  end
  -- caballos
  for _, d in ipairs(KNIGHT_DIRS) do
    local rr, cc = r + d[1], c + d[2]
    if onBoard(rr, cc) and b[idx(rr, cc)] == byColor * M.N then return true end
  end
  -- rey
  for _, d in ipairs(KING_DIRS) do
    local rr, cc = r + d[1], c + d[2]
    if onBoard(rr, cc) and b[idx(rr, cc)] == byColor * M.K then return true end
  end
  -- deslizantes
  for t, dirs in pairs(SLIDE_DIRS) do
    for _, d in ipairs(dirs) do
      local rr, cc = r + d[1], c + d[2]
      while onBoard(rr, cc) do
        local pc = b[idx(rr, cc)]
        if pc ~= 0 then
          if (pc > 0) == (byColor > 0) and math.abs(pc) == t then return true end
          break
        end
        rr, cc = rr + d[1], cc + d[2]
      end
    end
  end
  return false
end

function M.inCheck(pos, color)
  for i = 1, 64 do
    local pc = pos.board[i]
    if pc ~= 0 and (pc > 0) == (color > 0) and math.abs(pc) == M.K then
      return M.isAttacked(pos, row(i), col(i), -color)
    end
  end
  return false
end

function M.makeMove(pos, m)
  local b = pos.board
  local mine = pos.turn

  m.captured = b[m.to]
  m.oldCastle = { pos.castling.WK, pos.castling.WQ, pos.castling.BK, pos.castling.BQ }
  m.oldEP = pos.ep
  m.oldHalf = pos.half

  b[m.to] = b[m.from]
  b[m.from] = 0

  if m.isEP then
    m.epPawn = b[idx(row(m.from), col(m.to))]
    b[idx(row(m.from), col(m.to))] = 0
  end

  if m.promo ~= nil and m.promo ~= 0 then
    b[m.to] = mine * m.promo
  end

  if m.castle then
    m.rookFrom = idx(row(m.from), m.castle == "K" and 8 or 1)
    m.rookTo = idx(row(m.from), m.castle == "K" and 6 or 4)
    b[m.rookTo] = b[m.rookFrom]
    b[m.rookFrom] = 0
  end

  local cr = pos.castling
  local t = math.abs(m.piece)
  if t == M.K then
    if mine == WHITE then cr.WK, cr.WQ = false, false else cr.BK, cr.BQ = false, false end
  elseif t == M.R then
    local cc = col(m.from)
    if mine == WHITE then
      if cc == 1 then cr.WQ = false elseif cc == 8 then cr.WK = false end
    else
      if cc == 1 then cr.BQ = false elseif cc == 8 then cr.BK = false end
    end
  end
  if math.abs(m.captured) == M.R then
    local rr2, cc2 = row(m.to), col(m.to)
    if rr2 == 1 and cc2 == 1 then cr.WQ = false
    elseif rr2 == 1 and cc2 == 8 then cr.WK = false
    elseif rr2 == 8 and cc2 == 1 then cr.BQ = false
    elseif rr2 == 8 and cc2 == 8 then cr.BK = false end
  end

  pos.ep = 0
  if t == M.P and m.doublePush then
    pos.ep = idx(row(m.from) + mine, col(m.from))
  end

  if t == M.P or m.captured ~= 0 or m.isEP then
    pos.half = 0
  else
    pos.half = pos.half + 1
  end

  local mover = pos.turn
  pos.turn = -mover
  if mover == BLACK then pos.full = pos.full + 1 end

  return m
end

function M.unmakeMove(pos, m)
  local b = pos.board
  local mover = -pos.turn

  b[m.from] = m.piece
  b[m.to] = m.captured

  if m.isEP then
    b[idx(row(m.from), col(m.to))] = m.epPawn
  end
  if m.castle then
    b[m.rookFrom] = b[m.rookTo]
    b[m.rookTo] = 0
  end

  pos.castling.WK, pos.castling.WQ, pos.castling.BK, pos.castling.BQ =
    m.oldCastle[1], m.oldCastle[2], m.oldCastle[3], m.oldCastle[4]
  pos.ep = m.oldEP
  pos.half = m.oldHalf

  if mover == BLACK then pos.full = pos.full - 1 end
  pos.turn = -pos.turn
end

function M.genMoves(pos)
  local moves = {}
  local b = pos.board
  local mine = pos.turn

  local function addMove(from, to, mtype, isEP, isDouble)
    moves[#moves + 1] = {
      from = from, to = to, type = mtype, piece = b[from],
      promo = 0, isEP = isEP or false, doublePush = isDouble or false, castle = nil,
    }
  end

  local function addPawn(from, rr, cc, isEP)
    local promoRow = mine == WHITE and 8 or 1
    if rr == promoRow then
      for _, pt in ipairs({ M.Q, M.R, M.B, M.N }) do
        moves[#moves + 1] = {
          from = from, to = idx(rr, cc), type = pt, piece = b[from],
          promo = pt, isEP = isEP or false, doublePush = false, castle = nil,
        }
      end
    else
      addMove(from, idx(rr, cc), M.P, isEP)
    end
  end

  for i = 1, 64 do
    local pc = b[i]
    if pc ~= 0 and ((pc > 0 and mine == WHITE) or (pc < 0 and mine == BLACK)) then
      local t = math.abs(pc)
      local r, c = row(i), col(i)

      if t == M.P then
        local fr = r + mine
        local j = idx(fr, c)
        if onBoard(fr, c) and b[j] == 0 then
          addPawn(i, fr, c, false)
          local start = (mine == WHITE) and 2 or 7
          if r == start then
            local fr2 = r + 2 * mine
            if onBoard(fr2, c) and b[idx(fr2, c)] == 0 then
              addMove(i, idx(fr2, c), M.P, false, true)
            end
          end
        end
        for _, dc in ipairs({ -1, 1 }) do
          local cc = c + dc
          local rr = r + mine
          if onBoard(rr, cc) then
            local ii = idx(rr, cc)
            local target = b[ii]
            if target ~= 0 then
              if (target > 0) ~= (mine > 0) then
                addPawn(i, rr, cc, false)
              end
            else
              local adjIdx = idx(r, cc)
              if ii == pos.ep and b[adjIdx] == -mine then
                addMove(i, ii, M.P, true)
              end
            end
          end
        end

      elseif t == M.N then
        for _, d in ipairs(KNIGHT_DIRS) do
          local rr, cc = r + d[1], c + d[2]
          if onBoard(rr, cc) then
            local p = b[idx(rr, cc)]
            if p == 0 or (p > 0) ~= (mine > 0) then addMove(i, idx(rr, cc), M.N) end
          end
        end

      elseif t == M.K then
        for _, d in ipairs(KING_DIRS) do
          local rr, cc = r + d[1], c + d[2]
          if onBoard(rr, cc) then
            local p = b[idx(rr, cc)]
            if p == 0 or (p > 0) ~= (mine > 0) then addMove(i, idx(rr, cc), M.K) end
          end
        end

      else
        for _, d in ipairs(SLIDE_DIRS[t]) do
          local rr, cc = r + d[1], c + d[2]
          while onBoard(rr, cc) do
            local p = b[idx(rr, cc)]
            if p == 0 then
              addMove(i, idx(rr, cc), t)
            else
              if (p > 0) ~= (mine > 0) then addMove(i, idx(rr, cc), t) end
              break
            end
            rr, cc = rr + d[1], cc + d[2]
          end
        end
      end
    end
  end

  -- enroque
  local kRow = (mine == WHITE) and 1 or 8
  local kCol = 5
  local ksq = idx(kRow, kCol)
  local kingPresent = math.abs(b[ksq]) == M.K and (b[ksq] > 0) == (mine > 0)

  if kingPresent then
    local kingside = (mine == WHITE and pos.castling.WK) or (mine == BLACK and pos.castling.BK)
    if kingside then
      if b[idx(kRow, 6)] == 0 and b[idx(kRow, 7)] == 0 and
         b[idx(kRow, 8)] == mine * M.R then
        if not M.isAttacked(pos, kRow, 5, -mine) and
           not M.isAttacked(pos, kRow, 6, -mine) and
           not M.isAttacked(pos, kRow, 7, -mine) then
          moves[#moves + 1] = {
            from = ksq, to = idx(kRow, 7), type = M.K, piece = b[ksq],
            promo = 0, isEP = false, doublePush = false, castle = "K",
          }
        end
      end
    end
    local queenside = (mine == WHITE and pos.castling.WQ) or (mine == BLACK and pos.castling.BQ)
    if queenside then
      if b[idx(kRow, 4)] == 0 and b[idx(kRow, 3)] == 0 and b[idx(kRow, 2)] == 0 and
         b[idx(kRow, 1)] == mine * M.R then
        if not M.isAttacked(pos, kRow, 5, -mine) and
           not M.isAttacked(pos, kRow, 4, -mine) and
           not M.isAttacked(pos, kRow, 3, -mine) then
          moves[#moves + 1] = {
            from = ksq, to = idx(kRow, 3), type = M.K, piece = b[ksq],
            promo = 0, isEP = false, doublePush = false, castle = "Q",
          }
        end
      end
    end
  end

  -- filtrar jugadas ilegales (dejan al rey en jaque)
  local legal = {}
  for _, m in ipairs(moves) do
    M.makeMove(pos, m)
    if not M.inCheck(pos, mine) then
      legal[#legal + 1] = m
    end
    M.unmakeMove(pos, m)
  end
  return legal
end

function M.positionKey(pos)
  local b = pos.board
  local t = {}
  for i = 1, 64 do t[i] = tostring(b[i]) end
  local s = table.concat(t, ",")
  local cr = pos.castling
  s = s .. "|" .. tostring(pos.turn)
  s = s .. ((cr.WK and "K") or "") .. ((cr.WQ and "Q") or "")
  s = s .. ((cr.BK and "k") or "") .. ((cr.BQ and "q") or "")
  s = s .. "|" .. tostring(pos.ep)
  return s
end

function M.insufficientMaterial(pos)
  local b = pos.board
  local pieces = {}
  for i = 1, 64 do if b[i] ~= 0 then pieces[#pieces + 1] = b[i] end end
  if #pieces <= 2 then return true end

  local minors, bishops = 0, {}
  for _, pc in ipairs(pieces) do
    local t = math.abs(pc)
    if t == M.N or t == M.B then
      minors = minors + 1
      if t == M.B then bishops[#bishops + 1] = pc end
    end
  end

  if #pieces == 3 and minors == 1 then return true end
  if #pieces == 4 and minors == 2 then
    if #bishops == 2 then
      -- encontrar las casillas
      local sqs = { -1, -1 }
      for i = 1, 64 do
        local pc = b[i]
        if pc ~= 0 and math.abs(pc) == M.B then
          local parity = (row(i) + col(i)) % 2
          local idxB = (pc > 0) and 1 or 2
          sqs[idxB] = parity
        end
      end
      if sqs[1] == sqs[2] then return true end
    end
  end
  return false
end

function M.status(pos, repCounts)
  local moves = M.genMoves(pos)
  if #moves == 0 then
    return { result = M.inCheck(pos, pos.turn) and "mate" or "stalemate", loser = pos.turn }
  end
  if pos.half >= 100 then return { result = "draw50" } end
  if M.insufficientMaterial(pos) then return { result = "drawMaterial" } end
  local k = M.positionKey(pos)
  if repCounts and repCounts[k] and repCounts[k] >= 3 then return { result = "drawRep" } end
  return { checked = M.inCheck(pos, pos.turn) }
end

-- ---- evaluacion ----
local function evaluate(pos, viewpoint)
  local b = pos.board
  local score = 0
  local heavy = 0
  for i = 1, 64 do
    local pc = b[i]
    if pc ~= 0 then
      local t = math.abs(pc)
      if t ~= M.K and t ~= M.P then heavy = heavy + 1 end
    end
  end
  local phase = math.min(1, heavy / 3)
  for i = 1, 64 do
    local pc = b[i]
    if pc ~= 0 then
      local t = math.abs(pc)
      local r, c = row(i), col(i)
      local pstRow = (pc > 0) and (9 - r) or r
      local pi = (pstRow - 1) * 8 + c
      local pst = 0
      if t == M.K then
        pst = KING_MG[pi] * (1 - phase) + KING_EG[pi] * phase
      else
        pst = PST[t][pi]
      end
      local sign = (pc > 0) and 1 or -1
      score = score + sign * (VALUE[t] + pst)
    end
  end
  if viewpoint == WHITE then return score end
  return -score
end

-- orden de jugadas
local function moveScore(pos, m)
  local val = 0
  if m.castle then val = val + 1200 end
  if m.promo ~= 0 then val = val + 900 + m.promo * 150 end
  local capt
  if m.isEP then
    capt = M.P
  else
    capt = pos.board[m.to]
  end
  if capt ~= 0 then
    local ct = math.abs(capt)
    val = val + 1000 + VALUE[ct] * 10 - floor(VALUE[math.abs(m.piece)] / 10)
  end
  return val
end

local function orderMoves(pos, moves)
  local scored = {}
  for _, m in ipairs(moves) do
    scored[#scored + 1] = { m, moveScore(pos, m) }
  end
  table.sort(scored, function(a, b) return a[2] > b[2] end)
  local out = {}
  for _, s in ipairs(scored) do out[#out + 1] = s[1] end
  return out
end

function M.quiesce(pos, alpha, beta, viewpoint, ply)
  if ply > 8 then return evaluate(pos, viewpoint) end
  local stand = evaluate(pos, viewpoint)
  if stand >= beta then return beta end
  if stand > alpha then alpha = stand end

  local moves = M.genMoves(pos)
  for _, m in ipairs(moves) do
    local capt = pos.board[m.to]
    if m.isEP then capt = M.P end
    if capt ~= 0 or m.promo ~= 0 then
      M.makeMove(pos, m)
      local val = -M.quiesce(pos, -beta, -alpha, -viewpoint, ply + 1)
      M.unmakeMove(pos, m)
      if val >= beta then return beta end
      if val > alpha then alpha = val end
    end
  end
  return alpha
end

local function negaMax(pos, depth, alpha, beta, viewpoint)
  if depth <= 0 then
    return M.quiesce(pos, alpha, beta, viewpoint, 0)
  end
  local moves = M.genMoves(pos)
  if #moves == 0 then
    if M.inCheck(pos, pos.turn) then return -1000000 end
    return 0
  end
  moves = orderMoves(pos, moves)
  for _, m in ipairs(moves) do
    M.makeMove(pos, m)
    local val = -negaMax(pos, depth - 1, -beta, -alpha, -viewpoint)
    M.unmakeMove(pos, m)
    if val >= beta then return beta end
    if val > alpha then alpha = val end
  end
  return alpha
end

-- depth = profundidad de la IA, noise = margen en cps para variar jugadas
function M.findBestMove(pos, depth, noise)
  local moves = M.genMoves(pos)
  if #moves == 0 then return nil end
  local myColor = pos.turn
  moves = orderMoves(pos, moves)

  local beta = HUGE
  local alpha = -HUGE
  local candidates = {}

  for _, m in ipairs(moves) do
    M.makeMove(pos, m)
    local val = -negaMax(pos, depth - 1, -beta, -alpha, myColor)
    M.unmakeMove(pos, m)
    if val > alpha then alpha = val end
    candidates[#candidates + 1] = { m, val }
  end

  local bestScore = -HUGE
  for _, cand in ipairs(candidates) do
    if cand[2] > bestScore then bestScore = cand[2] end
  end

  local pool = {}
  local limit = noise or 0
  for _, cand in ipairs(candidates) do
    if cand[2] >= bestScore - limit then
      pool[#pool + 1] = cand[1]
    end
  end
  -- variar jugadas entre las mejores
  local random = math.random
  return pool[random(#pool)]
end