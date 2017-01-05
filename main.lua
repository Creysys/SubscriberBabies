require("mobdebug").start()

--change this to your channel
local twitchchannel = "cobaltstreak"
--will each sub have the same entity every time? (true/false)
local subSeed = true
--if true change this number to switch to a different set of sub dependent entities
local subSeedOffset = 666
--tyrone is not letting me access the gui offset so you have to adjust this yourself im sorry :S
local subMessagePos = Vector(45, 45)
--subscriber message color
local subMessageColor = { r = 0.8, g = 0.4, b = 0.15 }
--subscriber message duration in seconds
local subMessageDuration = 5
--subscriber message fade out duration in seconds
local subMessageFadeDuration = 1

local socket = require("socket")

function string.starts(String, Start)
   return string.sub(String, 1, string.len(Start)) == Start
end

local irc = {
  server = "irc.twitch.tv",
  port = 6667,
  nick = "justinfan"..math.random(10000, 99999999),
    
  newSubPattern = ":twitchnotify!twitchnotify@twitchnotify.tmi.twitch.tv PRIVMSG #"..twitchchannel.." :",
  client = socket.tcp(),
  
  connect = function(self)
    self.client:connect(self.server, self.port)
    self.client:send("NICK "..self.nick.."\r\n")
    self.client:send("JOIN #"..twitchchannel.."\r\n")
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
		elseif	string.starts(line, "@") and line:find(":tmi.twitch.tv USERNOTICE #"..twitchchannel) then
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
    
    if subSeed then
      math.randomseed(seed + subSeedOffset)
    end
    
    subtype = math.random(1, 1)
    if subtype == 1 then
      --enemy
      spawnPos = Isaac.GetFreeNearPosition(Vector(math.random(-10, 10), math.random(-10, 10)), 1)
      entity = Isaac.Spawn(EntityType.ENTITY_BOOMFLY, 0, 0, spawnPos, Vector(0, 0), nil)
      
      self.SubMessage = { message = sub.." has awoken!", time = 0 }
    elseif subtype == 2 then
      --friendly
    else
      --item
    end
  end
}


function subscriberBabiesMod:PostPlayerInit()
  irc:connect()
end

d = false
function subscriberBabiesMod:PostUpdate()
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
  
  alpha = 0.85
  if subscriberBabiesMod.SubMessage.time > subMessageDuration then
    alpha = (1 - (subscriberBabiesMod.SubMessage.time - subMessageDuration) / subMessageFadeDuration) * 0.85
  end
  
  Isaac.RenderText(subscriberBabiesMod.SubMessage.message, subMessagePos.X, subMessagePos.Y, 0.8, 0.4, 0.15, alpha)
  subscriberBabiesMod.SubMessage.time = subscriberBabiesMod.SubMessage.time + 1/60
  if subscriberBabiesMod.SubMessage.time >= subMessageDuration + subMessageFadeDuration then
    subscriberBabiesMod.SubMessage = nil
  end
end

Isaac.RegisterMod(subscriberBabiesMod, subscriberBabiesMod.Name, 1)
subscriberBabiesMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, subscriberBabiesMod.PostPlayerInit)
subscriberBabiesMod:AddCallback(ModCallbacks.MC_POST_UPDATE, subscriberBabiesMod.PostUpdate)
subscriberBabiesMod:AddCallback(ModCallbacks.MC_POST_RENDER, subscriberBabiesMod.PostRender)


