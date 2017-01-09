StartDebug()

local source = debug.getinfo(1).source
local modDir = source:sub(2, #source - 8)
dofile(modDir.."settings.lua")

local socket = require("socket")

function string.starts(String, Start)
   return string.sub(String, 1, string.len(Start)) == Start
end

local irc = {
  server = "irc.twitch.tv",
  port = 6667,
  nick = "justinfan"..math.random(10000, 99999999),
    
  newSubPattern = ":twitchnotify!twitchnotify@twitchnotify.tmi.twitch.tv PRIVMSG #"..subscriberBabiesSettings.twitchchannel.." :",
  client = socket.tcp(),
  connected = false,
  
  connect = function(self)
    self.client:connect(self.server, self.port)
    self.client:send("NICK "..self.nick.."\r\n")
    self.client:send("JOIN #"..subscriberBabiesSettings.twitchchannel.."\r\n")
    self.client:send("CAP REQ :twitch.tv/commands\r\n")
    self.client:send("CAP REQ :twitch.tv/membership\r\n")
    self.client:send("CAP REQ :twitch.tv/tags\r\n")
    self.client:settimeout(0)
    self.connected = true
  end,
  
  receive = function(self)
    line, err = self.client:receive()
    
    if err == "closed" then
      self.connected = false
      return nil
    end
    if not line or err == "timeout" then return nil end
    return line
  end,

  parseSub = function(self, line)
    if line == "PING :tmi.twitch.tv" then
			self.client:send("PONG :tmi.twitch.tv\r\n")
		elseif string.starts(line, self.newSubPattern) then
			local namestart = #self.newSubPattern + 1
			local nameend = line:find(" ", namestart) - 1
			local name = line:sub(namestart, nameend)
			return name
		elseif	string.starts(line, "@") and line:find(":tmi.twitch.tv USERNOTICE #"..subscriberBabiesSettings.twitchchannel) then
			line = line:sub(2, line:find(":") - 1)
			local t = {}
			for k, v in string.gmatch(line, "([^=]*)=([^=;]*);") do
				t[k] = v
			end

			if t["msg-id"] == "resub" then
				return t["display-name"]
			end
		end
    
    return nil
  end,

  getNextSub = function(self)
    for i = 1, 8 do
      line = self:receive()
      if not line then break end
      
      sub = self:parseSub(line)
      if sub then
        return sub
      end
    end
    return nil
  end
}

local function GetSubSeed(sub)
  seed = 0
  for i = 1, #sub do
    seed = (seed + string.byte(sub, i))*23
  end
  return seed
end

local subscriberBabiesMod = {
  Name = "SubscriberBabies",
  SubMessage = nil,
  SubEntities = {},
  AddCallback = function(self, callbackId, fn, entityId)
    if not entityId then entityId = -1 end
    Isaac.AddCallback(self, callbackId, fn, entityId)
  end,
  SaveData = function(self, data)
      Isaac.SaveModData(self, data)
  end,
  LoadData = function(self)
      return Isaac.LoadModData(self)
  end,
  HasData = function(self)
      return Isaac.HasModData(self)
  end,
  RemoveData = function(self)
      Isaac.RemoveModData(self)
  end,

  SpawnSub = function(self, sub)
    seed = GetSubSeed(sub)
    
    if subscriberBabiesSettings.subSeed then
      math.randomseed(seed + subscriberBabiesSettings.subSeedOffset)
    end
    
    room = Game():GetRoom()
    subtype = math.random(1, 8)
    subtype = 8
    if subtype == 1 then                                       --enemy

      pool = subscriberBabiesSettings.subEnemies
      poolEntry = pool[math.random(1, #pool)]

      roomMin = room:GetTopLeftPos()
      roomMax = room:GetBottomRightPos()
      spawnPos = Isaac.GetFreeNearPosition(Vector(math.random(roomMin.X, roomMax.X), math.random(roomMin.Y, roomMax.Y)), 1)
      entity = Isaac.Spawn(poolEntry.type, poolEntry.variant, poolEntry.subType, spawnPos, Vector(0, 0), nil)

      npc = entity:ToNPC()
      if npc then
        if math.random(1, 3) == 1 then
          npc:MakeChampion(seed)
          self.SubEntities[#self.SubEntities + 1] = { entity = entity, name = sub, champion = true }
        else
          self.SubEntities[#self.SubEntities + 1] = { entity = entity, name = sub, champion = false }
        end
      end
      self.SubMessage = { message = sub.." has awoken!", time = 0 }
      
    elseif subtype == 2 or subtype == 3 or subtype == 4 or subtype == 5 then    --friendly
      
      pool = subscriberBabiesSettings.subFriendlies
      poolEntry = pool[math.random(1, #pool)]

      roomMin = room:GetTopLeftPos()
      roomMax = room:GetBottomRightPos()
      spawnPos = Isaac.GetFreeNearPosition(Vector(math.random(roomMin.X, roomMax.X), math.random(roomMin.Y, roomMax.Y)), 1)
      entity = Isaac.Spawn(poolEntry.type, poolEntry.variant, poolEntry.subType, spawnPos, Vector(0, 0), nil)
      npc = entity:ToNPC()
      if npc then
        entity:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
        entity:AddEntityFlags(EntityFlag.FLAG_CHARM)
        entity:AddEntityFlags(EntityFlag.FLAG_NO_TARGET)
        if math.random(1, 2) == 1 then
          npc:MakeChampion(seed)
          self.SubEntities[#self.SubEntities + 1] = { entity = entity, name = sub, champion = true }
        else
          self.SubEntities[#self.SubEntities + 1] = { entity = entity, name = sub, champion = false }
        end
      end

      self.SubMessage = { message = sub.." came to help you!", time = 0 }
      
    elseif subtype == 6 or subtype == 7 or evilPresent  then                    ---good item

      pool = subscriberBabiesSettings.subGoodItems
      poolEntry = pool[math.random(1, #pool)]

      roomMin = room:GetTopLeftPos()
      roomMax = room:GetBottomRightPos()
      spawnPos = Isaac.GetFreeNearPosition(Vector(math.random(roomMin.X, roomMax.X), math.random(roomMin.Y, roomMax.Y)), 1)
      entity = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, poolEntry, spawnPos, Vector(0, 0), nil)

      self.SubMessage = { message = sub.." has a present for you!", time = 0 }

    else                                                          --bad item
      
      pool = subscriberBabiesSettings.subBadItems
      poolEntry = pool[math.random(1, #pool)]

      roomMin = room:GetTopLeftPos()
      roomMax = room:GetBottomRightPos()
      spawnPos = Isaac.GetFreeNearPosition(Vector(math.random(roomMin.X, roomMax.X), math.random(roomMin.Y, roomMax.Y)), 1)
      self.evilPresent = { item = poolEntry, doors = {} }
      Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, poolEntry, spawnPos, Vector(0, 0), nil)

      for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        door = room:GetDoor(i)
        if door then
          self.evilPresent.doors[i] = door:IsOpen()
        end
      end

      self.SubMessage = { message = sub.." has an evil present for you!", time = 0 }

    end
  end
}

function subscriberBabiesMod:PostPlayerInit()
  irc:connect()
end

local lastRoomId = nil
function subscriberBabiesMod:PostUpdate()
  --Reconnect every minute
  if not irc.connected and Isaac.GetFrameCount() % 3600 == 0 then
    irc:connect()
    Isaac.DebugString("subscriberBabiesMod: Reconnecting...")
  end

  room = Game():GetRoom()
  roomId = Game():GetLevel():GetCurrentRoomIndex()
  if not lastRoomId then
    lastRoomId = roomId
  end

  if lastRoomId == roomId then
    --check if subs died
    for i = 1, #subscriberBabiesMod.SubEntities do
      sub = subscriberBabiesMod.SubEntities[i]
      if sub and sub.entity:IsDead() then
        subscriberBabiesMod.SubEntities[i] = nil
      end
    end
  else
    --remove dead subs and spawn alive ones if entered next room
    newSubEntities = {}

    for i = 1, #subscriberBabiesMod.SubEntities do
      sub = subscriberBabiesMod.SubEntities[i]
      if sub then
        roomMin = room:GetTopLeftPos()
        roomMax = room:GetBottomRightPos()
        spawnPos = Isaac.GetFreeNearPosition(Vector(math.random(roomMin.X, roomMax.X), math.random(roomMin.Y, roomMax.Y)), 1)
        entity = Isaac.Spawn(sub.entity.Type, sub.entity.Variant, sub.entity.SubType, sub.entity.Position, Vector(0, 0), nil)
        entity:AddEntityFlags(sub.entity:GetEntityFlags())
        if sub.champion then
          entity:ToNPC():MakeChampion(GetSubSeed(sub.name))
        end
        newSubEntities[#newSubEntities + 1] = { entity = entity, name = sub.name, champion = sub.champion}
      end
    end
    subscriberBabiesMod.SubEntities = newSubEntities
    lastRoomId = roomId
  end

  --check if evil present has been taken to open doors
  if subscriberBabiesMod.evilPresent then
    if Isaac.GetPlayer(0):HasCollectible(subscriberBabiesMod.evilPresent.item) then
      for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        door = room:GetDoor(i)
        if door and subscriberBabiesMod.evilPresent.doors[i] then
          door:Open()
        end
      end
      subscriberBabiesMod.evilPresent = nil
    else
      for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        door = room:GetDoor(i)
        if door then
          self.evilPresent.doors[i] = self.evilPresent.doors[i] or door:IsOpen()
          door:Close(false)
        end
      end
      room:KeepDoorsClosed()
    end
  end

  if subscriberBabiesMod.SubMessage then
      return
  end
  
  sub = irc:getNextSub()
  if sub then
    subscriberBabiesMod:SpawnSub(sub)
	end
  
  if subscriberBabiesSettings.debug then
    --subscriberBabiesMod:SpawnSub("Abc")
    subscriberBabiesMod:SpawnSub("Creysys")
    --subscriberBabiesMod:SpawnSub("AverageName555")
    --subscriberBabiesMod:SpawnSub("SomeOtherPrettyLongNameLUL")
    subscriberBabiesSettings.debug = false
  end
end

function subscriberBabiesMod:PostRender()
  --draw sub names
  room = Game():GetRoom()
  for i = 1, #subscriberBabiesMod.SubEntities do
      sub = subscriberBabiesMod.SubEntities[i]
      if sub then
        pos = sub.entity.Position
        pos.X = pos.X - #sub.name*4.5
        pos.Y = pos.Y - 80
        pos = room:WorldToScreenPosition(pos, true)
        Isaac.RenderText(sub.name, pos.X, pos.Y, subscriberBabiesSettings.subNameColor.r,
          subscriberBabiesSettings.subNameColor.g, subscriberBabiesSettings.subNameColor.b,
          subscriberBabiesSettings.subNameColor.a)
      end
  end



  if not subscriberBabiesMod.SubMessage then
    return
  end
  
  alpha = subscriberBabiesSettings.subMessageColor.a
  if subscriberBabiesMod.SubMessage.time > subscriberBabiesSettings.subMessageDuration then
    alpha = alpha * (1 - (subscriberBabiesMod.SubMessage.time - subscriberBabiesSettings.subMessageDuration) / subscriberBabiesSettings.subMessageFadeDuration)
  end
  
  Isaac.RenderText(subscriberBabiesMod.SubMessage.message, subscriberBabiesSettings.subMessagePos.X, subscriberBabiesSettings.subMessagePos.Y,
    subscriberBabiesSettings.subMessageColor.r, subscriberBabiesSettings.subMessageColor.g, subscriberBabiesSettings.subMessageColor.b, alpha)
  subscriberBabiesMod.SubMessage.time = subscriberBabiesMod.SubMessage.time + 1/60
  if subscriberBabiesMod.SubMessage.time >= subscriberBabiesSettings.subMessageDuration + subscriberBabiesSettings.subMessageFadeDuration then
    subscriberBabiesMod.SubMessage = nil
  end
end

Isaac.RegisterMod(subscriberBabiesMod, subscriberBabiesMod.Name, 1)
subscriberBabiesMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, subscriberBabiesMod.PostPlayerInit)
subscriberBabiesMod:AddCallback(ModCallbacks.MC_POST_UPDATE, subscriberBabiesMod.PostUpdate)
subscriberBabiesMod:AddCallback(ModCallbacks.MC_POST_RENDER, subscriberBabiesMod.PostRender)
