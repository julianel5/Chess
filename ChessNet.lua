-- ChessNet.lua
-- Transporte online para WoW 3.3.5.
-- Como funciona el mensajero de addon en 3.3.5:
--   * No existe "CHANNEL" en SendAddonMessage (es de 6.x) ni la API
--     RegisterAddonMessagePrefix (es de 4.1.0). En 3.3.5 el cliente
--     entrega TODOS los mensajes de addon, sin filtro por prefijo.
--   * PRECAUCION CLAVE: el chat de WoW se come los codigos "|" (son
--     codigos internos de color/link). NINGUN mensaje del protocolo usa
--     "|": los campos se separan con espacios.
--   * Canal valido para 1v1: solo "WHISPER".
--   * Un susurro NORMAL (SendChatMessage) siempre llega; uno de addon
--     puede que el servidor privado no lo routee. Por eso los mensajes
--     criticos viajan por AMBOS canales (addon + susurro normal con la
--     palabra magica "!ajedrez").
-- Diagnostico:
--   /chess debug  -> registra en el chat cada envio/recepcion
--   /chess teste  -> prueba de ida y vuelta con un rival
--   /chess check  -> estado interno

ChessNet = nil
local M = {}
ChessNet = M

local PREFIX = "ChessNW1"
-- NS = prefijo de los mensajes "con envoltorio" (mismo en addon y susurro)
local NS = "chess "
local HELLO = "!ajedrez"

M.PREFIX = PREFIX
M.helloTok = HELLO

-- callbacks registrados por ChessUI: inv, ack, dec, icn, hlo, mov, rsg, drw, rm
M.callbacks = {}
-- protocolo interno de prueba (tst/tstok) gestionado por ChessNet
M.builtin = {}

local queue = {}
local nextSend = 0
local frame = CreateFrame("Frame", "ChessNetFrame")
frame:Hide()

local handshakeCB = nil
local registered = false
local prefixRegistered = false
local debugOn = false

local function dbg(...)
  if not debugOn then return end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[Chess]|r " .. format("|cffcccccc%.2f|r", GetTime()) .. " " .. format(...))
  end
end

function M.SetDebug(on)
  debugOn = (on or false)
  if debugOn then
    print("[Chess] Log de comunicaciones ACTIVADO")
  else
    print("[Chess] Log de comunicaciones desactivado")
  end
end

function M.GetDebug()
  return debugOn
end

local function pureName(n)
  return (n or ""):gsub("%-%w+$", ""):lower()
end

-- Algunos clientes "3.3.5" (modificados o con APIs reincorporadas) filtran
-- los mensajes de addon entrantes: solo entregan los prefijos registrados
-- con RegisterAddonMessagePrefix. Si la API existe en este cliente, la
-- usamos para que no nos descarten los mensajes de chess.
local function registerPrefixApi()
  if prefixRegistered then return end
  local fn = RegisterAddonMessagePrefix
  if type(fn) ~= "function" and C_ChatInfo then
    fn = C_ChatInfo.RegisterAddonMessagePrefix
  end
  if type(fn) ~= "function" then return end
  local ok, res = pcall(fn, PREFIX)
  prefixRegistered = ok and not not res
  dbg("REG-API: RegisterAddonMessagePrefix(%q) -> %s", PREFIX, tostring(prefixRegistered))
end

