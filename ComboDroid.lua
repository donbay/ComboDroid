-- ComboDroid (Turtle/Vanilla)
-- Hidden on login; toggle with /combodroid
-- DRUIDS: optional auto-show in Cat Form (/combodroid auto to toggle)
-- Rectangular combo pips (bar-height), tight layout, smart target HP colors
-- Elegant close (hover ×, right-click anywhere, ESC closes)
-- Global 20% size reduction
-- Rectangles + gaps exactly span the bar width

print("ComboDroid loaded! Type /combodroid, or '/combodroid auto' for druid Cat-Form auto toggle.")

-- ===== Global scale (20% smaller) =====
local SCALE = 0.80
local function S(v) return v * SCALE end

-- ===== Frame basics =====
local frame = CreateFrame("Frame", "ComboDroidMainFrame_A9B3C7", UIParent)
frame:SetWidth(S(260)); frame:SetHeight(S(150))
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetResizable(true); frame:SetMinResize(S(180), S(120)); frame:SetMaxResize(S(600), S(400))
frame:Hide() -- start hidden

-- allow ESC to close (vanilla-safe)
table.insert(UISpecialFrames, frame:GetName())

-- move/resize (vanilla script handlers don't pass 'self')
frame:SetMovable(true); frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() frame:StartMoving(); frame.isMoving=true end)
frame:SetScript("OnDragStop",  function() frame:StopMovingOrSizing(); frame.isMoving=false end)
frame:SetScript("OnMouseUp", function()
  if frame.isMoving then frame:StopMovingOrSizing(); frame.isMoving=false end
  if arg1=="RightButton" then frame:Hide() end -- right-click to close
end)

local sizer = CreateFrame("Button", nil, frame)
sizer:SetWidth(S(16)); sizer:SetHeight(S(16))
sizer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
sizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
sizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
sizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
sizer:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
sizer:SetScript("OnMouseUp",   function() frame:StopMovingOrSizing() end)

-- elegant close glyph (hover to reveal)
local closeGlyph = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
closeGlyph:SetPoint("TOPRIGHT", frame, "TOPRIGHT", S(-4), S(-6))
closeGlyph:SetText("|cffff6666×|r")
closeGlyph:SetAlpha(0)
if closeGlyph.SetTextHeight then closeGlyph:SetTextHeight(S(16)) end

local closeHot = CreateFrame("Button", nil, frame)
closeHot:SetPoint("TOPRIGHT", frame, "TOPRIGHT", S(-2), S(-2))
closeHot:SetWidth(S(18)); closeHot:SetHeight(S(18))
closeHot:RegisterForClicks("AnyUp")
closeHot:SetScript("OnEnter", function() closeGlyph:SetAlpha(0.9) end)
closeHot:SetScript("OnLeave", function() closeGlyph:SetAlpha(0) end)
closeHot:SetScript("OnClick", function() frame:Hide() end)

-- ===== Helpers =====
local fmod = math.fmod or function(a,b) return a - math.floor(a/b)*b end
local function SetTexSize(tex, w, h)
  if tex.SetSize then tex:SetSize(S(w), S(h)) else tex:SetWidth(S(w)); tex:SetHeight(S(h)) end
end
local function SetAuraRotation(tex, angleRad)
  if tex.SetRotation then tex:SetRotation(angleRad)
  elseif tex.SetTexCoord then
    local c,s = math.cos(angleRad), math.sin(angleRad)
    local cx,cy,hx,hy = 0.5,0.5,0.5,0.5
    local ulx = cx + (-hx)*c - (-hy)*s ; local uly = cy + (-hx)*s + (-hy)*c
    local llx = cx + (-hx)*c - ( hy)*s ; local lly = cy + (-hx)*s + ( hy)*c
    local urx = cx + ( hx)*c - (-hy)*s ; local ury = cy + ( hx)*s + (-hy)*c
    local lrx = cx + ( hx)*c - ( hy)*s ; local lry = cy + ( hx)*s + ( hy)*c
    tex:SetTexCoord(ulx,uly, llx,lly, urx,ury, lrx,lry)
  end
