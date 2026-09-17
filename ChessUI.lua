-- ChessUI.lua
-- Interfaz de ajedrez para WoW 3.3.5

ChessUI = nil
local UI = {}
ChessUI = UI

local Engine = ChessEngine
local Net = ChessNet
local WHITE = Engine.WHITE
local BLACK = Engine.BLACK

local SQ = 44
local BOARD_SIZE = 8 * SQ + 8
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

local DIFFICULTIES = {
  [1] = { name = "Facil",   depth = 1, noise = 90 },
  [2] = { name = "Medio",   depth = 2, noise = 30 },
  [3] = { name = "Dificil", depth = 3, noise = 0 },
}

local START_COUNTS = { [Engine.P] = 8, [Engine.N] = 2, [Engine.B] = 2, [Engine.R] = 2, [Engine.Q] = 1 }

-- estado de la partida (por tablero: el de la maquina y el online son
-- independientes y conviven sin pisarse)
local difficulty = 2

local function newState()
  return {
    pos = nil,
    gameMoves = {},
    repCounts = {},
    selected = nil,
    candidates = {},
    flipped = false,
    gameOver = false,
    humanTurn = true,
    thinking = false,
    pendingPromo = nil,
    hintMove = nil,
    lastMoves = {},
    statusMsg = nil,
    subMsg = "",
    subKind = nil,
  }
end

local aiState = newState()
local netState = newState()

-- estado online
local online = false
local netGid = ""
local netColor = WHITE
local netOpponent = ""
local netAwaitingAccept = false
local netDrawSent = false
local pendingInvGid, pendingInvSeed, pendingInvOpp
local pendingRematchGid
local netInvSeed
local netIncoming = {}
local INV_TTL = 180
local invPopShown = 0
local invPopShownGid = nil

local SOUNDS = {
  move = "Interface\\AddOns\\Chess\\sounds\\move.wav",
  capture = "Interface\\AddOns\\Chess\\sounds\\capture.wav",
  check = "Interface\\AddOns\\Chess\\sounds\\check.wav",
}

-- ---- temporizador simple ----
-- Soporta varias tareas simultaneas: cada schedule() registra una tarea
-- independiente y todas arrancan a la vez sin cancelarse entre si.
local timerFrame = CreateFrame("Frame", nil, UIParent)
timerFrame:Hide()
local timers = {}
local timerRunning = false

local function cancelTimer()
  wipe(timers)
  timerRunning = false
  timerFrame:SetScript("OnUpdate", nil)
  timerFrame:Hide()
end