local function addToQueue(packet)
  local now = GetTime()
  if now < nextSend then
    queue[#queue + 1] = packet
  else
    queue[#queue + 1] = packet
    if #queue <= 1 then nextSend = now + 0.15 end
  end
end

local function trySend(packet)
  local ok, err = pcall(SendAddonMessage, packet.prefix, packet.text, "WHISPER", packet.target)
  dbg("TX addon -> %s : %s   (ok=%s %s)", packet.target, packet.text or "", tostring(ok), tostring(err or ""))
  return ok
end

-- registra la sesion de addon en NUESTRO cliente con un eco a nosotros
-- mismos. No es imprescindible en 3.3.5, y sirve como comprobacion.
local function selfRegister()
  if registered then return end
  local me = pcall(UnitName, "player") and UnitName("player") or ""
  if me == "" then return end
  dbg("REG: auto-eco de addon a %q", me)
  addToQueue({ prefix = PREFIX, text = M.Envelope("hlo", "0000"), target = me })
  registered = true
end

frame:SetScript("OnUpdate", function(self, elapsed)
  selfRegister()
  registerPrefixApi()
  if #queue == 0 then return end
  local now = GetTime()
  if now < nextSend then return end
  while #queue > 0 and now >= nextSend do
    local packet = table.remove(queue, 1)
    trySend(packet)
    nextSend = now + 0.15
  end
end)

local function handleWhisper(msg, sender)
  -- palabra magica: puede llevar un mensaje de addon adosado (fallback).
  -- Nada de "|" en el texto: WoW se lo come.
  if msg:sub(1, #HELLO) == HELLO then
    local body = msg:sub(#HELLO + 1)
    body = body:gsub("^%s+", "")
    if body:sub(1, #NS) == NS then
      M.dispatch(body, sender)
    end
    if handshakeCB then
      pcall(handshakeCB, sender)
    end
    return
  end
  -- retrocompatibilidad: mensajes de addon sueltos enviados por susurro
  M.dispatch(msg, sender)
  if msg:find(HELLO, 1, true) then
    if handshakeCB then
      pcall(handshakeCB, sender)
    end
  end
end

frame:SetScript("OnEvent", function(self, event, ...)
  local info = { ... }
  local my = pcall(UnitName, "player") and UnitName("player") or ""
  if event == "CHAT_MSG_WHISPER" then
    local msg = info[1]
    local sender = info[2]
    dbg("RX susurro de %s : %q", tostring(sender), tostring(msg))
    if type(msg) ~= "string" or type(sender) ~= "string" then return end
    if sender ~= "" and pureName(sender) == pureName(my) then
      dbg("  (susurro propio, ignorado)")
      return
    end
    handleWhisper(msg, sender)
  elseif event == "CHAT_MSG_ADDON" then
    -- 3.3.5: args = prefix, message, canal, sender
    local prefix = info[1]
    local msg = info[2]
    local chan = info[3]
    local sender = info[4]
    if type(prefix) ~= "string" or type(msg) ~= "string" then return end
    if prefix ~= PREFIX then
      -- trafico de otros addons: se ignora en silencio (no ensuciar el log)
      return
    end
    dbg("RX addon de %s : %s (chan=%s)", tostring(sender), msg, tostring(chan))
    if chan ~= "WHISPER" then
      dbg("  (canal %s, no es WHISPER: ignorado)", tostring(chan))
      return
    end
    if sender ~= "" and pureName(sender) == pureName(my) then
      dbg("  (addon propio/eco, ignorado)")
      return
    end
    M.dispatch(msg, sender)
  elseif event == "PLAYER_ENTERING_WORLD" then
    registerPrefixApi()
    selfRegister()
  end
end)

function M.Enable()
  dbg("Enable() -- registrando eventos")
  registerPrefixApi()
  frame:RegisterEvent("CHAT_MSG_WHISPER")
  frame:RegisterEvent("CHAT_MSG_ADDON")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:Show()
end

function M.Disable()
  frame:Hide()
  wipe(queue)
end

-- registra el prefijo en NUESTRO cliente; se reintenta en OnUpdate hasta
-- que UnitName devuelva un nombre valido
function M.Note()
  selfRegister()
end

-- apreton de manos: mensaje de addon (puede perderse al principio) +
-- susurro normal con la palabra magica (ese SIEMPRE llega). Si se pasa
-- "payload", el susurro lo lleva adosado para que llegue igualmente.
function M.Shake(target, payload)
  if not target or target == "" then return end
  dbg("SHAKE -> %s (payload=%s)", target, payload or "(solo magia)")
  addToQueue({ prefix = PREFIX, text = M.Envelope("hlo", "0000"), target = target })
  local whisper = HELLO
  if payload then
    whisper = whisper .. " " .. payload
  end
  local ok = pcall(SendChatMessage, whisper, "WHISPER", nil, target)
  dbg("TX susurro normal -> %s : %q  (ok=%s)", target, whisper, tostring(ok or false))
end

-- enviar un mensaje por el canal garantizado (susurro normal)
function M.SendWhisper(target, payload)
  if not target or target == "" or not payload then return end
  local txt = HELLO
  if payload then txt = HELLO .. " " .. payload end
  local ok = pcall(SendChatMessage, txt, "WHISPER", nil, target)
  dbg("TX susurro normal -> %s : %q  (ok=%s)", target, txt, tostring(ok or false))
end

-- registra un callback que se lanza cuando alguien envia el susurro normal
function M.OnHello(cb)
  handshakeCB = cb
end

function M.Send(target, payload)
  if not target or target == "" then return end
  addToQueue({ prefix = PREFIX, text = payload, target = target })
end

function M.Envelope(op, gid, rest)
  return NS .. op .. " " .. gid .. (rest and (" " .. rest) or "")
end

-- ---- protocolo interno de prueba ----
-- El que prueba envia un "tst" por addon y por susurro normal; el rival
-- responde automaticamente un "tstok" por susurro normal. Si el mensaje
-- por addon llega, se ve en el log RX addon; si no, solo llega el susurro.
M.builtin.tst = function(sender, gid, rest)
  dbg("PRUEBA: recibido tst de %s (%s)", sender, tostring(rest))
  print(("[Chess] PRUEBA recibida de %s (via %s)").format(sender, rest))
  M.SendWhisper(sender, M.Envelope("tstok", gid, "tst"))
end

M.builtin.tstok = function(sender, gid, rest)
  print(("[Chess] PRUEBA CONFIRMADA: %s recibio tu mensaje").format(sender))
  dbg("PRUEBA: tstok de %s", sender)
end

function M.Test(target)
  if not target or target == "" then
    print("Uso: /chess teste NombreJugador")
    return
  end
  local tag = ("p%u"):format(GetTime())
  print(("[Chess] Enviando prueba de comunicacion a %s ...").format(target))
  M.Send(target, M.Envelope("tst", tag, "addon"))
  M.SendWhisper(target, M.Envelope("tst", tag, "whisper"))
  print("[Chess] Hecho. El rival debe ejecutar:  /chess teste " .. tostring(target))
end

function M.GetInfo()
  local me = pcall(UnitName, "player") and UnitName("player") or ""
  local realm = pcall(GetRealmName) and GetRealmName() or ""
  local hasEvent = false
  local ok, res = pcall(function()
    return frame:GetScript("OnEvent") ~= nil
  end)
  if ok then hasEvent = res end
  local apiFn = RegisterAddonMessagePrefix
  if type(apiFn) ~= "function" and C_ChatInfo then
    apiFn = C_ChatInfo.RegisterAddonMessagePrefix
  end
  return {
    me = me,
    realm = realm,
    registered = registered,
    prefixRegistered = prefixRegistered,
    apiAvailable = type(apiFn) == "function",
    queue = #queue,
    debug = debugOn,
    events = hasEvent,
  }
end

function M.dispatch(msg, sender)
  if type(msg) ~= "string" then return end
  if msg:sub(1, #NS) ~= NS then return end
  local body = msg:sub(#NS + 1)
  local op, gid, rest = body:match("^(%a+) (%S+) ?(.*)$")
  if not op then return end
  dbg("DISPATCH op=%s gid=%s rest=%q de %s", op, gid, rest or "", tostring(sender))
  local builtin = M.builtin[op]
  if builtin then
    pcall(builtin, sender, gid, rest)
  end
  local cb = M.callbacks[op]
  if cb then
    pcall(cb, sender, gid, rest)
  end
end