end
local function ResetAuraRotation(tex)
  if tex.SetRotation then tex:SetRotation(0)
  elseif tex.SetTexCoord then tex:SetTexCoord(0,0, 0,1, 1,0, 1,1) end
end
local function TrySetTexture(tex, path)
  tex:SetTexture(path)
  local applied = tex.GetTexture and tex:GetTexture() or path
  return applied and applied ~= ""
end

-- ===== Texture paths =====
local IMG_GLOW     = "Interface\\AddOns\\ComboDroid\\images\\softglow"
local FALLBACK_RING= "Interface\\Buttons\\UI-Quickslot2"
local SQUARE       = "Interface\\Buttons\\WHITE8x8"

-- ===== Debug/Fake (optional) =====
local DEBUG=false
local FAKE=false
local function dprint(x) if DEBUG then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[ComboDroid]|r "..tostring(x)) end end

-- ===== Combo point shim =====
local function ReadComboPoints()
  if FAKE then local t=math.floor(GetTime()*1.7); return fmod(t,6) end
  local cp=0
  if GetComboPoints then
    local a=GetComboPoints("player","target"); if a and a>cp then cp=a end
    local b=GetComboPoints("target");          if b and b>cp then cp=b end
    local c=GetComboPoints();                  if c and c>cp then cp=c end
  end
  if UnitComboPoints then
    local d=UnitComboPoints("player");          if d and d>cp then cp=d end
    local e=UnitComboPoints("player","target"); if e and e>cp then cp=e end
  end
  return cp or 0
end

