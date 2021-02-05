-- Addon Controls --

PrismaticWarning = PrismaticWarning or {
  name = "PrismaticWarning",
  author = "@Pretz333 (NA)",
  version = "0.0.1",
  variableVersion = 1,
  defaults = {
    left = GuiRoot:GetWidth()/2,
    top  = (2*GuiRoot:GetHeight()/3),
    refreshRate = 1000,
    hideOnScreenAlert = false,
    hideOnScreenAlertInCombat = true,
    isLocked = false,
    fontName = "EsoUI/Common/Fonts/Univers67.otf",
    fontSize = 48,
    infoFontSize = 25,
    fontOutline = "thick-outline",
    fontColor = {255, 255, 255, 255},
    alertToChat = false,
    alertOnlyOnVet = false,
    alertInDungeons = true,
    alertInPartialDungeons = true,
    alertInTrials = true,
    alertInArenas = true,
    alertIfTank = false,
    alertIfHeal= false,
    alertIfMagDD = true,
    alertIfStamDD = true,
    autoSwapTo = GetString(PRISMATICWARNING_MENU_DONT),
    debugAlerts = false,
  },
}

function PrismaticWarning.OnAddOnLoaded(_, addonName)
  if addonName ~= PrismaticWarning.name then return end

  EVENT_MANAGER:UnregisterForEvent(PrismaticWarning.name, EVENT_ADD_ON_LOADED)
  PrismaticWarning.savedVariables = ZO_SavedVars:NewAccountWide("PrismaticWarningSavedVariables", PrismaticWarning.variableVersion, nil, PrismaticWarning.defaults, nil, "$InstallationWide")
  PrismaticWarning.SettingsWindow()
  PrismaticWarning.role = GetSelectedLFGRole()
  PrismaticWarning.settingsBypass = false

  if not PrismaticWarning.savedVariables.hideOnScreenAlert then
    PrismaticWarning.InitializeUI()
  end

  if PrismaticWarning.savedVariables.autoSwapTo == GetString(PRISMATICWARNING_MENU_FRONT_BAR) then
    PrismaticWarning.equipSlot = EQUIP_SLOT_MAIN_HAND
    PrismaticWarning.poisonSlot = EQUIP_SLOT_POISON
  elseif PrismaticWarning.savedVariables.autoSwapTo == GetString(PRISMATICWARNING_MENU_BACK_BAR) then
    PrismaticWarning.equipSlot = EQUIP_SLOT_BACKUP_MAIN
    PrismaticWarning.poisonSlot = EQUIP_SLOT_BACKUP_POISON
  end

  if PrismaticWarning.isWeaponPrismatic(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN) or PrismaticWarning.isWeaponPrismatic(BAG_WORN, EQUIP_SLOT_MAIN_HAND) then
    PrismaticWarning.isPrismaticSlotted = true
  else
    PrismaticWarning.isPrismaticSlotted = false
  end

  EVENT_MANAGER:RegisterForEvent(PrismaticWarning.name .. "Role", EVENT_GROUP_MEMBER_ROLE_CHANGED, PrismaticWarning.roleCheck)
  EVENT_MANAGER:RegisterForEvent(PrismaticWarning.name .. "Kick", EVENT_INSTANCE_KICK_TIME_UPDATE, PrismaticWarning.kicking)
  EVENT_MANAGER:RegisterForEvent(PrismaticWarning.name .. "Load", EVENT_PLAYER_ACTIVATED, PrismaticWarning.sorter)
  EVENT_MANAGER:RegisterForEvent(PrismaticWarning.name .. "Reset", EVENT_ACTIVITY_FINDER_STATUS_UPDATE, PrismaticWarning.OnActivityFinderStatusUpdate)
  EVENT_MANAGER:RegisterForEvent(PrismaticWarning.name .. "Gear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, PrismaticWarning.gearChanged)
  EVENT_MANAGER:AddFilterForEvent(PrismaticWarning.name .. "Gear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
  EVENT_MANAGER:AddFilterForEvent(PrismaticWarning.name .. "Gear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
end

function PrismaticWarning.OnActivityFinderStatusUpdate(_, result) -- Thank you @code65536 (stolen from dungeon timer)
	-- Covers the case where a group requeues directly into the same dungeon
	if (result == ACTIVITY_FINDER_STATUS_FORMING_GROUP or result == ACTIVITY_FINDER_STATUS_READY_CHECK) then
		PrismaticWarning.dungeonComplete()
	end
end

function PrismaticWarning.kicking()
  PrismaticWarning.zoneId = nil -- to fix the case where the player ports directly from the old instance into the new instance
end

function PrismaticWarning.roleCheck(_, unitTag, role)
  if AreUnitsEqual(unitTag, 'player') then
    PrismaticWarning.role = role
    PrismaticWarning.settingsBypass = true
    PrismaticWarning.sorter()
  end
end

function PrismaticWarning.sorter()
  local zoneId = GetZoneId(GetUnitZoneIndex('player'))
  local shouldWatch, zoneIsArena, zoneIsTrial, zoneIsPartialDungeon, zoneIsDungeon

  if PrismaticWarning.zoneId ~= zoneId then
    PrismaticWarning.zoneId = zoneId
    PrismaticWarning.dungeonComplete()
  elseif PrismaticWarning.settingsBypass then
    PrismaticWarning.settingsBypass = false
    PrismaticWarning.dungeonComplete() -- in case shouldWatch is now false
  else
    return -- already checked this zone and settings haven't changed
  end

  if PrismaticWarning.zones[zoneId] ~= nil then
    if PrismaticWarning.zones[zoneId][4] then
      zoneIsPartialDungeon = true
      zoneIsDungeon = true
    elseif PrismaticWarning.zones[zoneId][3] then
      zoneIsDungeon = true
    elseif PrismaticWarning.zones[zoneId][2] then
      zoneIsTrial = true
    elseif PrismaticWarning.zones[zoneId][1] then
      zoneIsArena = true
    end
  end

  if zoneIsDungeon or zoneIsTrial or zoneIsArena then
    if PrismaticWarning.savedVariables.alertOnlyOnVet and (GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_VETERAN) then
      PrismaticWarning.debugAlert("Doesn't want alerts on normal difficulty")
    elseif (PrismaticWarning.role == LFG_ROLE_TANK) and (not PrismaticWarning.savedVariables.alertIfTank) then
      PrismaticWarning.debugAlert("Doesn't want alerts on a tank")
    elseif (PrismaticWarning.role == LFG_ROLE_HEAL) and (not PrismaticWarning.savedVariables.alertIfHeal) then
      PrismaticWarning.debugAlert("Doesn't want alerts on a healer")
    elseif (PrismaticWarning.role == LFG_ROLE_DPS) and (not PrismaticWarning.savedVariables.alertIfMagDD) and (GetPlayerStat(STAT_MAGICKA_MAX, STAT_BONUS_OPTION_APPLY_BONUS) > GetPlayerStat(STAT_STAMINA_MAX, STAT_BONUS_OPTION_APPLY_BONUS)) then
      PrismaticWarning.debugAlert("Doesn't want alerts on a MagDPS")
    elseif (PrismaticWarning.role == LFG_ROLE_DPS) and (not PrismaticWarning.savedVariables.alertIfStamDD) and (GetPlayerStat(STAT_STAMINA_MAX, STAT_BONUS_OPTION_APPLY_BONUS) > GetPlayerStat(STAT_MAGICKA_MAX, STAT_BONUS_OPTION_APPLY_BONUS)) then
      PrismaticWarning.debugAlert("Doesn't want alerts on a StamDPS")
    elseif zoneIsTrial and (not PrismaticWarning.savedVariables.alertInTrials) then
      PrismaticWarning.debugAlert("Doesn't want alerts in a trial")
    elseif zoneIsArena and (not PrismaticWarning.savedVariables.alertInArenas) then
      PrismaticWarning.debugAlert("Doesn't want alerts in an arena")
    elseif zoneIsDungeon and (not PrismaticWarning.savedVariables.alertInDungeons) then
      PrismaticWarning.debugAlert("Doesn't want alerts in dungeons")
    elseif zoneIsPartialDungeon and (not PrismaticWarning.savedVariables.alertInPartialDungeons) then
      PrismaticWarning.debugAlert("Doesn't want alerts in a partial dungeon, converted to a nungeon")
      EVENT_MANAGER:RegisterForUpdate(PrismaticWarning.name, PrismaticWarning.savedVariables.refreshRate, PrismaticWarning.NoneDungeon)
    else
      shouldWatch = true
    end
  end

  if shouldWatch then
    if PrismaticWarning.usesDeathCounting[zoneId] then
      EVENT_MANAGER:RegisterForEvent(PrismaticWarning.name .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, PrismaticWarning.bossDeathCounter)
      EVENT_MANAGER:AddFilterForEvent(PrismaticWarning.name .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "boss1")
    end
    EVENT_MANAGER:RegisterForUpdate(PrismaticWarning.name, PrismaticWarning.savedVariables.refreshRate, PrismaticWarning.zones[zoneId][5])
  end
end

-- Dungeon Watchers --

function PrismaticWarning.AA() -- alerts slightly late, as in not on pads to foundatin atro
  local _, y = PrismaticWarning.currentLocation()
  local mapId = GetCurrentMapId()
  
  if mapId == 642 and ((y > 25 and y < 43) or (y > 52 and y < 75)) then
    PrismaticWarning.alerter(true)
  elseif mapId == 641 or mapId == 640 then
    PrismaticWarning.alerter(false)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.BC1()
  local x, y = PrismaticWarning.currentLocation()
  if x < 38 and y > 32 then
    PrismaticWarning.alerter(false)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(true)
  end
end

function PrismaticWarning.BC2()
  local x, y = PrismaticWarning.currentLocation()
  if (x > 71 and y > 69) or (x < 48 and y > 58 and y < 73) or (y < 29 and x > 40) then
    PrismaticWarning.alerter(false)
  elseif x < 43 and y < 20 then
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(true)
  end
end

function PrismaticWarning.BHH()  
  -- If someone in group is doing quest, adds after roost mother all count (add " or (y < 30 and x < 55 and group member doing quest) to "y < 10")
  -- I'm currently ignoring that since I don't know how to tell if someone in group talked to Shifty Tom after the Atarus kill
  
  local _, y = PrismaticWarning.currentLocation()
  if GetCurrentMapId() == 346 and y < 55 then
    PrismaticWarning.alerter(true)
  elseif y < 10 then
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.BRF() -- bugged, alerts before it should and after it should
  local _, y = PrismaticWarning.currentLocation()
  if GetCurrentMapId() == 1309 and y > 55 and not DoesUnitExist('boss2') and not DoesUnitExist('boss3') then
    PrismaticWarning.alerter(true)
    -- no unregister in case they kill boss2 and boss3, then wipe
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.COA1()
  local x, y = PrismaticWarning.currentLocation()
  if x > 50 then
    PrismaticWarning.alerter(false)
    PrismaticWarning.dungeonComplete()
  -- elseif x < 22 and y > 58 then -- Golor technically isn't an undead/daedra, but he dies so quickly it'll slow groups down if they deslot, then slot the prismatic
    -- PrismaticWarning.alerter(false)
  else
    PrismaticWarning.alerter(true)
  end
end

function PrismaticWarning.COS() -- double check alerts
  local x, y = PrismaticWarning.currentLocation()
  local mapId = GetCurrentMapId()
  
  if mapId == 1134 and ((y > 60 and x > 65) or (x < 34 and y < 65)) then
    PrismaticWarning.alerter(true)
  elseif mapId == 1135 and y > 53 then -- Replace "y > 53" with "dranos is dead" if that's a thing without needed to register for combat events. Gives user more time to slot the weapon
    PrismaticWarning.alerter(true)
  elseif mapId == 1137 then
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.CT()
  local x, y = PrismaticWarning.currentLocation()
  local mapId = GetCurrentMapId()
  
  if mapId == 1823 and x < 38 or y < 38 then
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.Direfrost()
  -- no dungeonComplete since it's possible to do this dungeon basically backwards
  
  local x, y = PrismaticWarning.currentLocation()
  if (GetCurrentMapId() == 162) or (x > 74 and y > 40) then
    PrismaticWarning.alerter(false)
  elseif y < 67 and y > 10 then
    PrismaticWarning.alerter(true)
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.DOM()
  local x, y = PrismaticWarning.currentLocation()
  if GetCurrentMapId() == 1596 and x < 51 and y < 37 then
    if x > 38 and y > 24 then
      PrismaticWarning.alerter(true)
    else
      PrismaticWarning.alerter(false)
    end
  else
    PrismaticWarning.alerter(false)
    PrismaticWarning.dungeonComplete()
  end
end

function PrismaticWarning.DSA()
  local mapId = GetCurrentMapId()
  if mapId == 689 or mapId == 691 then
    PrismaticWarning.alerter(true)
  elseif mapId == 692 then
    PrismaticWarning.alerter(false)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.EH2() -- uses safe kill counting
  local x, y = PrismaticWarning.currentLocation()
  if GetCurrentMapId() == 1146 or (PrismaticWarning.counter == 1 and x > 65 and y > 55 and y < 75) then
    PrismaticWarning.alerter(false)
  elseif y < 33 and x < 55 then
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(true)
  end
end

function PrismaticWarning.FG2()
  local x, y = PrismaticWarning.currentLocation()
  
  if GetCurrentMapId() == 1151 or x < 34 or (y > 46 and y < 50 and x < 39) then
    PrismaticWarning.alerter(false)
    PrismaticWarning.dungeonComplete()
  elseif y > 38 and y < 50 and x < 45 then
    PrismaticWarning.alerter(true)
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.FH()
  local x, y = PrismaticWarning.currentLocation()
  local mapId = GetCurrentMapId()
  if mapId == 1322 then
    if x > 59 and y > 78 then
      PrismaticWarning.alerter(false)
      PrismaticWarning.dungeonComplete()
    else
      PrismaticWarning.alerter(true)
    end
  elseif x < 30 and y > 62 then
    PrismaticWarning.alerter(true)
  elseif mapId == 1323 then
    PrismaticWarning.alerter(false)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.FullDungeon()
  PrismaticWarning.alerter(true)
  if PrismaticWarning.isPrismaticSlotted then
    PrismaticWarning.dungeonComplete()
  end
end

function PrismaticWarning.HRC() -- uses safe kill counting
  -- assuming Ra Kotu spawns in only after the flame-shapers have been aggroed
  
  -- local _, y = PrismaticWarning.currentLocation()
  -- local mapId = GetCurrentMapId()
  -- if mapId == 616 or PrismaticWarning.counter > 0 or y < ## then
    -- PrismaticWarning.alerter(false)
       PrismaticWarning.dungeonComplete()
  -- elseif mapId == (through first door) and y > ## then
    -- if DoesUnitExist('boss1') then
      -- PrismaticWarning.alerter(true)
    -- end
  -- else
    -- PrismaticWarning.alerter(false)
  -- end
end

function PrismaticWarning.KA()
  if GetCurrentMapId() == 1806 then -- 1807 is the 2nd floor, 1808 is the bottom floor
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.MA()
  local mapId = GetCurrentMapId()
  if mapId == 988 or mapId == 973 then
    PrismaticWarning.alerter(true)
  elseif mapId == 986 then
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.MOL()
  local x = PrismaticWarning.currentLocation()
  
  if GetCurrentMapId()== 1000 and x < 75 then
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.NoneDungeon()
  PrismaticWarning.alerter(false)
  if not PrismaticWarning.isPrismaticSlotted then
    PrismaticWarning.dungeonComplete()
  end
end

function PrismaticWarning.Spindle1()
  local _, y = PrismaticWarning.currentLocation()
  if y > 68 then
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.Spindle2()
  local x, y = PrismaticWarning.currentLocation()
  if x > 70 or y > 55 then
    PrismaticWarning.alerter(true)
    PrismaticWarning.dungeonComplete()
  elseif x > 52 and y < 33 then
    PrismaticWarning.alerter(false)
  else
    PrismaticWarning.alerter(true)
  end
end

function PrismaticWarning.Tempest()
  local x, y = PrismaticWarning.currentLocation()
  if y < 39 and y > 30 and x > 78 and x < 85 then
    PrismaticWarning.alerter(true)
  elseif GetCurrentMapId() == 597 then
    PrismaticWarning.alerter(false)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.UHG()
  local _, y = PrismaticWarning.currentLocation()
  local mapId = GetCurrentMapId()
  
  if mapId == 1769 then
    PrismaticWarning.alerter(true)
  elseif mapId == 1796 and y > 75 then
    PrismaticWarning.alerter(false)
    PrismaticWarning.dungeonComplete()
  else
    PrismaticWarning.alerter(false)
  end
end

function PrismaticWarning.VH()
  local mapId = GetCurrentMapId()
  
  if mapId == 1843 or mapId == 1845 then
    PrismaticWarning.alerter(true)
  elseif mapId == 1844 then
    PrismaticWarning.alerter(false)
  elseif mapId == 1846 then
    PrismaticWarning.dungeonComplete()
    PrismaticWarning.alerter(false)
  end
end

PrismaticWarning.zones = {
  -- [zoneId] = {isArena, isTrial, isNotAPartialDungeon, isAPartialDungeon, sortFunc},
  -- use string matching to a one letter code (a, t, d, p) in sorter() instead of the 3 falses, 1 true?
  [11] = {false, false, true, false, PrismaticWarning.FullDungeon}, -- VOM
  [22] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- Volenfell
  [31] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- Selene's
  [38] = {false, false, false, true, PrismaticWarning.BHH},
  [63] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- DC1
  [64] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- Blessed Crucible
  [126] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- EH1
  [130] = {false, false, true, false, PrismaticWarning.FullDungeon}, -- COH1
  [131] = {false, false, false, true, PrismaticWarning.Tempest}, 
  [144] = {false, false, false, true, PrismaticWarning.Spindle1}, 
  [146] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- Wayrest 1
  [148] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- Arx Corinium
  [176] = {false, false, false, true, PrismaticWarning.COA1}, 
  [283] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- FG1
  [380] = {false, false, false, true, PrismaticWarning.BC1}, 
  [449] = {false, false, false, true, PrismaticWarning.Direfrost}, 
  [635] = {true, false, false, false, PrismaticWarning.DSA}, 
  [636] = {false, true, false, false, PrismaticWarning.HRC}, 
  [638] = {false, true, false, false, PrismaticWarning.AA}, 
  [639] = {false, true, false, false, PrismaticWarning.NoneDungeon}, -- SO
  [677] = {true, false, false, false, PrismaticWarning.MA}, 
  [678] = {false, false, true, false, PrismaticWarning.FullDungeon}, --ICP
  [681] = {false, false, true, false, PrismaticWarning.FullDungeon}, --COA2
  [688] = {false, false, true, false, PrismaticWarning.FullDungeon}, --WGT
  [725] = {false, true, false, false, PrismaticWarning.MOL}, 
  [843] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- ROM
  [848] = {false, false, false, true, PrismaticWarning.COS}, 
  [930] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- DC2
  [931] = {false, false, false, true, PrismaticWarning.EH2}, 
  [932] = {false, false, true, false, PrismaticWarning.FullDungeon}, -- COH2
  [933] = {false, false, true, false, PrismaticWarning.FullDungeon}, -- Wayrest 2
  [934] = {false, false, false, true, PrismaticWarning.FG2}, 
  [935] = {false, false, false, true, PrismaticWarning.BC2}, 
  [936] = {false, false, false, true, PrismaticWarning.Spindle2}, 
  [973] = {false, false, false, true, PrismaticWarning.BRF}, 
  [974] = {false, false, false, true, PrismaticWarning.FH}, 
  [975] = {false, true, false, false, PrismaticWarning.NoneDungeon}, -- HOF
  [1000] = {false, true, false, false, PrismaticWarning.NoneDungeon}, -- Asylum
  [1009] = {false, false, true, false, PrismaticWarning.FullDungeon}, -- FL
  [1010] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- SCP
  [1051] = {false, true, false, false, PrismaticWarning.NoneDungeon}, -- CR
  [1052] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- MHK
  [1055] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- MOS
  [1080] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- Frostvault
  [1082] = {true, false, false, false, PrismaticWarning.NoneDungeon}, -- BRP
  [1081] = {false, false, false, true, PrismaticWarning.DOM}, 
  [1121] = {false, true, false, false, PrismaticWarning.NoneDungeon}, -- SS
  [1122] = {false, false, true, false, PrismaticWarning.FullDungeon}, -- MGF
  [1123] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- LOM
  [1152] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- Icereach
  [1153] = {false, false, false, true, PrismaticWarning.UHG},  
  [1196] = {false, true, false, false, PrismaticWarning.KA},
  [1197] = {false, false, true, false, PrismaticWarning.NoneDungeon}, -- Stone Garden
  [1201] = {false, false, false, true, PrismaticWarning.CT},
  [1227] = {true, false, false, false, PrismaticWarning.VH},
}

PrismaticWarning.usesDeathCounting = {
  [636] = true, --HRC
  [931] = true, --EH2
}

-- Alert Controllers --

function PrismaticWarning.alerter(shouldSlot)
  -- Could add " and PrismaticWarning.savedVariables.hideOnScreenAlertInCombat". It adds an extra check but would pop up the alert if stuck in combat
  if IsUnitInCombat('player') then return end
  
  if PrismaticWarning.lastCall ~= shouldSlot then
    PrismaticWarning.lastCall = shouldSlot
    
    local whatToDo
    
    if shouldSlot and not PrismaticWarning.isPrismaticSlotted then
      whatToDo = GetString(PRISMATICWARNING_SLOT_NOW)
      PrismaticWarning.alert = true
    elseif not shouldSlot and PrismaticWarning.isPrismaticSlotted then
      whatToDo = GetString(PRISMATICWARNING_DESLOT_NOW)
      PrismaticWarning.alert = true
    else
      whatToDo = GetString(PRISMATICWARNING_KEEP_AS_IS)
      PrismaticWarning.alert = false
    end
    
    PrismaticWarning.alertVisible(PrismaticWarning.alert, whatToDo)
    PrismaticWarning.addChatMessage(whatToDo)
    
    if PrismaticWarning.alert then
      PrismaticWarning.slotter(shouldSlot)
    end
  end
end

function PrismaticWarning.bossDeathCounter(_, _, isDead)
  if isDead then
    PrismaticWarning.counter = PrismaticWarning.counter + 1
    PrismaticWarning.debugAlert("Counter at " .. PrismaticWarning.counter)
  end
end

function PrismaticWarning.currentLocation()
  local x, y = GetMapPlayerPosition('player')
  
  if PrismaticWarning.zoneId ~= GetZoneId(GetCurrentMapZoneIndex()) then -- if they are viewing a different zone in the map 
    x = PrismaticWarning.x
    y = PrismaticWarning.y
  else
    PrismaticWarning.x = x
    PrismaticWarning.y = y
  end
  
  return x * 100, y * 100
end

function PrismaticWarning.dungeonComplete()
  PrismaticWarning.debugAlert("Complete")
  EVENT_MANAGER:UnregisterForEvent(PrismaticWarning.name .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED)
  EVENT_MANAGER:UnregisterForUpdate(PrismaticWarning.name)
  PrismaticWarning.counter = 0
  PrismaticWarning.lastCall = nil
  PrismaticWarning.alert = false
  PrismaticWarning.alertVisible(false, "")
end

function PrismaticWarning.gearChanged(_, bag, slot) 
  if slot == EQUIP_SLOT_BACKUP_MAIN or slot == EQUIP_SLOT_MAIN_HAND then
    PrismaticWarning.lastCall = nil -- to allow alerter to check if they slotted the right weapon
    PrismaticWarning.alertVisible(false, "")
    PrismaticWarning.updateUnequippedItemId()
    
    if PrismaticWarning.isWeaponPrismatic(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN) or PrismaticWarning.isWeaponPrismatic(BAG_WORN, EQUIP_SLOT_MAIN_HAND) then
      PrismaticWarning.isPrismaticSlotted = true
    else
      PrismaticWarning.isPrismaticSlotted = false
    end
  end
end

-- Chat and Gear --

function PrismaticWarning.isWeaponPrismatic(bag, slot)
  if GetItemLinkAppliedEnchantId(GetItemLink(bag, slot, LINK_STYLE_DEFAULT)) == 147 then -- covers CP160 and CP150 gold glyphs, at least
    return true
  else
    return false
  end
end

function PrismaticWarning.slotter(slotAPrismatic)
-- * CompareId64s(*id64* _firstId_, *id64* _secondId_)
-- ** _Returns:_ *integer* _result_

  if PrismaticWarning.savedVariables.autoSwapTo == GetString(PRISMATICWARNING_MENU_DONT) then return end

  local itemSlot, unequippedItemId
  local numSlots = GetBagSize(BAG_BACKPACK)

  if PrismaticWarning.prismaticItemId == nil then
    for slot = 0, numSlots do
      if GetItemWeaponType(BAG_BACKPACK, slot) ~= WEAPONTYPE_NONE and PrismaticWarning.isWeaponPrismatic(BAG_BACKPACK, slot) then
        PrismaticWarning.prismaticItemId = GetItemUniqueId(BAG_BACKPACK, slot)
        PrismaticWarning.debugAlert("Found a prismatic")
        break
      end
    end
  end
  
  if slotAPrismatic then
    unequippedItemId = PrismaticWarning.prismaticItemId
  else
    unequippedItemId = PrismaticWarning.nonPrismaticItemId
  end

  if unequippedItemId == nil then
    PrismaticWarning.debugAlert("Don't know what to slot")
  else
    for slot = 0, numSlots do
      if GetItemWeaponType(BAG_BACKPACK, slot) ~= WEAPONTYPE_NONE and unequippedItemId == GetItemUniqueId(BAG_BACKPACK, slot) then
        itemSlot = slot
        break
      end
    end
  end

  if itemSlot == nil then
    PrismaticWarning.addChatMessage(GetString(PRISMATICWARNING_AUTO_SWAP_FAILED))
    PrismaticWarning.alertVisible(true, GetString(PRISMATICWARNING_AUTO_SWAP_FAILED))
  else
    PrismaticWarning.updateUnequippedItemId()
    
    EquipItem(BAG_BACKPACK, itemSlot, PrismaticWarning.equipSlot)
    PrismaticWarning.addChatMessage(GetString(PRISMATICWARNING_AUTO_SWAP_SUCCESS))
    
    -- remove poisons if equipped on bar where the prismatic was/is slotted
    if GetItemUniqueId(BAG_WORN, PrismaticWarning.poisonSlot) ~= nil then
      local emptySlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
      if emptySlot == nil then
        PrismaticWarning.debugAlert("No space in inventory for unequipping poisons")
      else
        CallSecureProtected("RequestMoveItem", BAG_WORN, PrismaticWarning.poisonSlot, BAG_BACKPACK, emptySlot, 200)
      end
    end
  end

end

function PrismaticWarning.updateUnequippedItemId()
  if PrismaticWarning.isWeaponPrismatic(BAG_WORN, PrismaticWarning.equipSlot) then
    PrismaticWarning.prismaticItemId = GetItemUniqueId(BAG_WORN, PrismaticWarning.equipSlot)
  else
    PrismaticWarning.nonPrismaticItemId = GetItemUniqueId(BAG_WORN, PrismaticWarning.equipSlot)
  end
end

function PrismaticWarning.debugAlert(message)
  if PrismaticWarning.savedVariables.debugAlerts then
    CHAT_SYSTEM:AddMessage("[Prismatic Warning] " .. message)
  end
end

function PrismaticWarning.addChatMessage(message)
  if PrismaticWarning.savedVariables.alertToChat then
    CHAT_SYSTEM:AddMessage("[Prismatic Warning] " .. message)
  end
end

-- On-Screen Alert --

function PrismaticWarning.InitializeUI()
  PrismaticWarningWindowLabelBG:ClearAnchors()
  PrismaticWarningWindowLabelBG:SetAnchor(TOPLEFT, PrismaticWarningWindow, CENTER, PrismaticWarning.savedVariables.left, PrismaticWarning.savedVariables.top)
  
  PrismaticWarning.updateFont()
  
  PrismaticWarningWindowLabel:SetText(string.upper(GetString(PRISMATICWARNING_ALERT)))
  PrismaticWarningWindowLabel:SetColor(unpack(PrismaticWarning.savedVariables.fontColor))
  PrismaticWarningWindowInfo:SetColor(unpack(PrismaticWarning.savedVariables.fontColor))
  PrismaticWarningWindowLabelBG:SetMouseEnabled(not PrismaticWarning.savedVariables.isLocked)

  if PrismaticWarning.savedVariables.hideOnScreenAlertInCombat then
    PrismaticWarning.updateVisibilityOnCombatChange(_, IsUnitInCombat('player'))
    EVENT_MANAGER:RegisterForEvent(PrismaticWarning.name .. "Combat", EVENT_PLAYER_COMBAT_STATE, PrismaticWarning.updateVisibilityOnCombatChange)
  end
  
  PrismaticWarning.alertVisible(false, "")
end

function PrismaticWarning.savePosition()
  PrismaticWarning.savedVariables.left = PrismaticWarningWindowLabelBG:GetLeft()
  PrismaticWarning.savedVariables.top = PrismaticWarningWindowLabelBG:GetTop()
end

function PrismaticWarning.updateFont()
  if PrismaticWarning.savedVariables.fontOutline == "none" then
    PrismaticWarningWindowLabel:SetFont(PrismaticWarning.savedVariables.fontName .. "|" .. PrismaticWarning.savedVariables.fontSize)
    PrismaticWarningWindowInfo:SetFont(PrismaticWarning.savedVariables.fontName .. "|" .. PrismaticWarning.savedVariables.infoFontSize)
  else
    PrismaticWarningWindowLabel:SetFont(PrismaticWarning.savedVariables.fontName .. "|" .. PrismaticWarning.savedVariables.fontSize .. "|" ..  PrismaticWarning.savedVariables.fontOutline)
    PrismaticWarningWindowInfo:SetFont(PrismaticWarning.savedVariables.fontName .. "|" .. PrismaticWarning.savedVariables.infoFontSize .. "|" ..  PrismaticWarning.savedVariables.fontOutline)
  end
end

function PrismaticWarning.updateVisibilityOnCombatChange(_, inCombat)
  if PrismaticWarning.alert then
    PrismaticWarningWindow:SetHidden(inCombat)
  end
end

function PrismaticWarning.alertVisible(visible, setText)
  if not PrismaticWarning.savedVariables.hideOnScreenAlert then
    PrismaticWarningWindowInfo:SetText(string.upper(setText))
    PrismaticWarningWindow:SetHidden(not visible)
  end
end 

EVENT_MANAGER:RegisterForEvent(PrismaticWarning.name, EVENT_ADD_ON_LOADED, PrismaticWarning.OnAddOnLoaded)