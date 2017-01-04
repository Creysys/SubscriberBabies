require("mobdebug").start()

local twitchchannel = "cobaltstreak"

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

  getNextSubs = function(self)
    subs = {}
    for i = 1, 32 do
      line = self:receive()
      if line == nil then break end
      
      sub = self:parseSub(line)
      if sub ~= nil then
        subs[#subs + 1] = sub
      end
    end
    return subs
  end
}

local subscriberBabiesMod = {
  Name = "SubscriberBabies",
  AddCallback = function(self, callbackId, fn, entityId)
    if entityId == nil then entityId = -1 end
    Isaac.AddCallback(self, callbackId, fn, entityId)
  end
}


function subscriberBabiesMod:PostPlayerInit()
  irc:connect()
end

function subscriberBabiesMod:PostUpdate()
  subs = irc:getNextSubs()
	for i = 1, #subs do
		Isaac.Spawn(EntityType.ENTITY_BOOMFLY, 0, 0, Vector(math.random(0, 100), math.random(0, 100)), Vector(0, 0), Isaac.GetPlayer(0))
	end
end

Isaac.RegisterMod(subscriberBabiesMod, subscriberBabiesMod.Name, 1)
subscriberBabiesMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, subscriberBabiesMod.PostPlayerInit)
subscriberBabiesMod:AddCallback(ModCallbacks.MC_POST_UPDATE, subscriberBabiesMod.PostUpdate)


