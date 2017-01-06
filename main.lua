require("mobdebug").start()

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
  
  connect = function(self)
    self.client:connect(self.server, self.port)
    self.client:send("NICK "..self.nick.."\r\n")
    self.client:send("JOIN #"..subscriberBabiesSettings.twitchchannel.."\r\n")
    self.client:send("CAP REQ :twitch.tv/commands\r\n")
    self.client:send("CAP REQ :twitch.tv/membership\r\n")
    self.client:send("CAP REQ :twitch.tv/tags\r\n")
    self.client:settimeout(0)
  end,
  
  receive = function(self)
    line, err = self.client:receive()
    
    if line == nil or err == "timeout" then return nil end
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
      if line == nil then break end
      
      sub = self:parseSub(line)
      if sub ~= nil then
        return sub
      end
    end
    return nil
  end
}

local subscriberBabiesMod = {
  Name = "SubscriberBabies",
  SubMessage = nil,
  Friendlies = {},
  AddCallback = function(self, callbackId, fn, entityId)
    if entityId == nil then entityId = -1 end
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
    seed = 0
    for i = 1, #sub do
      seed = (seed + string.byte(sub, i))*23
    end
    
    if subscriberBabiesSettings.subSeed then
      math.randomseed(seed + subscriberBabiesSettings.subSeedOffset)
    end
    
    room = Game():GetRoom()
    subtype = math.random(1, 2)
    if subtype == 1 then        --enemy
      
      for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
        door = room:GetDoor(i)
        if door then
          door:Close(false)
        end
      end
      
      pool = subscriberBabiesSettings.subEnemies
      poolEntry = pool[math.random(1, #pool)]

      roomMin = room:GetTopLeftPos()
      roomMax = room:GetBottomRightPos()
      spawnPos = Isaac.GetFreeNearPosition(Vector(math.random(roomMin.X, roomMax.X), math.random(roomMin.Y, roomMax.Y)), 1)
      entity = Isaac.Spawn(poolEntry.type, poolEntry.variant, poolEntry.subType, spawnPos, Vector(0, 0), nil)
      
      self.SubMessage = { message = sub.." has awoken!", time = 0 }
      
    elseif subtype == 2 then    --friendly
      
      pool = subscriberBabiesSettings.subFriendlies
      poolEntry = pool[math.random(1, #pool)]

      roomMin = room:GetTopLeftPos()
      roomMax = room:GetBottomRightPos()
      spawnPos = Isaac.GetFreeNearPosition(Vector(math.random(roomMin.X, roomMax.X), math.random(roomMin.Y, roomMax.Y)), 1)
      entity = Isaac.Spawn(poolEntry.type, poolEntry.variant, poolEntry.subType, spawnPos, Vector(0, 0), nil)
      entity:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
      entity:AddEntityFlags(EntityFlag.FLAG_CHARM)
      entity:AddEntityFlags(EntityFlag.FLAG_NO_TARGET)

      self.Friendlies[#self.Friendlies + 1] = entity
      self.SubMessage = { message = sub.." came to help you!", time = 0 }
      
    else                        --item
      
      
      
    end
  end
}


function subscriberBabiesMod:PostPlayerInit()
  irc:connect()
end

d = false

local lastRoomId = nil
function subscriberBabiesMod:PostUpdate()
  roomId = Game():GetLevel():GetCurrentRoomIndex()
  if not lastRoomId then
    lastRoomId = roomId
  end

  if lastRoomId == roomId then
    --check if friendlies died
    for i = 1, #subscriberBabiesMod.Friendlies do
      if subscriberBabiesMod.Friendlies[i]:IsDead() then
        subscriberBabiesMod.Friendlies[i] = nil
      end
    end
  else
    --spawn friendlies if entered next room
    room = Game():GetRoom()
    newFriendlies = {}
    for i = 1, #subscriberBabiesMod.Friendlies do
      entity = subscriberBabiesMod.Friendlies[i]
      if entity then
        roomMin = room:GetTopLeftPos()
        roomMax = room:GetBottomRightPos()
        spawnPos = Isaac.GetFreeNearPosition(Vector(math.random(roomMin.X, roomMax.X), math.random(roomMin.Y, roomMax.Y)), 1)
        entity = Isaac.Spawn(entity.Type, entity.Variant, entity.SubType, spawnPos, Vector(0, 0), nil)
        entity:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
        entity:AddEntityFlags(EntityFlag.FLAG_CHARM)
        entity:AddEntityFlags(EntityFlag.FLAG_NO_TARGET)
        newFriendlies[#newFriendlies + 1] = entity
      end
    end
    subscriberBabiesMod.Friendlies = newFriendlies
    lastRoomId = roomId
  end

  if subscriberBabiesMod.SubMessage ~= nil then
      return
  end
  
  sub = irc:getNextSub()
  if sub ~= nil then
    subscriberBabiesMod:SpawnSub(sub)
	end
  
  if not d then
    subscriberBabiesMod:SpawnSub("Creysys")
    d = true
  end
end

function subscriberBabiesMod:PostRender()
  if subscriberBabiesMod.SubMessage == nil then
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