-- ===== Build UI (rogue/druid only) =====
local _, CLASS = UnitClass("player")
if CLASS=="ROGUE" or CLASS=="DRUID" then
  local lastCP=-1

  -- Bar sizes
  local BAR_WIDTH     = 200   -- base width (pre-scale)
  local TARGET_BAR_H  = 18
  local PLAYER_BAR_H  = 16

  -- Rect pip layout: bar-height rectangles, equal gaps, edge-aligned span
  local NUM_PIPS      = 5
  local EDGE_PAD      = 0     -- set to >0 if you want inset
  local GAP           = 4     -- gap between rectangles (pre-scale)
  local RECT_W        = (BAR_WIDTH - EDGE_PAD*2 - GAP*(NUM_PIPS-1)) / NUM_PIPS
  local RECT_H        = TARGET_BAR_H

  -- Target bars
  local targBG = frame:CreateTexture(nil,"ARTWORK")
  targBG:SetWidth(S(BAR_WIDTH)); targBG:SetHeight(S(TARGET_BAR_H))
  targBG:SetPoint("TOP", frame, "TOP", 0, S(-22))
  targBG:SetTexture(SQUARE); targBG:SetVertexColor(0.12,0.12,0.14,0.55); targBG:Show()

  local targSB = frame:CreateTexture(nil,"OVERLAY")
  targSB:SetWidth(S(BAR_WIDTH)); targSB:SetHeight(S(TARGET_BAR_H))
  targSB:SetPoint("TOPLEFT", targBG, "TOPLEFT", 0, 0)
  targSB:SetTexture("Interface/TargetingFrame/UI-StatusBar")
  targSB:SetVertexColor(0.2,0.8,0.3,0.85); targSB:Show()

  local targTxt = frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  targTxt:SetPoint("CENTER", targBG, "CENTER", 0, 0); targTxt:SetText("No target"); targTxt:Show()

  -- Pips frame (width = bar width, tight height)
  local pipFrame = CreateFrame("Frame", "ComboDroidPipFrame", frame)
  pipFrame:SetWidth(S(BAR_WIDTH)); pipFrame:SetHeight(S(RECT_H + 10)) -- room for glow
  pipFrame:SetPoint("TOP", targBG, "BOTTOM", 0, S(-4))
  pipFrame:SetFrameStrata("HIGH")
  pipFrame:SetFrameLevel(frame:GetFrameLevel()+10)
  pipFrame:Show()

  -- Rotating aura at max CP (match bar width)
  local aura = pipFrame:CreateTexture(nil,"BACKGROUND")
  if not TrySetTexture(aura, IMG_GLOW) then aura:SetTexture(FALLBACK_RING) end
  aura:SetBlendMode("ADD")
  aura:SetPoint("CENTER", pipFrame, "CENTER", 0, 0)
  SetTexSize(aura, BAR_WIDTH, 68)
  aura:SetVertexColor(1,1,1,0); aura:Hide()

  -- Rainbow colors (R,O,Y,G,B)
  local RAINBOW = {
    {1.00, 0.20, 0.20},
    {1.00, 0.55, 0.10},
    {1.00, 0.95, 0.25},
    {0.30, 1.00, 0.55},
    {0.40, 0.75, 1.00},
  }

  -- Rectangular pips: left -> right, edge-aligned with gaps
  local pips = {}
  for i=1,NUM_PIPS do
    local leftX = - (BAR_WIDTH/2) + EDGE_PAD + (i-1)*(RECT_W + GAP)
    local centerX = leftX + RECT_W/2

    local rect = pipFrame:CreateTexture(nil, "ARTWORK")
    rect:SetTexture(SQUARE)
    rect:SetBlendMode("BLEND")
    rect:SetPoint("CENTER", pipFrame, "CENTER", S(centerX), 0)
    rect:SetWidth(S(RECT_W)); rect:SetHeight(S(RECT_H))
    rect:SetVertexColor(0.70, 0.72, 0.76, 0.80) -- inactive color
    rect:Show()

    local glow = pipFrame:CreateTexture(nil, "OVERLAY")
    if not TrySetTexture(glow, IMG_GLOW) then glow:SetTexture(FALLBACK_RING) end
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER", rect, "CENTER", 0, 0)
    SetTexSize(glow, RECT_W + 10, RECT_H + 14)
    glow:SetVertexColor(1,1,1,0.0); glow:Hide()

    local phase = (i-1) * 0.8
    pips[i] = {rect=rect, glow=glow, phase=phase}
  end

  -- Player bar (tight gap)
  local pbg = frame:CreateTexture(nil,"ARTWORK")
  pbg:SetWidth(S(BAR_WIDTH)); pbg:SetHeight(S(PLAYER_BAR_H))
  pbg:SetPoint("TOP", pipFrame, "BOTTOM", 0, S(-6))
  pbg:SetTexture(SQUARE); pbg:SetVertexColor(0.10,0.10,0.14,0.55); pbg:Show()

  local psb = frame:CreateTexture(nil,"OVERLAY")
  psb:SetWidth(S(BAR_WIDTH)); psb:SetHeight(S(PLAYER_BAR_H))
  psb:SetPoint("TOPLEFT", pbg, "TOPLEFT", 0, 0)
  psb:SetTexture("Interface/TargetingFrame/UI-StatusBar")
  psb:SetVertexColor(0.2,0.85,0.2,0.85); psb:Show()

  local ptxt = frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  ptxt:SetPoint("CENTER", pbg, "CENTER", 0, 0); ptxt:SetText("Player: 0/0"); ptxt:Show()

  -- ===== Animation state =====
  local auraAlpha=0; local auraRot=0; local rotating=false
  local lastUpdate=nil
  local AURA_ROT_RATE=20
  local GLOW_MIN=0.25; local GLOW_MAX=0.65; local GLOW_SPEED=1.6

  local function dimByEnergy()
    local _, class = UnitClass("player")
    local req = (class=="ROGUE") and 35 or 40
    local enough = UnitMana("player") >= req
    local a = enough and 1 or 0.7
    for i=1,NUM_PIPS do
      pips[i].rect:SetAlpha(a)
      pips[i].glow:SetAlpha(enough and 1 or 0.6)
    end
  end

  local function applyCP(n)
    for i=1,NUM_PIPS do
      if i <= n then
        local c = RAINBOW[i]
        pips[i].rect:SetVertexColor(c[1], c[2], c[3], 1.0)   -- active uses rainbow color
        pips[i].glow:SetVertexColor(c[1], c[2], c[3], 0.8)
        pips[i].glow:Show()
      else
        pips[i].rect:SetVertexColor(0.25, 0.27, 0.30, 0.65) -- inactive
        pips[i].glow:Hide()
      end
    end
  end

  local function handleAura(n)
    if n==NUM_PIPS then
      aura:Show()
      if auraAlpha<0.5 then auraAlpha=math.min(auraAlpha+0.02,0.5); aura:SetAlpha(auraAlpha) end
      if not rotating then
        rotating=true; lastUpdate=nil
        frame:SetScript("OnUpdate", function()
          local now=GetTime(); local dt=0
          if lastUpdate then dt=now-lastUpdate end
          lastUpdate=now
          -- Breathing glow for active pips
          for i=1,NUM_PIPS do
            local c = RAINBOW[i]
            local t = now*GLOW_SPEED + pips[i].phase
            local s = (math.sin(t) + 1) * 0.5
            local a = GLOW_MIN + (GLOW_MAX - GLOW_MIN)*s
            if pips[i].glow:IsShown() then
              pips[i].glow:SetVertexColor(c[1], c[2], c[3], a)
            end
          end
          -- Rotate aura at max CP
          auraRot = fmod(auraRot + AURA_ROT_RATE*(dt or 0), 360)
          SetAuraRotation(aura, math.rad(auraRot))
        end)
      end
    else
      if auraAlpha>0 then auraAlpha=math.max(auraAlpha-0.03,0); aura:SetAlpha(auraAlpha); if auraAlpha<=0 then aura:Hide() end end
      rotating=false; auraRot=0; ResetAuraRotation(aura)
      frame:SetScript("OnUpdate", function()
        local now=GetTime()
        for i=1,NUM_PIPS do
          if pips[i].glow:IsShown() then
            local c = RAINBOW[i]
            local t = now*GLOW_SPEED + pips[i].phase
            local s = (math.sin(t) + 1) * 0.5
            local a = GLOW_MIN + (GLOW_MAX - GLOW_MIN)*s
            pips[i].glow:SetVertexColor(c[1], c[2], c[3], a)
          end
        end
      end)
    end
  end

  -- smart target HP color (friendly=green, neutral=yellow, hostile/combat=red)
  local function colorTargetBar(unit)
    local r,g,b = 0.6,0.6,0.6
    if UnitAffectingCombat(unit) then
      r,g,b = 1,0,0
    else
      local reaction = UnitReaction("player", unit)
      if reaction then
        if reaction >= 5 or UnitIsFriend("player", unit) then
          r,g,b = 0.2,0.8,0.2
        elseif reaction == 4 then
          r,g,b = 1,1,0.2
        else
          r,g,b = 1,0.1,0.1
        end
      end
    end
    targSB:SetVertexColor(r,g,b,0.85)
  end

  local function updateCP(force)
    local cp = ReadComboPoints()
    if force or cp~=lastCP then
      applyCP(cp); handleAura(cp); dimByEnergy()
      lastCP = cp
    end
  end

  local function updateHP()
    local u="target"
    if UnitExists(u) and not UnitIsDead(u) then
      local hp,maxhp=UnitHealth(u),UnitHealthMax(u)
      local pct=(maxhp>0) and (hp/maxhp) or 0
      targSB:SetWidth(S(BAR_WIDTH*pct)); targSB:Show()
      targTxt:SetText("Health: "..hp.."/"..maxhp)
      colorTargetBar(u)
    else
      targSB:SetWidth(S(1)); targSB:Hide(); targTxt:SetText("No target")
    end
    local php,pmax=UnitHealth("player"),UnitHealthMax("player")
    psb:SetWidth(S(BAR_WIDTH*((pmax>0) and (php/pmax) or 0))); psb:Show()
    ptxt:SetText("Player: "..php.."/"..pmax)
  end

  -- ===== Druid Cat Form auto-visibility =====
  local AutoCatEnabled = true  -- default ON; toggle with /combodroid auto

  local function InCatForm()
    -- Prefer shapeshift info (vanilla-safe)
    if GetNumShapeshiftForms and GetShapeshiftFormInfo then
      local n = GetNumShapeshiftForms()
      for i=1,(n or 0) do
        local icon, name, active = GetShapeshiftFormInfo(i)
        if active then
          if (name and string.find(string.lower(name), "cat"))
             or (icon and string.find(string.lower(icon), "catform")) then
            return true
          end
        end
      end
    end
    -- Fallback: scan buffs for Cat Form texture
    if UnitBuff then
      local i=1
      while true do
        local tex = UnitBuff("player", i)
        if not tex then break end
        local t = string.lower(tex)
        if string.find(t, "ability_druid_catform") then return true end
        i=i+1
      end
    end
    return false
  end

  local function refreshAll()
    updateCP(true); updateHP(); dimByEnergy()
  end

  local function UpdateVisibilityByForm()
    if CLASS == "DRUID" and AutoCatEnabled then
      if InCatForm() then
        if not frame:IsShown() then frame:Show(); refreshAll() end
      else
        if frame:IsShown() then frame:Hide() end
      end
    end
  end

  -- ===== Events =====
  frame:RegisterEvent("PLAYER_COMBO_POINTS")
  frame:RegisterEvent("UNIT_COMBO_POINTS")
  frame:RegisterEvent("PLAYER_TARGET_CHANGED")
  frame:RegisterEvent("UNIT_FACTION")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("UNIT_HEALTH")
  frame:RegisterEvent("UNIT_ENERGY"); frame:RegisterEvent("UNIT_MANA"); frame:RegisterEvent("UNIT_RAGE")
  -- Form change signals (vanilla-safe mix)
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
  frame:RegisterEvent("PLAYER_AURAS_CHANGED") -- broad fallback

  frame:SetScript("OnEvent", function()
    -- Always react to form changes for druids when AutoCatEnabled
    if CLASS=="DRUID" and AutoCatEnabled and (
        event=="PLAYER_ENTERING_WORLD" or
        event=="UPDATE_SHAPESHIFT_FORM" or
        event=="UPDATE_SHAPESHIFT_FORMS" or
        event=="PLAYER_AURAS_CHANGED"
      ) then
      UpdateVisibilityByForm()
    end

    -- Skip updates if hidden
    if not frame:IsShown() then return end

    if event=="PLAYER_TARGET_CHANGED" or event=="UNIT_FACTION" then
      updateCP(true); updateHP()
    elseif event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_REGEN_ENABLED" then
      updateHP()
    elseif event=="UNIT_HEALTH" and (arg1=="target" or arg1=="player") then
      updateHP()
    elseif event=="UNIT_ENERGY" or event=="UNIT_MANA" or event=="UNIT_RAGE" then
      if arg1=="player" then dimByEnergy() end
    else
      updateCP(); updateHP()
    end
  end)

  -- ===== Slash command: toggle & auto =====
  local function msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[ComboDroid]|r "..tostring(text))
  end

  function ComboDroid_SlashCommandHandler(raw)
    local msgText = string.lower(tostring(raw or ""))

    if msgText == "debug" then
      DEBUG = not DEBUG; msg("debug "..(DEBUG and "ON" or "OFF"))

    elseif msgText == "fake" then
      FAKE = not FAKE; msg("fake CP "..(FAKE and "ON" or "OFF"))

    elseif string.sub(msgText, 1, 4) == "auto" then
      -- /combodroid auto [on|off]
      local arg = string.gsub(string.sub(msgText, 5) or "", "^%s+", "")
      if arg == "on" then
        AutoCatEnabled = true
        msg("Auto Cat Form visibility: ON")
      elseif arg == "off" then
        AutoCatEnabled = false
        msg("Auto Cat Form visibility: OFF")
      else
        AutoCatEnabled = not AutoCatEnabled
        msg("Auto Cat Form visibility toggled: "..(AutoCatEnabled and "ON" or "OFF"))
      end
      UpdateVisibilityByForm()

    else
      if frame:IsShown() then
        frame:Hide()
      else
        frame:Show(); refreshAll()
      end
      if CLASS=="DRUID" and AutoCatEnabled then
        msg("Manual toggle set; next form change will re-apply auto behavior ("..(InCatForm() and "Cat" or "Not Cat")..").")
      end
    end
  end

  SLASH_COMBODROID1="/combodroid"; SlashCmdList["COMBODROID"]=ComboDroid_SlashCommandHandler

else
  -- Non-combo classes: minimal toggle
  function ComboDroid_SlashCommandHandler(msg)
    if frame:IsShown() then frame:Hide() else frame:Show() end
  end
  SLASH_COMBODROID1="/combodroid"; SlashCmdList["COMBODROID"]=ComboDroid_SlashCommandHandler
end