local function schedule(sec, fn)
  timers[#timers + 1] = { time = 0, sec = sec, fn = fn }
  if not timerRunning then
    timerRunning = true
    timerFrame:SetScript("OnUpdate", function(_, elapsed)
      for i = #timers, 1, -1 do
        local t = timers[i]
        if t then
          t.time = t.time + elapsed
          if t.time >= t.sec then
            table.remove(timers, i)
            local f = t.fn
            if f then f() end
          end
        end
      end
      if #timers == 0 then cancelTimer() end
    end)
    timerFrame:Show()
  end
end

local function playSoundWav(m)
  local file = SOUNDS.move
  if m.isEP or m.captured ~= 0 then
    file = SOUNDS.capture
  end
  pcall(PlaySoundFile, file)
end

-- ---- mapping de coordenadas ----
local function logicIdx(B, dr, dc)
  if B.state.flipped then
    return (dr - 1) * 8 + (9 - dc)
  end
  return (8 - dr) * 8 + dc
end

local function displayPos(B, sq)
  local r = Engine.row(sq)
  local c = Engine.col(sq)
  if B.state.flipped then return r, 9 - c end
  return 9 - r, c
end

local function sqName(sq)
  return string.char(96 + Engine.col(sq)) .. Engine.row(sq)
end

-- ---- texturas de piezas ----
local TNAME = { [Engine.K] = "K", [Engine.Q] = "Q", [Engine.R] = "R", [Engine.B] = "B", [Engine.N] = "N", [Engine.P] = "P" }
local PIECE_TEX_DIR = "Interface\\AddOns\\Chess\\textures"
local PIECE_H = { [Engine.K] = 42, [Engine.Q] = 40, [Engine.R] = 34, [Engine.B] = 35, [Engine.N] = 36, [Engine.P] = 30 }

local function texFor(pc)
  local t = math.abs(pc)
  local letter = TNAME[t] or "P"
  local color = (pc > 0) and "w" or "b"
  return PIECE_TEX_DIR .. "\\" .. color .. letter .. ".tga"
end

-- predeclaracion de funciones (asignadas mas abajo)
local paintSquare, clearOverlays, showLastMove, showSelection, refreshBoard
local updateCaptured, resultMessage, updateStatusText, setGameOver, noteRep
local selectPiece, executeHumanMove, afterHumanMove, onSquareClick, aiThink
local showHint, newGame, doUndo, setDifficulty
local showPromotion, hidePromotion, pickPromotion
local netSetup, startOnlineGame, endOnlineGame, netChallenge, netAcceptInvite
local netApplyMove, netOnResign, netOnDraw, netOnRematch, netResign, netOfferDraw
local netOfferRematch, netRematch, netShowMsg, setOnlineButtons, netResultText
local updateOnlineView, invListRefresh, invListPopPopup, acceptEntry, declineEntry
local setTab
local activeTab = "ai"
local activeBoard

-- ---- creacion de frames ----
local F = CreateFrame("Frame", "ChessFrame", UIParent)
F:SetSize(404, 590)
F:SetPoint("CENTER")
F:SetMovable(true)
F:SetClampedToScreen(true)
F:EnableMouse(true)
F:SetFrameStrata("MEDIUM")
F:SetBackdrop({
  bgFile = WHITE8,
  edgeFile = WHITE8,
  tile = false,
  tileSize = 0,
  edgeSize = 2,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
F:SetBackdropColor(0.10, 0.10, 0.14, 0.96)
F:SetBackdropBorderColor(1.0, 0.84, 0.55, 1)
F:RegisterForDrag("LeftButton")
F:SetScript("OnDragStart", function(self) self:StartMoving() end)
F:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

local titleFS = F:CreateFontString(nil, "ARTWORK", "GameFontNormal")
titleFS:SetPoint("TOP", F, "TOP", 0, -4)
titleFS:SetTextColor(0.95, 0.93, 0.90)
titleFS:SetText("Ajedrez contra la maquina")

local closeBtn = CreateFrame("Button", "ChessCloseButton", F, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", F, "TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() F:Hide() end)

local function makeFlatBtn(name, parent, w, h, text)
  local b = CreateFrame("Button", name, parent)
  b:SetSize(w, h)
  b:EnableMouse(true)
  b:RegisterForClicks("LeftButtonUp")
  b:SetNormalTexture(WHITE8)
  b:GetNormalTexture():SetVertexColor(0.13, 0.14, 0.19, 1)
  b:SetHighlightTexture(WHITE8)
  b:GetHighlightTexture():SetVertexColor(0.28, 0.32, 0.42, 1)
  b:SetBackdrop({
    bgFile = WHITE8,
    edgeFile = WHITE8,
    tile = false,
    tileSize = 0,
    edgeSize = 1,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b:SetBackdropColor(0.13, 0.14, 0.19, 1)
  b:SetText(text)
  b:SetNormalFontObject(GameFontNormal)
  b:SetHighlightFontObject(GameFontNormal)
  return b
end

local tabAI = makeFlatBtn("ChessTabAIButton", F, 120, 24, "Vs Maquina")
tabAI:SetPoint("RIGHT", F, "TOP", -3, -30)

local tabNet = makeFlatBtn("ChessTabNetButton", F, 104, 24, "Online")
tabNet:SetSize(104, 24)
tabNet:SetPoint("LEFT", F, "TOP", 3, -30)

local function paintTab(btn, active)
  if active then
    btn:GetNormalTexture():SetVertexColor(0.24, 0.30, 0.42, 1)
    btn:SetBackdropBorderColor(1.0, 0.85, 0.35, 1)
  else
    btn:GetNormalTexture():SetVertexColor(0.13, 0.14, 0.19, 1)
    btn:SetBackdropBorderColor(0.35, 0.35, 0.42, 1)
  end
end

local function paintTabs()
  paintTab(tabAI, activeTab == "ai")
  paintTab(tabNet, activeTab ~= "ai")
end

local function paintEnabled(b, on)
  if on then
    b:GetNormalTexture():SetVertexColor(0.13, 0.14, 0.19, 1)
    b:SetBackdropBorderColor(0.35, 0.35, 0.42, 1)
  else
    b:GetNormalTexture():SetVertexColor(0.08, 0.08, 0.11, 1)
    b:SetBackdropBorderColor(0.16, 0.16, 0.22, 1)
  end
end

local capturedFS = F:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
capturedFS:SetPoint("TOP", F, "TOP", 0, -58)
capturedFS:SetWidth(380)
capturedFS:SetHeight(14)
capturedFS:SetJustifyH("CENTER")

-- fábrica de tableros: cada uno con su propio frame y sus propias casillas
local function makeBoard(name)
  local B = {}
  B.state = nil
  B.frame = CreateFrame("Frame", name, F)
  B.frame:SetPoint("TOP", F, "TOP", 0, -76)
  B.frame:SetSize(BOARD_SIZE, BOARD_SIZE)
  B.frame:SetBackdrop({
    bgFile = WHITE8,
    edgeFile = WHITE8,
    tile = false,
    tileSize = 0,
    edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  B.frame:SetBackdropColor(0.30, 0.20, 0.12, 1)
  B.frame:SetBackdropBorderColor(0.6, 0.45, 0.28, 1)

  B.squares = {}
  for dr = 1, 8 do
    B.squares[dr] = {}
    for dc = 1, 8 do
      local btn = CreateFrame("Button", nil, B.frame)
      btn:SetSize(SQ, SQ)
      btn:SetPoint("TOPLEFT", B.frame, "TOPLEFT", 4 + (dc - 1) * SQ, -(4 + (dr - 1) * SQ))
      btn:SetNormalTexture(WHITE8)
      local nt = btn:GetNormalTexture()
      if (dr + dc) % 2 == 1 then
        nt:SetVertexColor(0.62, 0.41, 0.25, 1)
      else
        nt:SetVertexColor(0.92, 0.85, 0.68, 1)
      end

      local piece = btn:CreateTexture(nil, "OVERLAY")
      piece:SetPoint("CENTER", btn, "CENTER", 0, 0)
      piece:Hide()

      local sel = btn:CreateTexture(nil, "OVERLAY")
      sel:SetTexture(WHITE8)
      sel:SetVertexColor(1, 1, 0.2, 0.45)
      sel:SetAllPoints(btn)
      sel:Hide()

      local legal = btn:CreateTexture(nil, "OVERLAY")
      legal:SetTexture(WHITE8)
      legal:SetVertexColor(0.2, 1, 0.3, 0.4)
      legal:SetAllPoints(btn)
      legal:Hide()

      local last = btn:CreateTexture(nil, "OVERLAY")
      last:SetTexture(WHITE8)
      last:SetVertexColor(0.4, 0.7, 1, 0.45)
      last:SetAllPoints(btn)
      last:Hide()

      local hint = btn:CreateTexture(nil, "OVERLAY")
      hint:SetTexture(WHITE8)
      hint:SetVertexColor(1, 0.4, 1, 0.5)
      hint:SetAllPoints(btn)
      hint:Hide()

      btn:SetScript("OnClick", function()
        onSquareClick(B, logicIdx(B, dr, dc))
      end)

      B.squares[dr][dc] = {
        btn = btn, piece = piece,
        sel = sel, legal = legal, last = last, hint = hint,
      }
    end
  end
  B.frame:Hide()
  return B
end

local aiBoard = makeBoard("ChessBoardAI")
local netBoard = makeBoard("ChessBoardNet")
aiBoard.state = aiState
netBoard.state = netState

local function activeBoard()
  return (activeTab == "ai") and aiBoard or netBoard
end

-- que piezas son del jugador humano: en el modo maquina siempre las
-- blancas; en el online, las del color de la sesion. Recibe el tablero
-- para que los dos juegos nunca se crucen.
local function isMyPiece(B, pc)
  if pc == 0 then return false end
  if B == netBoard then
    if not online then return false end
    return (pc > 0) == (netColor > 0)
  end
  return pc > 0
end

-- estado / texto
local statusFS = F:CreateFontString(nil, "ARTWORK", "GameFontNormal")
statusFS:SetPoint("TOP", aiBoard.frame, "BOTTOM", 0, -6)
statusFS:SetWidth(380)
statusFS:SetHeight(20)
statusFS:SetJustifyH("CENTER")

local subFS = F:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
subFS:SetPoint("TOP", statusFS, "BOTTOM", 0, -2)
subFS:SetWidth(380)
subFS:SetHeight(22)
subFS:SetJustifyH("CENTER")

-- textos por tablero: cada partida recuerda el suyo y solo se pinta en
-- pantalla si su tablero es el visible (evita que se crucen el modo
-- maquina y el online)
local function setStatus(B, txt)
  B.state.statusMsg = txt
  if B ~= activeBoard() then return end
  statusFS:SetText(txt)
end

local function setSub(B, txt, kind)
  B.state.subMsg = txt or ""
  B.state.subKind = kind or "info"
  if B ~= activeBoard() then return end
  subFS:SetText(txt or "")
end

-- hileras de botones
local row1 = CreateFrame("Frame", nil, F)
row1:SetPoint("TOP", subFS, "BOTTOM", 0, -4)
row1:SetSize(376, 24)

local newBtn = makeFlatBtn("ChessNewButton", row1, 112, 22, "Nueva partida")
newBtn:SetPoint("LEFT", row1, "LEFT", 6, 0)
newBtn:SetScript("OnClick", function() newGame() end)

local undoBtn = makeFlatBtn("ChessUndoButton", row1, 112, 22, "Deshacer")
undoBtn:SetPoint("CENTER", row1, "CENTER", 0, 0)
undoBtn:SetScript("OnClick", function() doUndo() end)

local hintBtn = makeFlatBtn("ChessHintButton", row1, 112, 22, "Pista")
hintBtn:SetPoint("RIGHT", row1, "RIGHT", -6, 0)
hintBtn:SetScript("OnClick", function() showHint(aiBoard) end)

local row2 = CreateFrame("Frame", nil, F)
row2:SetPoint("TOP", row1, "BOTTOM", 0, -2)
row2:SetSize(376, 30)

local diffDD = CreateFrame("Frame", "ChessDifficultyDropDown", row2, "UIDropDownMenuTemplate")
diffDD:SetPoint("LEFT", row2, "LEFT", 4, 0)
UIDropDownMenu_SetWidth(diffDD, 120)
UIDropDownMenu_Initialize(diffDD, function(self, level)
  if level ~= 1 then return end
  for i, diff in ipairs(DIFFICULTIES) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = diff.name
    info.checked = (difficulty == i)
    info.func = function() setDifficulty(i) end
    UIDropDownMenu_AddButton(info, level)
  end
end)
diffDD:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" then
    ToggleDropDownMenu(1, nil, self, self:GetName(), 0, 0)
  end
end)

local flipBtn = makeFlatBtn("ChessFlipButton", row2, 112, 22, "Girar tablero")
flipBtn:SetPoint("RIGHT", row2, "RIGHT", -6, 0)
flipBtn:SetScript("OnClick", function()
  aiState.flipped = not aiState.flipped
  refreshBoard(aiBoard)
  showSelection(aiBoard)
end)

local row3 = CreateFrame("Frame", nil, F)
row3:SetPoint("TOP", row2, "BOTTOM", 0, -2)
row3:SetSize(376, 24)

local onlineBtn = makeFlatBtn("ChessOnlineButton", row3, 116, 22, "Retar")
onlineBtn:SetPoint("LEFT", row3, "LEFT", 6, 0)
onlineBtn:SetScript("OnClick", function()
  if online then
    print("Ya estas en una partida online. Usa Rendirse o Salir para salir.")
    return
  end
  StaticPopup_Show("CHESS_CHALLENGE")
end)

local exitBtn = makeFlatBtn("ChessExitButton", row3, 52, 22, "Salir")
exitBtn:SetPoint("LEFT", row3, "LEFT", 6, 0)
exitBtn:SetScript("OnClick", function()
  netExit()
end)
exitBtn:Hide()

local resignBtn = makeFlatBtn("ChessResignButton", row3, 64, 22, "Rendirse")
resignBtn:SetPoint("LEFT", exitBtn, "RIGHT", 8, 0)
resignBtn:SetScript("OnClick", function() netResign() end)

local drawBtn = makeFlatBtn("ChessDrawButton", row3, 56, 22, "Tablas")
drawBtn:SetPoint("LEFT", resignBtn, "RIGHT", 8, 0)
drawBtn:SetScript("OnClick", function() netOfferDraw() end)

local rematchBtn = makeFlatBtn("ChessRematchButton", row3, 64, 22, "Revancha")
rematchBtn:SetPoint("LEFT", drawBtn, "RIGHT", 8, 0)
rematchBtn:SetScript("OnClick", function() netOfferRematch() end)

local netFlipBtn = makeFlatBtn("ChessNetFlipButton", row3, 96, 22, "Girar tablero")
netFlipBtn:SetPoint("RIGHT", row3, "RIGHT", -6, 0)
netFlipBtn:SetScript("OnClick", function()
  netState.flipped = not netState.flipped
  refreshBoard(netBoard)
  showSelection(netBoard)
end)
netFlipBtn:Hide()

-- panel "retos recibidos" (vista online sin partida)
local invPanel = CreateFrame("Frame", "ChessInvPanel", F)
invPanel:SetSize(376, 152)
invPanel:SetPoint("TOP", F, "TOP", 0, -62)
invPanel:SetBackdrop({
  bgFile = WHITE8,
  edgeFile = WHITE8,
  tile = false,
  tileSize = 0,
  edgeSize = 1,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
invPanel:SetBackdropColor(0.10, 0.10, 0.14, 0.96)
invPanel:SetBackdropBorderColor(0.35, 0.35, 0.42, 1)
invPanel:Hide()

local invTitle = invPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
invTitle:SetPoint("TOP", invPanel, "TOP", 0, -6)
invTitle:SetText("Retos recibidos")

local invEmpty = invPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
invEmpty:SetPoint("TOP", invPanel, "TOP", 0, -46)
invEmpty:SetText("No hay retos pendientes. Reta a alguien con 'Retar'.")
invEmpty:SetTextColor(0.6, 0.6, 0.68, 1)

local invSlots = {}
for i = 1, 4 do
  local row = CreateFrame("Frame", nil, invPanel)
  row:SetSize(360, 26)
  row:SetPoint("TOP", invPanel, "TOP", 0, -34 - (i - 1) * 28)
  local nm = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  nm:SetPoint("LEFT", row, "LEFT", 10, 0)
  nm:SetWidth(220)
  nm:SetJustifyH("LEFT")
  local acc = makeFlatBtn("ChessInvAccept" .. i, row, 56, 20, "Aceptar")
  acc:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  local dec = makeFlatBtn("ChessInvDecline" .. i, row, 64, 20, "Rechazar")
  dec:SetPoint("RIGHT", acc, "LEFT", -6, 0)
  local idx = i
  acc:SetScript("OnClick", function()
    local e = netIncoming[idx]
    if e then acceptEntry(e) end
  end)
  dec:SetScript("OnClick", function()
    local e = netIncoming[idx]
    if e then declineEntry(e) end
  end)
  invSlots[i] = { row = row, nm = nm }
end

function setTab(tab)
  activeTab = tab
  paintTabs()
  if tab == "ai" then
    row1:Show()
    row2:Show()
    row3:Hide()
    titleFS:SetText("Ajedrez - Vs Maquina")
    statusFS:SetTextColor(0.90, 0.88, 1.0)
    netBoard.frame:Hide()
    aiBoard.frame:Show()
  else
    row1:Hide()
    row2:Hide()
    local colorName = (netColor == WHITE) and "Blancas" or "Negras"
    if online then
      titleFS:SetText("Ajedrez - Online  (Eres las " .. colorName .. ")")
    else
      titleFS:SetText("Ajedrez - Online")
    end
    statusFS:SetTextColor(0.30, 1.0, 0.40)
    aiBoard.frame:Hide()
    netBoard.frame:Show()
  end
  updateOnlineView()
  setOnlineButtons()
  local B = (tab == "ai") and aiBoard or netBoard
  if B.state.statusMsg then
    statusFS:SetText(B.state.statusMsg)
  end
  subFS:SetText(B.state.subMsg or "")
  if B.state.pos then
    updateCaptured(B)
  end
end

tabAI:SetScript("OnClick", function()
  setTab("ai")
end)

tabNet:SetScript("OnClick", function()
  setTab("online")
end)

StaticPopupDialogs["CHESS_CHALLENGE"] = {
  text = "Nombre del rival (escribe su nombre; anade -Reino si esta en otro).",
  button1 = "Retar",
  button2 = "Cancelar",
  hasEditBox = true,
  timeout = 0,
  whileDead = true,
  OnShow = function(self)
    self.editBox:SetText("")
    self.editBox:SetFocus()
  end,
  EditBoxOnEnterPressed = function(self)
    local parent = self:GetParent()
    StaticPopup_OnClick(parent, 1)
  end,
  OnAccept = function(self)
    local name = (self.editBox and self.editBox:GetText()) or ""
    name = name:gsub("^%s*(.-)%s*$", "%1")
    if name ~= "" then
      netChallenge(name)
    end
  end,
  OnCancel = function() end,
}

StaticPopupDialogs["CHESS_INVITE"] = {
  text = "",
  button1 = "Aceptar",
  button2 = "Rechazar",
  timeout = 0,
  whileDead = true,
  OnAccept = function()
    netAcceptInvite(true)
  end,
  OnAlt = function()
    if GetTime() - invPopShown >= 1 then
      netAcceptInvite(false)
    end
  end,
  OnCancel = function()
    -- solo rechaza si el popup lleva un instante visible: un reemplazo
    -- involuntario del popup (otro dialogo de WoW) dispara OnCancel justo
    -- al aparecer y causaria un rechazo automatico del reto.
    if GetTime() - invPopShown >= 1 then
      netAcceptInvite(false)
    end
  end,
}

StaticPopupDialogs["CHESS_DRAW"] = {
  text = "",
  button1 = "Aceptar",
  button2 = "Rechazar",
  timeout = 0,
  whileDead = true,
  OnAccept = function()
    netOnDraw("acc")
  end,
  OnCancel = function()
    netOnDraw("dec")
  end,
}

StaticPopupDialogs["CHESS_REMATCH"] = {
  text = "",
  button1 = "Aceptar",
  button2 = "Declinar",
  timeout = 0,
  whileDead = true,
  OnAccept = function()
    netOnRematch("acc")
  end,
  OnCancel = function()
    netOnRematch("dec")
  end,
}

-- selector de promocion
local promoBoard
local promFrame = CreateFrame("Frame", "ChessPromotionFrame", UIParent)
promFrame:SetSize(228, 74)
promFrame:SetPoint("CENTER", F, "CENTER", 0, 0)
promFrame:SetFrameStrata("DIALOG")
promFrame:SetBackdrop({
  bgFile = WHITE8,
  edgeFile = WHITE8,
  tile = false,
  tileSize = 0,
  edgeSize = 2,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
promFrame:SetBackdropColor(0.08, 0.08, 0.12, 0.98)
promFrame:SetBackdropBorderColor(1.0, 0.84, 0.55, 1)
promFrame:Hide()

local promTitle = promFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
promTitle:SetPoint("TOP", promFrame, "TOP", 0, -6)
promTitle:SetText("Elige la promocion")

local promoButtons = {}
local function makePromoItem(t, x)
  local btn = makeFlatBtn("ChessPromo" .. t .. "Button", promFrame, 46, 28, "")
  btn:SetPoint("TOP", promFrame, "TOP", -40 + (x - 1) * 26, -30)
  local icon = btn:CreateTexture(nil, "OVERLAY")
  icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
  icon:SetSize(22, 22)
  icon:SetTexture(texFor(t))
  btn:SetScript("OnClick", function()
    pickPromotion(t)
  end)
  promoButtons[t] = btn
end
makePromoItem(Engine.Q, 1)
makePromoItem(Engine.R, 2)
makePromoItem(Engine.B, 3)
makePromoItem(Engine.N, 4)

function showPromotion(B)
  promFrame:Show()
end

function hidePromotion(B)
  promFrame:Hide()
  B.state.pendingPromo = nil
end

function pickPromotion(t)
  local B = promoBoard
  local chosen
  if B.state.pendingPromo then
    for _, m in ipairs(B.state.pendingPromo) do
      if m.promo == t then chosen = m end
    end
  end
  B.state.pendingPromo = nil
  hidePromotion(B)
  if chosen then
    executeHumanMove(B, chosen)
  end
end

-- ---- pintado ----
function paintSquare(B, dr, dc)
  local sq = logicIdx(B, dr, dc)
  local s = B.state
  local pc = s.pos.board[sq]
  local cell = B.squares[dr][dc]

  cell.sel:Hide()
  cell.legal:Hide()
  cell.hint:Hide()

  local piece = cell.piece
  if pc == 0 then
    piece:Hide()
  else
    local t = math.abs(pc)
    local size = PIECE_H[t] or 34
    piece:SetTexture(texFor(pc))
    piece:SetSize(size, size)
    piece:Show()
  end
end

function clearOverlays(B)
  for dr = 1, 8 do
    for dc = 1, 8 do
      local cell = B.squares[dr][dc]
      cell.sel:Hide()
      cell.legal:Hide()
      cell.hint:Hide()
    end
  end
end

function showSelection(B)
  clearOverlays(B)
  local s = B.state
  if not s.pos then return end
  showLastMove(B)
  if s.selected then
    local dr, dc = displayPos(B, s.selected)
    B.squares[dr][dc].sel:Show()
  end
  for _, m in ipairs(s.candidates) do
    local dr, dc = displayPos(B, m.to)
    B.squares[dr][dc].legal:Show()
  end
end

function showLastMove(B)
  for _, sq in ipairs(B.state.lastMoves) do
    local dr, dc = displayPos(B, sq)
    if B.squares[dr][dc] then
      B.squares[dr][dc].last:Show()
    end
  end
end

function refreshBoard(B)
  local s = B.state
  if not s.pos then return end
  for dr = 1, 8 do
    for dc = 1, 8 do
      local cell = B.squares[dr][dc]
      cell.last:Hide()
      cell.hint:Hide()
    end
  end
  for dr = 1, 8 do
    for dc = 1, 8 do
      paintSquare(B, dr, dc)
    end
  end
  showLastMove(B)
  if s.hintMove then
    local dr1, dc1 = displayPos(B, s.hintMove.from)
    local dr2, dc2 = displayPos(B, s.hintMove.to)
    B.squares[dr1][dc1].hint:Show()
    B.squares[dr2][dc2].hint:Show()
  end
  updateCaptured(B)
end

-- ---- textos ----
function updateCaptured(B)
  if B ~= activeBoard() then return end
  local s = B.state
  if not s.pos then return end
  local function countOn(color)
    local c = {}
    for i = 1, 64 do
      local pc = s.pos.board[i]
      if pc ~= 0 and ((pc > 0 and color == WHITE) or (pc < 0 and color == BLACK)) then
        local t = math.abs(pc)
        c[t] = (c[t] or 0) + 1
      end
    end
    return c
  end
  local function captureString(color)
    local on = countOn(color)
    local parts = {}
    for t = Engine.Q, 1, -1 do
      local missing = START_COUNTS[t] - (on[t] or 0)
      for i = 1, missing do
        parts[#parts + 1] = Engine.LETTER[t]
      end
    end
    return table.concat(parts, " ")
  end
  local sUp = "Tu capturas: %s"
  local sDown = "Tu rival captura: %s"
  if B == netBoard then
    capturedFS:SetText((sUp .. "      " .. sDown):format(captureString(BLACK), captureString(WHITE)))
  else
    capturedFS:SetText((sUp .. "      " .. "La maquina captura: %s"):format(captureString(BLACK), captureString(WHITE)))
  end
end

function resultMessage(st)
  if st.result == "mate" then
    if st.loser == WHITE then return "Jaque mate. Gano la maquina." end
    return "Jaque mate. Has ganado!"
  elseif st.result == "stalemate" then
    return "Ahogado. Empate."
  elseif st.result == "drawRep" then
    return "Empate por repeticion de jugadas."
  elseif st.result == "draw50" then
    return "Empate por la regla de las 50 jugadas."
  elseif st.result == "drawMaterial" then
    return "Empate por material insuficiente."
  end
  return ""
end

function updateStatusText(B)
  local s = B.state
  if s.gameOver then return end
  local base
  local subBase
  if B == netBoard then
    if s.pos.turn == netColor then
      base = "Tu turno"
      subBase = "Te toca mover."
    else
      base = "Turno de " .. netOpponent .. "..."
      subBase = "Esperando a " .. netOpponent .. "..."
    end
  else
    base = "Tu turno"
    if s.pos.turn == BLACK then base = "Turno de la maquina..." end
  end
  if Engine.inCheck(s.pos, s.pos.turn) then
    base = base .. "  --  JAQUE!"
    pcall(PlaySoundFile, SOUNDS.check)
  end
  setStatus(B, base)
  if B == netBoard then
    setSub(B, subBase, "turn")
  end
end

function netResultText(st, resigned)
  if resigned then
    if resigned == netColor then
      return ("Te has rendido. Gana %s."):format(netOpponent)
    else
      return ("%s se ha rendido. Has ganado!"):format(netOpponent)
    end
  end
  if st.result == "mate" then
    if st.loser == netColor then
      return ("Jaque mate. Gana %s."):format(netOpponent)
    end
    return ("Jaque mate. Has ganado a %s!"):format(netOpponent)
  elseif st.result == "stalemate" then
    return "Ahogado. Tablas."
  elseif st.result == "drawRep" then
    return "Tablas por repeticion de jugadas."
  elseif st.result == "draw50" then
    return "Tablas por la regla de las 50 jugadas."
  elseif st.result == "drawMaterial" then
    return "Tablas por material insuficiente."
  elseif st.result == "drawAgreed" then
    return ("Tablas pactadas con %s."):format(netOpponent)
  end
  return ""
end

function setGameOver(B, st, resigned)
  local s = B.state
  s.gameOver = true
  s.thinking = false
  s.humanTurn = false
  s.selected = nil
  s.candidates = {}
  s.hintMove = nil
  hidePromotion(B)
  setOnlineButtons()
  if B == netBoard then
    setStatus(B, netResultText(st, resigned))
  else
    setStatus(B, resultMessage(st))
  end
  setSub(B, "")
end

-- ---- repeticion ----
function noteRep(B)
  local k = Engine.positionKey(B.state.pos)
  B.state.repCounts[k] = (B.state.repCounts[k] or 0) + 1
end

-- ---- movimiento humano ----
function selectPiece(B, sq)
  local s = B.state
  s.selected = sq
  s.candidates = {}
  local moves = Engine.genMoves(s.pos)
  for _, m in ipairs(moves) do
    if m.from == sq then
      s.candidates[#s.candidates + 1] = m
    end
  end
  showSelection(B)
end

function executeHumanMove(B, m)
  local s = B.state
  Engine.makeMove(s.pos, m)
  s.gameMoves[#s.gameMoves + 1] = m
  noteRep(B)
  s.lastMoves = { m.from, m.to }
  s.selected = nil
  s.candidates = {}
  s.hintMove = nil
  if B == netBoard then
    local mv = sqName(m.from) .. sqName(m.to)
    if m.promo ~= 0 then mv = mv .. Engine.LETTER[m.promo] end
    Net.Send(netOpponent, Net.Envelope("mov", netGid, mv))
  end
  playSoundWav(m)
  refreshBoard(B)
  afterHumanMove(B)
end

function afterHumanMove(B)
  local s = B.state
  local st = Engine.status(s.pos, s.repCounts)
  if st.result then
    setGameOver(B, st)
    return
  end
  if B == netBoard then
    s.humanTurn = false
    updateStatusText(B)
    return
  end
  if s.pos.turn == WHITE then
    s.humanTurn = true
    updateStatusText(B)
  else
    s.humanTurn = false
    s.thinking = true
    setSub(B, "")
    updateStatusText(B)
    schedule(0.5, function() aiThink(B) end)
  end
end

function onSquareClick(B, sq)
  local s = B.state
  if s.gameOver or s.thinking or not F:IsShown() then return end
  if B == netBoard then
    if not online then return end
    if netAwaitingAccept or s.pos.turn ~= netColor then return end
  elseif s.pos.turn ~= WHITE then
    return
  end

  local pc = s.pos.board[sq]

  if s.selected then
    if sq == s.selected then
      s.selected = nil
      s.candidates = {}
      showSelection(B)
      return
    end
    if pc ~= 0 and isMyPiece(B, pc) then
      selectPiece(B, sq)
      return
    end
    local hits = {}
    for _, m in ipairs(s.candidates) do
      if m.to == sq then hits[#hits + 1] = m end
    end
    if #hits > 0 then
      if #hits > 1 then
        s.pendingPromo = hits
        promoBoard = B
        showPromotion(B)
      else
        executeHumanMove(B, hits[1])
      end
      return
    end
    s.selected = nil
    s.candidates = {}
    showSelection(B)
    return
  end

  if pc ~= 0 and isMyPiece(B, pc) then
    selectPiece(B, sq)
  end
end

-- ---- IA ----
function aiThink(B)
  local s = B.state
  if s.gameOver then return end
  local diff = DIFFICULTIES[difficulty] or DIFFICULTIES[2]
  local m = Engine.findBestMove(s.pos, diff.depth, diff.noise)
  if not m then
    setGameOver(B, Engine.status(s.pos, s.repCounts))
    return
  end
  Engine.makeMove(s.pos, m)
  s.gameMoves[#s.gameMoves + 1] = m
  noteRep(B)
  s.lastMoves = { m.from, m.to }
  s.selected = nil
  s.candidates = {}
  s.hintMove = nil
  playSoundWav(m)
  refreshBoard(B)

  local st = Engine.status(s.pos, s.repCounts)
  if st.result then
    setGameOver(B, st)
    return
  end
  s.thinking = false
  s.humanTurn = true
  updateStatusText(B)
end

-- ---- pista ----
function showHint(B)
  local s = B.state
  if s.gameOver or s.thinking or s.pos.turn ~= WHITE then return end
  if B == netBoard then
    setSub(B, "Sin pistas en partida online.")
    return
  end
  local diff = DIFFICULTIES[difficulty] or DIFFICULTIES[2]
  local m = Engine.findBestMove(s.pos, diff.depth, 0)
  if not m then return end
  s.hintMove = m
  refreshBoard(B)
  local target = Engine.LETTER[m.promo ~= 0 and m.promo or math.abs(m.piece)]
  setSub(B, ("Pista: %s -> %s (%s)"):format(sqName(m.from), sqName(m.to), target))
end

-- ---- controles ----
function newGame()
  cancelTimer()
  local s = aiState
  s.pos = Engine.newPosition()
  s.gameMoves = {}
  s.repCounts = {}
  s.selected = nil
  s.candidates = {}
  s.flipped = false
  s.gameOver = false
  s.humanTurn = true
  s.thinking = false
  s.pendingPromo = nil
  s.hintMove = nil
  s.lastMoves = {}
  hidePromotion(aiBoard)
  refreshBoard(aiBoard)
  setStatus(aiBoard, "Empieza el juego. Te toca jugar (blancas).")
  setSub(aiBoard, "")
  updateOnlineView()
  setTab("ai")
end

function doUndo()
  if online then
    setSub(aiBoard, "No se puede deshacer en online.")
    return
  end
  local s = aiState
  if #s.gameMoves == 0 then return end
  cancelTimer()
  s.thinking = false
  hidePromotion(aiBoard)

  local n = 1
  if s.pos.turn == WHITE then n = 2 end
  if n > #s.gameMoves then n = #s.gameMoves end

  for i = 1, n do
    local m = s.gameMoves[#s.gameMoves]
    local k = Engine.positionKey(s.pos)
    if s.repCounts[k] then
      s.repCounts[k] = s.repCounts[k] - 1
      if s.repCounts[k] <= 0 then s.repCounts[k] = nil end
    end
    Engine.unmakeMove(s.pos, m)
    table.remove(s.gameMoves)
  end

  s.gameOver = false
  s.humanTurn = true
  s.selected = nil
  s.candidates = {}
  s.hintMove = nil
  s.lastMoves = {}
  refreshBoard(aiBoard)
  setStatus(aiBoard, "Jugada deshecha. Te toca (blancas).")
  setSub(aiBoard, "")
end

function setDifficulty(i)
  difficulty = i
  UIDropDownMenu_SetText(diffDD, DIFFICULTIES[i].name)
  if ChessOptions then
    ChessOptions.difficulty = i
  end
end

-- ---- online ----
local function sideName(c)
  return (c == WHITE) and "Blancas" or "Negras"
end

local function randomGid()
  local chars = "abcdefghjkmnpqrstuvwxyz23456789"
  local gid = ""
  for _ = 1, 4 do
    local n = math.random(#chars)
    gid = gid .. chars:sub(n, n)
  end
  return gid
end

local function sqIdx(s)
  local c = s:byte(1) - 96
  local r = s:byte(2) - 48
  if c < 1 or c > 8 or r < 1 or r > 8 then return nil end
  return Engine.idx(r, c)
end

local function decodeMove(S, s)
  if type(s) ~= "string" or #s < 4 then return nil end
  local from = sqIdx(s:sub(1, 2))
  local to = sqIdx(s:sub(3, 4))
  if not from or not to then return nil end
  local promo = 0
  if #s >= 5 then
    promo = Engine.PIECE[s:sub(5, 5):upper()] or 0
  end
  local pc = S.pos.board[from]
  if pc == 0 then return nil end
  local t = math.abs(pc)
  local m = {
    from = from, to = to, piece = pc, type = t,
    promo = promo, isEP = false, doublePush = false, castle = nil,
  }
  local dc = Engine.col(to) - Engine.col(from)
  if t == Engine.K and math.abs(dc) == 2 then
    m.castle = (Engine.col(to) == 7) and "K" or "Q"
  elseif t == Engine.P then
    if dc ~= 0 and S.pos.board[to] == 0 then m.isEP = true end
    if dc == 0 and math.abs(Engine.row(to) - Engine.row(from)) == 2 then m.doublePush = true end
  end
  for _, gm in ipairs(Engine.genMoves(S.pos)) do
    if gm.from == from and gm.to == to and gm.promo == promo and
       gm.isEP == m.isEP and gm.doublePush == m.doublePush and gm.castle == m.castle then
      return gm
    end
  end
  return nil
end

function netShowMsg(s)
  print(s)
end

local function pureName(n)
  return (n or ""):gsub("%-%w+$", ""):lower()
end

local function myNameMatches(target)
  if not target or target == "" then return true end
  local my = pcall(UnitName, "player") and UnitName("player") or ""
  local t = pureName(target)
  local m = pureName(my)
  return t == m or target:lower() == my:lower()
end

-- ---- lista de retos recibidos ----
function invListRefresh()
  local now = GetTime()
  local live = {}
  for _, e in ipairs(netIncoming) do
    if now - e.t <= INV_TTL then live[#live + 1] = e end
  end
  netIncoming = live
  for i, slot in ipairs(invSlots) do
    local e = netIncoming[i]
    if e then
      slot.row:Show()
      slot.nm:SetText(e.opp .. " te reta.")
    else
      slot.row:Hide()
    end
  end
  if #netIncoming == 0 then invEmpty:Show() else invEmpty:Hide() end
end

local function invListAdd(gid, opp, seed)
  for _, e in ipairs(netIncoming) do
    if e.gid == gid then
      e.opp, e.seed, e.t = opp, seed, GetTime()
      invListRefresh()
      return
    end
  end
  netIncoming[#netIncoming + 1] = { gid = gid, opp = opp, seed = seed, t = GetTime() }
  invListRefresh()
end

function invListPopPopup()
  local e = netIncoming[1]
  if not e then
    pendingInvGid, pendingInvSeed, pendingInvOpp = nil, nil, nil
    invPopShownGid = nil
    invPopShown = 0
    StaticPopup_Hide("CHESS_INVITE")
    return
  end
  -- si el popup ya esta mostrando este mismo reto, no lo re-muestres:
  -- en algunos clientes re-mostrar un popup visible dispara OnCancel y
  -- eso rechazaba el reto automaticamente al llegar cada copia duplicada.
  if invPopShownGid == e.gid then
    pendingInvGid = e.gid
    pendingInvSeed = e.seed
    pendingInvOpp = e.opp
    return
  end
  pendingInvGid = e.gid
  pendingInvSeed = e.seed
  pendingInvOpp = e.opp
  StaticPopupDialogs["CHESS_INVITE"].text = ("%s te reta a una partida de ajedrez."):format(e.opp)
  StaticPopup_Show("CHESS_INVITE")
  invPopShownGid = e.gid
  invPopShown = GetTime()
end

local function invRemove(gid)
  for i = #netIncoming, 1, -1 do
    if netIncoming[i].gid == gid then table.remove(netIncoming, i) end
  end
  invListRefresh()
end

function acceptEntry(e)
  if online or netAwaitingAccept then return end
  local gid = e.gid
  for _, o in ipairs(netIncoming) do
    if o.gid ~= gid then
      Net.Send(o.opp, Net.Envelope("dec", o.gid))
    end
  end
  wipe(netIncoming)
  invListRefresh()
  pendingInvGid, pendingInvSeed, pendingInvOpp = nil, nil, nil
  invPopShownGid = nil
  StaticPopup_Hide("CHESS_INVITE")
  Net.Send(e.opp, Net.Envelope("ack", gid))
  Net.SendWhisper(e.opp, Net.Envelope("ack", gid))
  netSetup(e.opp, gid, -(((e.seed % 2 == 1) and WHITE) or BLACK))
end

function declineEntry(e)
  Net.Send(e.opp, Net.Envelope("dec", e.gid))
  Net.SendWhisper(e.opp, Net.Envelope("dec", e.gid))
  if pendingInvGid == e.gid then
    pendingInvGid, pendingInvSeed, pendingInvOpp = nil, nil, nil
    invPopShownGid = nil
  end
  invRemove(e.gid)
  invListPopPopup()
end

function updateOnlineView()
  if activeTab == "online" then
    if online then
      invPanel:Hide()
      row3:Show()
      aiBoard.frame:Hide()
      netBoard.frame:Show()
      capturedFS:Show()
      statusFS:Show()
      subFS:Show()
    else
      invPanel:Show()
      row3:Show()
      aiBoard.frame:Hide()
      netBoard.frame:Hide()
      capturedFS:Hide()
      statusFS:Hide()
      subFS:Hide()
      setOnlineButtons()
      invListRefresh()
    end
  else
    invPanel:Hide()
    row3:Hide()
    netBoard.frame:Hide()
    aiBoard.frame:Show()
    capturedFS:Show()
    statusFS:Show()
    subFS:Show()
  end
end

local invTick = CreateFrame("Frame", nil, UIParent)
local invTickAccum = 0
invTick:SetScript("OnUpdate", function(self, elapsed)
  invTickAccum = invTickAccum + elapsed
  if invTickAccum < 1 then return end
  invTickAccum = 0
  if #netIncoming > 0 or pendingInvGid then
    invListRefresh()
    if netIncoming[1] and pendingInvGid ~= netIncoming[1].gid then
      invListPopPopup()
    elseif not netIncoming[1] and pendingInvGid then
      pendingInvGid, pendingInvSeed, pendingInvOpp = nil, nil, nil
      invPopShownGid = nil
      StaticPopup_Hide("CHESS_INVITE")
    end
  end
end)

function setOnlineButtons()
  if online then
    onlineBtn:Hide()
    exitBtn:Show()
    paintEnabled(onlineBtn, false)
    if netAwaitingAccept then
      netFlipBtn:Hide()
    else
      netFlipBtn:Show()
    end
    if netState.gameOver then
      resignBtn:Hide()
      drawBtn:Hide()
      rematchBtn:Show()
    else
      resignBtn:Show()
      drawBtn:Show()
      rematchBtn:Hide()
    end
  else
    onlineBtn:Show()
    exitBtn:Hide()
    paintEnabled(onlineBtn, true)
    resignBtn:Hide()
    drawBtn:Hide()
    rematchBtn:Hide()
    netFlipBtn:Hide()
  end
end

function startOnlineGame()
  local s = netState
  s.pos = Engine.newPosition()
  s.gameMoves = {}
  s.repCounts = {}
  s.selected = nil
  s.candidates = {}
  s.gameOver = false
  s.humanTurn = true
  s.thinking = false
  s.pendingPromo = nil
  s.hintMove = nil
  s.lastMoves = {}
  s.flipped = (netColor == BLACK)
  netDrawSent = false
  hidePromotion(netBoard)
  refreshBoard(netBoard)
  setStatus(netBoard, ("Partida online vs %s. Tu color: %s."):format(netOpponent, sideName(netColor)))
  if s.pos.turn == netColor then
    setSub(netBoard, "Te toca mover.", "turn")
  else
    setSub(netBoard, "Esperando a " .. netOpponent .. "...", "turn")
  end
  setTab("online")
end

function netSetup(opp, gid, color)
  netOpponent = opp
  netGid = gid
  netColor = color
  netAwaitingAccept = false
  online = true
  startOnlineGame()
end

function netChallenge(name)
  if online then
    print("Ya estas en una partida online. Usa Rendirse para salir.")
    return
  end
  local seed = math.random(1, 100000000)
  local gid = randomGid()
  netOpponent = name
  netGid = gid
  netInvSeed = seed
  netColor = (seed % 2 == 1) and WHITE or BLACK
  netAwaitingAccept = true
  online = true
  hidePromotion(netBoard)
  setTab("online")
  local payload = Net.Envelope("inv", gid, tostring(seed) .. " " .. name)
  Net.Send(name, payload)
  Net.Shake(name, payload)
  -- reenvios por si el primer mensaje se pierde mientras el rival aun
  -- no nos ha respondido (canales dobles: addon + susurro normal)
  for _, delay in ipairs({ 2, 6, 12 }) do
    schedule(delay, function()
      if netAwaitingAccept and netGid == gid then
        Net.Send(name, payload)
        Net.SendWhisper(name, payload)
      end
    end)
  end
  setOnlineButtons()
  setStatus(netBoard, ("Esperando respuesta de %s..."):format(name))
  setSub(netBoard, ("Reto enviado (tu color: %s)."):format(sideName(netColor)))
  schedule(25, function()
    if netAwaitingAccept and netGid == gid then
      netAwaitingAccept = false
      online = false
      setOnlineButtons()
      updateOnlineView()
      print(("Sin respuesta de %s. Comprueba que este en linea con el addon."):format(name))
    end
  end)
end

function netAcceptInvite(accept)
  local gid = pendingInvGid
  for _, x in ipairs(netIncoming) do
    if x.gid == gid then
      if accept then
        acceptEntry(x)
      else
        declineEntry(x)
      end
      return
    end
  end
  local opp = pendingInvOpp
  local seed = pendingInvSeed
  pendingInvGid, pendingInvSeed, pendingInvOpp = nil, nil, nil
  invPopShownGid = nil
  if not (gid and opp) then return end
  if accept then
    Net.Send(opp, Net.Envelope("ack", gid))
    Net.SendWhisper(opp, Net.Envelope("ack", gid))
    netSetup(opp, gid, -(((seed % 2 == 1) and WHITE) or BLACK))
  else
    Net.Send(opp, Net.Envelope("dec", gid))
    Net.SendWhisper(opp, Net.Envelope("dec", gid))
  end
end

Net.callbacks.inv = function(sender, gid, rest)
  if online or netAwaitingAccept then
    -- ya estamos en partida o esperando aceptar otro reto: lo ignoramos en
    -- silencio (sin "dec", evita que un reto duplicado por los dos canales
    -- nos "rechace" justo tras aceptar)
    return
  end
  local seedStr, target = rest:match("^(-?%d+) ?(.*)$")
  if not seedStr then return end
  if not myNameMatches(target) then return end
  local seed = tonumber(seedStr) or 0
  setTab("online")
  invListAdd(gid, sender, seed)
  invListPopPopup()
end

-- si estamos esperando que un rival acepte nuestro reto, se lo
-- reenviamos: su cliente ya registro el prefijo (apreton de manos)
local function netResendInvite(sender)
  if not (online and netAwaitingAccept) then return end
  if pureName(sender) ~= pureName(netOpponent) then return end
  Net.Send(netOpponent, Net.Envelope("inv", netGid, tostring(netInvSeed) .. " " .. netOpponent))
end

-- alguien nos respondio con el susurro normal de sincronizacion
Net.OnHello(function(sender)
  -- que registre en su cliente el prefijo: nos envia un mensaje de addon
  Net.Send(sender, Net.Envelope("hlo", "0000"))
  netResendInvite(sender)
end)

-- recibimos un mensaje de addon "hlo"
Net.callbacks.hlo = function(sender, gid, rest)
  netResendInvite(sender)
end

Net.callbacks.ack = function(sender, gid, rest)
  if not netAwaitingAccept or netGid ~= gid then return end
  netAwaitingAccept = false
  startOnlineGame()
end

Net.callbacks.dec = function(sender, gid, rest)
  if not netAwaitingAccept or netGid ~= gid then return end
  if pureName(sender) ~= pureName(netOpponent) then return end
  netAwaitingAccept = false
  online = false
  setOnlineButtons()
  updateOnlineView()
  print(("%s rechazo tu reto."):format(pureName(sender)))
end

Net.callbacks.icn = function(sender, gid, rest)
  local had = false
  for i = #netIncoming, 1, -1 do
    if netIncoming[i].gid == gid then
      table.remove(netIncoming, i)
      had = true
    end
  end
  if pendingInvGid == gid then
    pendingInvGid, pendingInvSeed, pendingInvOpp = nil, nil, nil
    invPopShownGid = nil
    StaticPopup_Hide("CHESS_INVITE")
  end
  if had then
    invListRefresh()
    invListPopPopup()
  end
end

Net.callbacks.mov = function(sender, gid, rest)
  if not online or netAwaitingAccept or netState.gameOver or netGid ~= gid then return end
  local s = netState
  if s.pos.turn == netColor then return end
  local m = decodeMove(s, rest)
  if not m then
    netShowMsg("Movimiento invalido recibido.")
    return
  end
  Engine.makeMove(s.pos, m)
  s.gameMoves[#s.gameMoves + 1] = m
  noteRep(netBoard)
  s.lastMoves = { m.from, m.to }
  s.selected = nil
  s.candidates = {}
  s.hintMove = nil
  playSoundWav(m)
  refreshBoard(netBoard)
  local st = Engine.status(s.pos, s.repCounts)
  if st.result then
    setGameOver(netBoard, st)
    return
  end
  s.humanTurn = (s.pos.turn == netColor)
  updateStatusText(netBoard)
end

Net.callbacks.rsg = function(sender, gid, rest)
  if not online or netGid ~= gid or netState.gameOver then return end
  setGameOver(netBoard, nil, -netColor)
end

function netResign()
  if not online or netState.gameOver then return end
  Net.Send(netOpponent, Net.Envelope("rsg", netGid))
  setGameOver(netBoard, nil, netColor)
end

function netOfferDraw()
  if not online or netState.gameOver then return end
  if netDrawSent then
    netDrawSent = false
    Net.Send(netOpponent, Net.Envelope("drw", netGid, "can"))
    setSub(netBoard, "")
    return
  end
  netDrawSent = true
  Net.Send(netOpponent, Net.Envelope("drw", netGid, "offer"))
  setSub(netBoard, "Oferta de tablas enviada...")
end

function netOnDraw(kind)
  StaticPopup_Hide("CHESS_DRAW")
  if not online or netState.gameOver then return end
  if kind == "acc" then
    Net.Send(netOpponent, Net.Envelope("drw", netGid, "acc"))
    setGameOver(netBoard, { result = "drawAgreed" }, nil)
  else
    Net.Send(netOpponent, Net.Envelope("drw", netGid, "dec"))
  end
end

Net.callbacks.drw = function(sender, gid, rest)
  if not online or netGid ~= gid or netState.gameOver then return end
  if rest == "offer" then
    StaticPopupDialogs["CHESS_DRAW"].text = ("%s ofrece tablas."):format(sender)
    StaticPopup_Show("CHESS_DRAW")
  elseif rest == "acc" then
    StaticPopup_Hide("CHESS_DRAW")
    setGameOver(netBoard, { result = "drawAgreed" }, nil)
  elseif rest == "dec" then
    netDrawSent = false
    setSub(netBoard, ("%s rechazo tus tablas."):format(sender))
  elseif rest == "can" then
    netDrawSent = false
    setSub(netBoard, "")
  end
end

function netRematch(newgid)
  pendingRematchGid = nil
  netGid = newgid
  netColor = -netColor
  netDrawSent = false
  startOnlineGame()
end

function netOnRematch(kind)
  StaticPopup_Hide("CHESS_REMATCH")
  if kind == "acc" then
    if pendingRematchGid then
      Net.Send(netOpponent, Net.Envelope("rm", netGid, "acc " .. pendingRematchGid))
      netRematch(pendingRematchGid)
    end
  else
    Net.Send(netOpponent, Net.Envelope("rm", netGid, "dec"))
    pendingRematchGid = nil
  end
end

function netOfferRematch()
  if not online or not netState.gameOver then return end
  local newgid = randomGid()
  pendingRematchGid = newgid
  Net.Send(netOpponent, Net.Envelope("rm", netGid, "req " .. newgid))
  setSub(netBoard, "Proponiendo revancha...")
end

Net.callbacks.rm = function(sender, gid, rest)
  if not online or netGid ~= gid or not netState.gameOver then return end
  local kind, newgid = rest:match("^(%a+) ?([%w]*)$")
  if kind == "req" then
    if not newgid or newgid == "" then return end
    pendingRematchGid = newgid
    StaticPopupDialogs["CHESS_REMATCH"].text = ("%s propone una revancha."):format(sender)
    StaticPopup_Show("CHESS_REMATCH")
  elseif kind == "acc" then
    netRematch(newgid)
  elseif kind == "dec" then
    setSub(netBoard, ("%s no quiere revancha."):format(sender))
  end
end

-- salir de la partida online y volver al panel de invitaciones:
-- si la partida sigue en juego, rendirse primero
function netExit()
  if not online then return end
  if not netState.gameOver then
    if Net.Send then
      Net.Send(netOpponent, Net.Envelope("rsg", netGid))
      Net.SendWhisper(netOpponent, Net.Envelope("rsg", netGid))
    end
  end
  local s = netState
  s.pos = Engine.newPosition()
  s.gameMoves = {}
  s.repCounts = {}
  s.selected = nil
  s.candidates = {}
  s.flipped = false
  s.gameOver = false
  s.humanTurn = true
  s.thinking = false
  s.pendingPromo = nil
  s.hintMove = nil
  s.lastMoves = {}
  online = false
  netAwaitingAccept = false
  netOpponent = nil
  netGid = nil
  netColor = WHITE
  netDrawSent = false
  pendingRematchGid = nil
  StaticPopup_Hide("CHESS_DRAW")
  StaticPopup_Hide("CHESS_REMATCH")
  setOnlineButtons()
  setTab("online")
  print("Has salido de la partida online.")
end

-- ---- arranque ----
SLASH_CHESS1 = "/chess"
SLASH_CHESS2 = "/ajedrez"
SlashCmdList["CHESS"] = function(msg)
  msg = tostring(msg or ""):gsub("^%s*(.-)%s*$", "%1")
  local cmd, rest = msg:match("^(%S*)%s?(.*)$")
  if cmd == "reto" and rest ~= "" then
    netChallenge(rest)
    return
  end
  if cmd == "reto" then
    print("Uso: /chess reto NombreJugador")
    return
  end
  if cmd == "solo" or cmd == "local" then
    setTab("ai")
    return
  end
  if cmd == "online" then
    setTab("online")
    return
  end
  if cmd == "debug" or cmd == "log" then
    Net.SetDebug(not Net.GetDebug())
    return
  end
  if cmd == "check" or cmd == "estado" then
    local i = Net.GetInfo()
    print("[Chess] Estado:")
    print(("[Chess]   personaje: %s (%s)"):format(i.me, i.realm))
    print(("[Chess]   partida online: %s | esperando aceptacion: %s")
      :format(tostring(online), tostring(netAwaitingAccept)))
    print(("[Chess]   eventos: %s | auto-eco: %s | cola: %d")
      :format(tostring(i.events), tostring(i.registered), i.queue))
    print(("[Chess]   RegisterAddonMessagePrefix: %s | prefijo registrado: %s")
      :format(tostring(i.apiAvailable), tostring(i.prefixRegistered)))
    print(("[Chess]   log: %s | para activarlo: /chess debug"):format(tostring(i.debug)))
    return
  end
  if cmd == "teste" or cmd == "prueba" then
    if rest == "" then
      print("Uso: /chess teste NombreJugador")
    else
      Net.Test(rest)
    end
    return
  end
  if F:IsShown() then F:Hide() else F:Show() end
end

local startup = CreateFrame("Frame")
startup:RegisterEvent("ADDON_LOADED")
startup:SetScript("OnEvent", function(self, event, addon)
  if addon ~= "Chess" then return end
  self:SetScript("OnEvent", nil)

  ChessOptions = ChessOptions or {}
  difficulty = ChessOptions.difficulty or 2
  difficulty = math.max(1, math.min(3, difficulty))
  UIDropDownMenu_SetText(diffDD, DIFFICULTIES[difficulty].name)

  Net.Enable()
  Net.Note()
  newGame()
  setTab("ai")
  F:Show()
end)

newGame()
netState.pos = Engine.newPosition()

UI._state = function()
  local B = activeBoard()
  local s = B.state
  local cands = {}
  for _, c in ipairs(s.candidates) do cands[#cands + 1] = sqName(c.from) .. "-" .. sqName(c.to) end
  local incoming = {}
  for _, e in ipairs(netIncoming) do incoming[#incoming + 1] = e.opp end
  return {
    online = online, gid = netGid, color = netColor, opp = netOpponent,
    awaiting = netAwaitingAccept, tab = activeTab,
    incoming = table.concat(incoming, " "),
    turn = s.pos and s.pos.turn, myturn = (s.pos and online and s.pos.turn == netColor),
    selected = s.selected and sqName(s.selected), candidates = table.concat(cands, " "),
    board = s.pos and table.concat(s.pos.board, ","),
    over = s.gameOver, flipped = s.flipped,
  }
end