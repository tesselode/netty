pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
-- netty
-- andrew minnich
cartdata("tesselode_netty")



-- state management
state = {}

function gotostate(s, ...)
 menuitem(4)
 state.current = s
 state.current:enter(...)
end



-- camera shakes
shake = {}
shake.launch = {
 {-1, -1},
 {-1, -1},
 {-1, -1},
 {1, 1},
 {1, 1},
 {1, 1},
 {1, -1},
 {1, -1},
 {1, -1},
 {-1, 1},
 {-1, 1},
 {-1, 1},
 {0, 0},
}


-- grid palettes
gridpalette = {
 {1, 0, 0, 6, 12, 'netty'},
 {0, 1, 1, 5, 1, 'nite',},
 {3, 11, 11, 11, 3, 'circuit',},
 {5, 0, 0, 0, 0, 'lumines',},
 {0, 0, 8, 8, 8, 'evil',},
 {13, 1, 1, 6, 1, 'murky',},
 {4, 9, 15, 4, 9, 'waffle',},
 {9, 0, 0, 10, 9, 'bee',},
 {8, 2, 2, 6, 14, 'punch',},
 {14, 14, 12, 6, 12, 'cute',},
 {7, 6, 6, 7, 7, 'sterile',},
 {0, 1, 0, 0, 7, 'depths',},
}


-- extra functions
function printc(s, x, y, c, glyphs)
 glyphs = glyphs or 0
 s = s .. ''
 x -= #s * 2 + glyphs * 2
 print(s, x, y, c)
end

function shakecamera(sequence)
 cam.sequence = sequence
 cam.frame = 1
end

function sign(x)
 if x < 0 then
  return -1
 elseif x > 0 then
  return 1
 else
  return 0
 end
end

function clamp(x, a, b)
 if x < a then
  return a
 elseif x > b then
  return b
 else
  return x
 end
end

function lerp(a, b, f)
 return a + (b-a) * f
end

function lerpl(a, b, f, m)
 local d = (b-a) * f
 d = clamp(d, -m, m)
 return a + d
end

function round(x)
 if x % 1 > .5 then
  return flr(x) + 1
 else
  return flr(x)
 end
end

function ceil(x)
 if x == flr(x) then
  return x
 else
  return flr(x) + 1
 end
end

function drawborder()
 pal(6, gridpalette[currentpalette][4])
 pal(12, gridpalette[currentpalette][5])
 map(0, 0, 0, 0, 16, 16)
 pal()
end


-- globals
gametype = 1
player = nil
dots = nil
blackholes = nil
effects = nil
score = nil
gravitytimer = nil
freezeframes = 0
uptime = 0

-- options
launchstyle = nil
movestyle = nil
firstrun = dget(2)
currentpalette = nil
if firstrun == 0 then
 dset(2, 1) -- first run
 dset(3, 1) -- launch style
 dset(4, 0) -- move style
 dset(5, 1) -- color palette
end

function setlaunchstyle(s)
 launchstyle = s
 dset(3, s)
 if s == 0 then
  menuitem(1, 'launch: normal', function()
   setlaunchstyle(1)
  end)
 end
 if s == 1 then
  menuitem(1, 'launch: inverted', function()
   setlaunchstyle(0)
  end)
 end
end

function setmovestyle(s)
 movestyle = s
 dset(4, s)
 if s == 0 then
  menuitem(2, 'move: normal', function()
   setmovestyle(1)
  end)
 end
 if s == 1 then
  menuitem(2, 'move: inverted', function()
   setmovestyle(0)
  end)
 end
end

function setcolorpalette(c)
 if c < 1 then c = 1 end
 if c > #gridpalette then c = 1 end
 currentpalette = c
 dset(5, c)
 menuitem(3, 'color: ' .. gridpalette[currentpalette][6], function()
  setcolorpalette(currentpalette + 1)
 end)
end

setlaunchstyle(dget(3))
setmovestyle(dget(4))
setcolorpalette(dget(5))



class = {}

function class.player()
 local player = {
  -- tweak me
  r = 4,
  accel = .02,
  friction = 1.015,
 	maxspeed = 2.5,
 	slomospeed = .2,
 	chargespeed = 1/60,
 	launchspeed = 3,
 	traillength = 16,

  -- don't tweak me
  buttoncurrent = false,
  buttonprevious = false,
 	x = 64,
 	y = 64,
 	vx = 0,
 	vy = 0,
 	canlaunch = true,
 	launching = false,
 	charge = 0,
 	launchdir = 0,
 	suctiontimer = 0,
 	sizetimer = 0,
 	speedtimer = 0,
 }
 player.displayr = player.r

 -- init trail
 player.trail = {}
 local i
 for i = 1, player.traillength do
  player.trail[i] = {x = player.x, y = player.y}
 end
 
 local inputx
 local inputy

 function player:update()
  -- input
  inputx = 0
  inputy = 0
  if (btn(0)) inputx -= 1
  if (btn(1)) inputx += 1
  if (btn(2)) inputy -= 1
  if (btn(3)) inputy += 1
  local l = sqrt(inputx*inputx + inputy*inputy)
  if l > 1 then
   inputx /= l
   inputy /= l
  end
  self.buttonprevious = self.buttoncurrent
  self.buttoncurrent = btn(4)
  local buttonpressed = self.buttoncurrent and not self.buttonprevious

  local speed = sqrt(self.vx*self.vx + self.vy*self.vy)

  -- acceleration
  local d = movestyle == 1 and -1 or 1
  self.vx += inputx * self.accel * speed / self.maxspeed * d
  self.vy += inputy * self.accel * speed / self.maxspeed * d

  -- friction
  self.vx /= self.friction
  self.vy /= self.friction
  
  -- gravity
  if gravitytimer > 0 then
   self.vy += .02
  end
  
  -- black hole gravity
  for b in all(blackholes) do
	  local d = atan2(b.x - self.x, b.y - self.y)
	  self.vx += .004 * cos(d)
	  self.vy += .004 * sin(d)
	 end

  -- bounce of screen edges
  local burstbounceparticles = function(angle)   
   for i = 1, 3 do
    local p = class.particle(self.x, self.y)
    p.angle = angle - .25 + rnd(.5)
    add(effects, p)
   end
   sfx(10)
  end
  if self.x < self.r then
   self.x = self.r
   self.vx *= -1
   burstbounceparticles(0)
  end
  if self.x > 128 - self.r then
   self.x = 128 - self.r
   self.vx *= -1
   burstbounceparticles(.5)
  end
  if self.y < self.r + 16 then
   self.y = self.r + 16
   self.vy *= -1
   burstbounceparticles(.75)
  end
  if self.y > 128 - self.r then
   self.y = 128 - self.r
   self.vy *= -1
   burstbounceparticles(.25)
  end

  -- limit speed
  if speed > self.maxspeed then
   self.vx /= (speed / self.maxspeed)
   self.vy /= (speed / self.maxspeed)
  end

  -- launching --
  
  -- start charge
  if not self.launching and buttonpressed then
   if self.canlaunch then
	   self.launching = true
	   self.charge = 0
	   if btn(0) or btn(1) or btn(2) or btn(3) then
	    self.launchdir = atan2(inputx, inputy)
	    if launchstyle == 1 then
	     self.launchdir += .5
	    end
	   else
	    self.launchdir = atan2(self.vx, self.vy)
	   end
	   sfx(8, 2)
	  else
	   sfx(35)
	  end
  end
  
  -- charge up
  if self.launching then
   self.charge += self.chargespeed
   if btnp(0) or btnp(1) or btnp(2) or btnp(3) then
    self.launchdir = atan2(inputx, inputy)
    if launchstyle == 1 then
     self.launchdir += .5
    end
   end
  end
  
  -- launch
  if self.launching and (not btn(4) or self.charge >= 1) then
   state.gameplay:onlaunch()
   self.launching = false
   local angle = self.launchdir
   self.vx = self.launchspeed * cos(angle) * self.charge
   self.vy = self.launchspeed * sin(angle) * self.charge
   score.multiplier = 1
   
   -- effects
   for i = 1, 5 do
    local p = class.particle(self.x, self.y, 12)
    p.angle = angle + .5 - .15 + rnd(.3)
    add(effects, p)
   end
   shakecamera(shake.launch)
   freezeframes = 2
   sfx(9, 2)
  end

  -- powerup states
  if self.suctiontimer > 0 then
   self.suctiontimer -= 1/60
  end
  if self.sizetimer > 0 then
   self.r = 8
   self.sizetimer -= 1/60
  else
   self.r = 4
  end
  if self.speedtimer > 0 then
   self.speedtimer -= 1/60
  end

  -- apply movement
 	local speedfactor
 	if self.launching then
 	 speedfactor = self.slomospeed
 	else
 	 speedfactor = 1
 	end
 	if self.speedtimer > 0 then
 	 speedfactor *= 1.5
 	end
  self.x += self.vx * speedfactor
  self.y += self.vy * speedfactor

  -- trail
  self.trail[1].x = player.x
  self.trail[1].y = player.y
  for i = 2, #self.trail do
   local t1 = self.trail[i]
   local t2 = self.trail[i - 1]
   t1.x = (t1.x + t2.x) / 2
   t1.y = (t1.y + t2.y) / 2
  end
  
  -- cosmetic
  self.displayr = self.displayr + (self.r - self.displayr) * .1
  
  -- burst some particles
  if not self.firstframe then
		 for i = 1, 10 do
			 add(effects, class.particle(self.x, self.y, 7))
			end
			self.firstframe = true
		end
 end

 function player:draw()
  -- draw launching hud
  local x, y = flr(self.x), flr(self.y)
  if self.launching then
   circfill(self.x, self.y, self.displayr * 4, 12)
   circfill(self.x, self.y, self.displayr + self.displayr*3*self.charge, 14)
   local bx = cos(self.launchdir) * self.displayr * 4
   local by = sin(self.launchdir) * self.displayr * 4
   if launchstyle == 1 then
    bx = -bx
    by = -by
   end
   line(self.x, self.y, self.x + bx, self.y + by, 9)
  end

  -- draw trail
  for i = 1, #self.trail do
   local t = self.trail[i]
   local r = self.displayr - self.displayr * (i / #self.trail)
   local c
   if self.speedtimer > 0 then
    c = 9
   else
    c = 7
   end
   circfill(t.x, t.y, r, c)
  end
  
  if self.suctiontimer > 0 then
   circfill(x, y, self.displayr, 11)
   circ(x, y, self.displayr, 10)
  else
   circfill(x + 1, y + 1, self.displayr, 5)
   circfill(x, y, self.displayr, 7)
	  circ(x, y, self.displayr, 6)
	 end
 end

 return player
end



function class.dot(special)
 local dot = {
  r = 4,

  x = 4 + flr(rnd(120)),
  y = 20 + flr(rnd(104)),
  vx = 0,
  vy = 0,
  special = special,
  displayr = 1,
 }

 function dot:update()
  -- suction
  if player.suctiontimer > 0 then
	  local d = atan2(player.x - self.x, player.y - self.y)
	  self.vx += .004 * cos(d)
	  self.vy += .004 * sin(d)
	 end
  
  -- gravity
  if gravitytimer > 0 then
   self.vy += .02
  end
  
  -- black hole gravity
  for b in all(blackholes) do
	  local d = atan2(b.x - self.x, b.y - self.y)
	  self.vx += .004 * cos(d)
	  self.vy += .004 * sin(d)
	 end
  
  -- bounce off walls
  if self.x < self.r then
   self.x = self.r
   self.vx *= -1
   sfx(24)
  end
  if self.x > 128 - self.r then
   self.x = 128 - self.r
   self.vx *= -1
   sfx(24)
  end
  if self.y < self.r + 16 then
   self.y = self.r + 16
   self.vy *= -1
   sfx(24)
  end
  if self.y > 128 - self.r then
   self.y = 128 - self.r
   self.vy *= -1
   sfx(24)
  end
  
  -- apply movement
  self.x += self.vx
  self.y += self.vy
  
  -- enter animation
  if self.displayr < self.r then
   self.displayr += 1/3
  end
 end

 function dot:draw()
  if self.special then
   local x1, y1 = self.x, self.y
	  for i = 0, 1, 1/16 do
		  local r = self.displayr + 2 * sin(uptime / 30 + i * 4)
		  local x2 = self.x + r * cos(i)
		  local y2 = self.y + r * sin(i)
		  line(x1, y1, x2, y2, 11)
		 end
		end
 
  if self.displayr < self.r then
   if self.special then
    circfill(self.x, self.y, self.displayr, 11)
   else
    circfill(self.x, self.y, self.displayr, 10)
   end
  else
	  local s
	  if self.special then
	   s = 2
	  else
	   s = 1
	  end
	  spr(s + 2, self.x - 3, self.y - 3)
	  spr(s, self.x - 4, self.y - 4)
	 end
 end

 return dot
end


function class.blackhole()
 local blackhole = {
  x = 8 + flr(rnd(112)),
  y = 24 + flr(rnd(96)),
	 r = 8,
	 life = 5,
	 displayr = 0,
	}
	sfx(20, 1)
	
	function blackhole:update()
	 self.life -= 1/60
	 if self.life <= 20/60 then
	  self.r = 0
	 end
	 self.displayr = self.displayr + (self.r - self.displayr) * .1
	 if self.life <= 0 then
	  sfx(22, 1)
	 end
	end

	function blackhole:draw()
	 local x1, y1 = self.x, self.y
	 for i = 0, 1, .05 do
	  local r = self.displayr + 2 + 2 * sin(uptime / 30 + i * 3)
	  local x2 = self.x + r * cos(i)
	  local y2 = self.y + r * sin(i)
	  line(x1, y1, x2, y2, 8)
	 end
	 circfill(self.x, self.y, self.displayr, 0)
	 circ(self.x, self.y, self.displayr, 8)
	end
	
	return blackhole
end



function class.particle(x, y, col)
 local particle = {
  x = x,
  y = y,
  angle = rnd(1),
  speed = 3,
  friction = 1.1,
  col = col or 7,
  life = .25 + rnd(.25),
 }

 function particle:update()
  self.speed /= self.friction
  self.x += self.speed * cos(self.angle)
  self.y += self.speed * sin(self.angle)
  self.life -= 1/60
 end

 function particle:draw()
  rect(self.x, self.y, self.x + 1, self.y + 1, self.col)
 end

 return particle
end


function class.scorepopup(x, y, score, col)
 local scorepopup = {
  x = x,
  y = y,
  score = score,
  col = col or 10,
  speed = 2,
  friction = 1.1,
  life = .5,
 }
 
 function scorepopup:update()
  self.speed /= self.friction
  self.y -= self.speed
  self.life -= 1/60
 end
 
 function scorepopup:draw()
  local s = self.score .. '00'
	 printc(s, self.x + 1, self.y + 1, 5)
  printc(s, self.x, self.y, self.col)
 end
 
 return scorepopup
end


function class.poweruptext(s)
 local text = {
  s = s,
  
  y = 16,
  life = 1.5,
  id = 'text',
 }
 
 function text:update()
  self.y /= 1.1
  self.life -= 1/60
 end
 
 function text:draw()
  printc(self.s, 65, 65 + self.y, 5)
  printc(self.s, 64, 64 + self.y, 11)
 end
 
 return text
end



function class.gridpoint(x, y)
 local point = {
  anchorx = x,
  anchory = y,
  x = x,
  y = y,
  vx = 0,
  vy = 0,
 }
 
 function point:update()
  if self.anchorx == 0 or self.anchorx == 128 or self.anchory == 16 or self.anchory == 128 then
   return
  end
  
  for b in all(blackholes) do
	  local r = sqrt((b.x - self.x)^2 + (b.y - self.y)^2)
	  if r < 1 then r = 1 end
   self.x = lerp(self.x, b.x, 1/r)
   self.y = lerp(self.y, b.y, 1/r)
  end
  
  local r = sqrt((player.x - self.x)^2 + (player.y - self.y)^2)
  if r < 1 then r = 1 end
  local f = (player.r^3)/320
  self.x = lerp(self.x, player.x, f/r)
  self.y = lerp(self.y, player.y, f/r)
  
  if gravitytimer > 0 then
   self.y = lerp(self.y, 128, .02)
  end
  
  self.x = lerp(self.x, self.anchorx, .1)
  self.y = lerp(self.y, self.anchory, .1)
 end

 return point
end



-- hud --

hud = {
 timeyoffset = 0,
 displayscore = 0,
 cutedots = {0, 0, 0, 0, 0, 0, 0, 0},
}

function hud:tickdown(playsound)
 self.timeyoffset = 4
 if playsound then sfx(29) end
end

function hud:update()
 local s = 0
 
 if state.current == state.gameplay or state.current == state.results then
  s = score.score
 end

 -- timer animation
 self.timeyoffset = lerp(self.timeyoffset, 0, .2)
	 
 -- rolling score counter
 if state.current == state.gameplay or state.current == state.results then
	 self.displayscore = lerp(self.displayscore, s, .25)
	 if self.displayscore % 1 > .99 then
	  self.displayscore = flr(self.displayscore) + 1
	 end
	else
	 self.displayscore = 0
	end

 if gametype == 3 then
  -- update zen mode visualizer
	 local wiggle = 1000 * sin(uptime/240) * (s - self.displayscore) / 100
	 self.cutedots[1] = lerpl(self.cutedots[1], wiggle, .1, 1.5)
	 for i = 8, 2, -1 do
	  self.cutedots[i] = lerp(self.cutedots[i], self.cutedots[i-1], .1)
	 end
	end
end

function hud:draw()
 local scoredisplayy = 0
 local timeleft = 60
 local movesleft = 15

 if state.current == state.gameplay or state.current == state.results then
  timeleft = score.timeleft
  movesleft = score.movesleft
 
  scoredisplayy = 400 * (score.score - self.displayscore) / 200
	 if scoredisplayy > 2 then scoredisplayy = 2 end
	 scoredisplayy = round(scoredisplayy)
	end

 if gametype == 3 then
  -- draw zen mode visualizer
	 for i = 1, 8 do
	  local x = 36 + 8 * (i - 1)
	  local wiggle = self.cutedots[i]
	  wiggle = clamp(wiggle, -4 ,4)
	  local y = round(8 + wiggle)
	  local c = 5
	  if abs(wiggle) > 1 then
	   c = gridpalette[currentpalette][4]
	  end
	  if abs(wiggle) > 3 then
	   c = gridpalette[currentpalette][5]
	  end
	  circfill(x, y, 2, c)
	 end
	 return false
	end
	
	-- score counter
 local s
 if self.displayscore == 0 then
  s = 0
 else
  local whole = flr(self.displayscore)
  local decimal = self.displayscore % 1
  if whole == 0 then whole = '' end
  if decimal == 0 then
   s = whole .. '00'
  else
   decimal = decimal .. ''
	  s = whole .. sub(decimal, 3, 4)
	 end
 end
 
 print('score', 2, 2, 5)
 print('score', 1, 1, 12)
 print(s, 26, 2 + scoredisplayy, 5)
 print(s, 25, 1 + scoredisplayy, 7)
 
 -- high score
 local s = dget(gametype-1)
 if s ~= 0 then
  s = s .. '00'
 end
 print('high', 2, 10, 5)
 print('high', 1, 9, 10)
 print(s, 26, 10, 5)
 print(s, 25, 9, 7)
 
 -- time/moves left
 if gametype == 1 or movesleft == 0 then
	 print('time', 113, 2, 5)
	 print('time', 112, 1, 7)
	 local t = ceil(timeleft)
	 t = t .. ''
	 printc(t, 121, 10 + self.timeyoffset, 5)
	 local c = 7
	 if timeleft <= 10 then
	  c = 8
	 end
	 printc(t, 120, 9 + self.timeyoffset, c)
	else
	 print('left', 113, 2, 5)
	 print('left', 112, 1, 7)
	 local t = movesleft
	 t = t .. ''
	 printc(t, 121, 10 + self.timeyoffset, 5)
	 local c = 7
	 if movesleft <= 5 then
	  c = 8
	 end
	 printc(t, 120, 9 + self.timeyoffset, c)
	end
end
  


-- gameplay state --

state.gameplay = {}

function state.gameplay:enter(gametype)
	player = class.player()
	dots = {}
	blackholes = {}
	effects = {}
	score = {
	 score = 0,
	 multiplier = 1,
	 dotscollected = 0,
	 timeleft = 60,
	 movesleft = 15,
	}
	cam = {
	 sequence = {{0, 0}},
	 frame = 1,
	}
	gravitytimer = 0
	
	self.powerups = {}
	
	-- cosmetic
	self.grid = {}
	for x = 0, 128, 16 do
	 self.grid[x] = {}
	 for y = 16, 128, 16 do
	  self.grid[x][y] = class.gridpoint(x, y)
	 end
	end
	 
	self.secondtimer = 1
	
	for i = 1, 5 do
		add(dots, class.dot())
	end
	
	menuitem(4, 'retry', function()
	 gotostate(state.transition, state.intro, true)
	end)
end

function state.gameplay:powerup()
 -- shuffle powerups
 if #self.powerups == 0 then
	 if gametype == 1 then
		 self.powerups = {1, 2, 3, 4, 5, 6}
		end
		if gametype == 2 then
		 self.powerups = {2, 3, 4, 5, 6}
		end
  if gametype == 3 then
   self.powerups = {2, 3, 4, 5}
  end 
	 for _ = 1, 10 do
		 for i = 1, #self.powerups - 1 do
	   local j = i + 1
	   if rnd(2) < 1 then
	    local a, b = self.powerups[i], self.powerups[j]
	    self.powerups[i] = b
	    self.powerups[j] = a
	   end
	  end
	 end
 end
 		
 local c = self.powerups[1]
 assert(c)
 del(self.powerups, self.powerups[1])

 -- delete previous powerup text
 for e in all(effects) do
  if e.id == 'text' then
   del(effects, e)
  end
 end

 if c == 1 then
  add(dots, class.dot())
  add(effects, class.poweruptext('extra dot!'))
  sfx(19, 3)
 end
 if c == 2 then
  add(blackholes, class.blackhole())
  add(effects, class.poweruptext('black hole!'))
 end
 if c == 3 then
  player.sizetimer = 5
  add(effects, class.poweruptext('size up!'))
  sfx(25, 3)
 end
 if c == 4 then
  gravitytimer = 5
  sfx(23, 3)
  add(effects, class.poweruptext('gravity!'))
 end
 if c == 5 then
  player.speedtimer = 5
  add(effects, class.poweruptext('speed up!'))
  sfx(21, 3)
 end
 if c == 6 then
  if gametype == 1 then
	  score.timeleft += 5
	  add(effects, class.poweruptext('extra time!'))
	 else
	  score.movesleft += 3
	  add(effects, class.poweruptext('extra launches!'))
	 end  
  sfx(33, 3)
 end
end

function state.gameplay:onlaunch()
 if gametype == 2 then
  score.movesleft -= 1
  hud:tickdown()
 end
end

function state.gameplay:update()
 if freezeframes > 0 then
  freezeframes -= 1
  return
 end

 if gametype == 1 then
	 score.timeleft -= 1/60
	 if score.timeleft <= 0 then
	  gotostate(state.results)
	 end
	end
	if gametype == 2 then
	 player.canlaunch = score.movesleft > 0
	 if score.movesleft == 0 then
	  score.timeleft -= 1/60
	  if score.timeleft <= 0 then
		  gotostate(state.results)
		 end
		else
			score.timeleft = 10
		end
	end
 
 if gravitytimer > 0 then
  gravitytimer -= 1/60
 end

 -- update player
 player:update()

 -- update dots
 for d in all(dots) do
  d:update()	

  -- dot collection
  local distance = sqrt((d.x - player.x)^2 + (d.y - player.y)^2)
  if distance < player.r + d.r then
   del(dots, d)
   local dotscore = score.multiplier
   local col
   if d.special then
    col = 11
    dotscore *= 5
    self:powerup()
   else
    col = 10
   end
   score.dotscollected += 1
   score.multiplier += 1
   score.score += dotscore
   add(dots, class.dot(score.dotscollected % 5 == 0))
   for i = 1, 5 do
    add(effects, class.particle(d.x, d.y, col))
   end
   add(effects, class.scorepopup(d.x, d.y, dotscore, col))
   local s
   if score.multiplier > 8 then
    s = 7
   else
	   s = score.multiplier - 2
	  end
	  if d.special then
	   s += 11
	  end
	  sfx(s, 0)
  end
 end
 
 -- update blackholes
 for b in all(blackholes) do
  b:update()
  if b.life <= 0 then
   del(blackholes, b)
  end
 end

 -- update particles
 for e in all(effects) do
  e:update()
  if e.life <= 0 then
   del(effects, e)
  end
 end
 
 -- update grid
 for x = 0, 128, 16 do
	 for y = 16, 128, 16 do
	  self.grid[x][y]:update()
	 end
	end
 
 -- update camera
 cam.frame += 1
 if cam.frame > #cam.sequence then
  cam.frame = #cam.sequence
 end
 
 -- update hud animations
 if gametype == 1 or score.movesleft == 0 then
	 self.secondtimer -= 1/60
	 if self.secondtimer <= 0 then
	  self.secondtimer += 1
	  if score.timeleft < 10 then
	   hud:tickdown(true)
	  end
	 end
	else
	 self.secondtimer = 1
	end
end

function state.gameplay:draw()
 cls()
 
 camera(cam.sequence[cam.frame][1], cam.sequence[cam.frame][2])
 
 -- draw grid
 clip(2, 18, 126, 108)
 rectfill(0, 0, 128, 128, gridpalette[currentpalette][1])
	for x = 0, 128, 16 do
	 for y = 16, 112, 16 do
	  local a = self.grid[x][y]
	  local b = self.grid[x][y+16]
	  line(a.x, a.y, b.x, b.y, gridpalette[currentpalette][2])
	 end
	end
	for x = 0, 112, 16 do
	 for y = 16, 128, 16 do
	  local a = self.grid[x][y]
	  local b = self.grid[x+16][y]
	  line(a.x, a.y, b.x, b.y, gridpalette[currentpalette][3])
	 end
	end
	clip()
 
 drawborder()
 	
	-- draw entities
 for b in all(blackholes) do
  b:draw()
 end
 player:draw()
 for d in all(dots) do
  d:draw()
 end
 for e in all(effects) do
  e:draw()
 end
 
 camera()
end



-- results screen
state.results = {}

function state.results:enter()
 sfx(-1, 0)
 sfx(-1, 1)
 sfx(-1, 2)
 sfx(-1, 3)
 sfx(31)

 self.newhighscore = false
 if score.score > dget(gametype-1) then
  self.newhighscore = true
  dset(gametype-1, score.score)
 end
 
 self.statetimer = 4
 self.displayscore = 0
end

function state.results:update()
 if self.statetimer > 0 then
	 self.statetimer -= 1/60
	 if self.statetimer <= 0 then
	  if self.newhighscore then
	   sfx(32)
	  end
	 end
	end

 if self.statetimer <= 2 then
  if self.displayscore < score.score then
   if stat(16) ~= 34 then
	   sfx(34, 0)
	  end
	  self.displayscore += score.score/100
	  if self.displayscore > score.score then
	   self.displayscore = score.score
	  end
	 else
	  if stat(16) == 34 then
	   sfx(26, 0)
	  end
	 end
	end

 if self.statetimer <= 0 then
	 if btnp(4) then
 	 gotostate(state.transition, state.intro, true)
	 end
	 if btnp(5) then
	  gotostate(state.transition, state.title, true)
  end
 end
end

function state.results:draw()
 state.gameplay:draw()

 rectfill(8, 32, 120, 96, 0)
 
 if self.statetimer <= 2 then
	 printc('final score', 65, 41, 5)
	 printc('final score', 64, 40, 12)
	 local s = flr(self.displayscore)
	 if s > 0 then
	  s = s .. '00'
	 end
	 printc(s, 65, 49, 5)
	 printc(s, 64, 48, 7)
	else
	 if gametype == 1 then
	 	printc('time up!', 65, 65, 5)
		 printc('time up!', 64, 64, 7)
		elseif gametype == 2 then
		 printc('out of moves!', 65, 65, 5)
		 printc('out of moves!', 64, 64, 7)
		end
	end
	
	if self.statetimer <= 0 then
	 if self.newhighscore then
	  printc('new high score!', 65, 65, 5)
	  printc('new high score!', 64, 64, 10)
	 end
	 printc('Ž retry    — menu', 65, 81, 5, 1)
	 printc('Ž retry    — menu', 64, 80, 12, 1)
	end
end



-- intro sequence
state.intro = {}

function state.intro:enter()
 self.rings = {}
 for i = 1, 8 do
  self.rings[i] = {
   startr = 16*i,
   extrar = rnd(128),
   targetr = i/4,
  }
  self.rings[i].r = self.rings[i].startr
 end
 
 self.timer = 2
 
 if gametype == 3 then
  sfx(28)
  sfx(37)
 else
	 sfx(27)
	 sfx(28)
	end
end

function state.intro:update()
 for i = 1, #self.rings do
  local r = self.rings[i]
  r.r -= r.startr/120
  r.extrar = lerp(r.extrar, 0, .05)
 end
 
 self.timer -= 1/60
 if self.timer <= 0 then
  sfx(-1, 0)
  sfx(-1, 1)
  sfx(-1, 2)
  sfx(-1, 3)
  if gametype == 3 then
   sfx(38)
   sfx(39)
  else
	  sfx(9)
	 end
  gotostate(state.gameplay)
 end
end

function state.intro:draw()
 cls()
 
 clip(2, 18, 126, 108)
 
 -- draw rings
 for i = 1, #self.rings do
  local r = self.rings[i]
  local c = i % 2 == 0 and 12 or 3
  if gametype ~= 3 then
   c = i + 4
  end
  circ(64, 64, r.r + r.extrar + r.targetr, c)
 end
 
 clip()
end



state.transition = {}

function state.transition:enter(s, crop)
 self.r = 1
 self.s = s
 self.crop = crop
 sfx(30)
end

function state.transition:update()
 self.r *= 1.15
 if self.r > 10000 then
  gotostate(self.s)
 end
end

function state.transition:draw()
 --rectfill(0, 0, self.x, 128, 0)
 if self.crop then
  clip(0, 16, 128, 112)
 end
 circfill(64, 64, self.r, 0)
 circfill(64, 64, self.r/2, gridpalette[currentpalette][1])
 circfill(64, 64, self.r/4, 0)
 clip()
end


-- title screen
state.title = {}

function state.title:enter()
 music(0)
 poke(0x5f42, 2)
end

function state.title:update()
 if btnp(5) then
  gametype += 1
  if gametype > 3 then
   gametype = 1
  end
  sfx(36)
 end
 if btnp(4) then
  music(-1)
  poke(0x5f42, 0)
  gotostate(state.transition, state.intro, true)
 end
end

function state.title:draw()
 cls()
 
 clip(2, 18, 126, 108)
 
 rectfill(0, 0, 128, 128, gridpalette[currentpalette][1])

 -- draw grid
 for x = 0, 128, 16 do
  line(x, 16, x, 128, gridpalette[currentpalette][2])
 end
 for y = 16, 128, 16 do
  line(0, y, 128, y, gridpalette[currentpalette][3])
 end
 
 clip()
 
 drawborder()

 -- draw title
 for i = 0, 4 do
  local s = 6 + i * 2
  local x = 128/2 - (15*5)/2 + 15*i
  local y = 32 + 3.99 * sin(uptime/60 - 1/15*i)
  spr(s, x, y, 2, 2)
 end
 
 printc('strategic kinetic', 65, 53, 5)
 printc('strategic kinetic', 64, 52, 7)
 printc('action videogame', 65, 61, 5)
 printc('action videogame', 64, 60, 7)
 
 -- instructions
 camera(0, 1.99 * sin(uptime / 120) + 4)
 
 printc('hold ”ƒ‹‘ to aim', 65, 81, 5, 4)
 printc('hold ”ƒ‹‘ to aim', 64, 80, 12, 4)
 
 printc('hold Ž to charge', 65, 89, 5, 1)
 printc('hold Ž to charge', 64, 88, 12, 1)
 
 printc('release Ž to launch!', 65, 97, 5, 1)
 printc('release Ž to launch!', 64, 96, 12, 1)
 
 local s
 if gametype == 1 then
  s = '— reflexive    Ž start'
 elseif gametype == 2 then
  s = '— cerebral     Ž start'
 elseif gametype == 3 then	
  s = '— sensory      Ž start'
 end
 printc(s, 65, 113, 5, 1)
 printc(s, 64, 112, 14, 1)
 
 camera()
end



-- main loop --
function _init()
	gotostate(state.transition, state.title)
end

function _update60()
 uptime += 1
 state.current:update()
 hud:update()
end

function _draw()
 state.current:draw()
 if state.current ~= state.transition then
	 hud:draw()
	end
end

__gfx__
00000000000aa000000bb00000055000000550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000a99a000bbaabb000555500055555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000a9aa9a00babbab00555555005555550000000000c777777777777000c777777777777000c777777777777000c777777777777000c770000000c7700
00077000a9aaaa9abab33bab5555555555555555000000000c777777777777000c777777777777000c777777777777000c777777777777000c770000000c7700
00077000a9aaaa9abab33bab5555555555555555000000000c770000000c77000c77eeeeeeeeee000deeeed77eeeee000deeeed77eeeee000c770000000c7700
007007000a9aa9a00babbab00555555005555550000000000c770000000c77000c77000000000000000000c770000000000000c7700000000c770000000c7700
0000000000a99a000bbaabb00055550005555550000000000c770000000c77000c77000000000000000000c770000000000000c7700000000c770000000c7700
00000000000aa000000bb0000005500000055000000000000c770000000c77000c77777700000000000000c770000000000000c7700000000c77777777777700
00cccccccccccccccccccc0000cccccccccccccccccccc000c770000000c77000c77777700000000000000c770000000000000c7700000000c77777777777700
0c66666666666666666666c00c66666666666666666666c00c770000000c77000c77eeee00000000000000c770000000000000c7700000000deeeeeeeeed7700
c6000000000000000000006cc6000000000000000000006c0c770000000c77000c77000000000000000000c770000000000000c77000000000000000000c7700
c6000000000000000000006cc6000000000000000000006c0c770000000c77000c77000000000000000000c770000000000000c77000000000000000000c7700
c6000000000000000000006cc6000000000000000000006c0c770000000c77000c77777777777700000000c770000000000000c7700000000c77777777777700
c6000000000000000000006cc6000000000000000000006c0c770000000c77000c77777777777700000000c770000000000000c7700000000c77777777777700
c6000000000000000000006cc6000000000000000000006c0dee0000000dee000deeeeeeeeeeee00000000dee0000000000000dee00000000deeeeeeeeeeee00
c6000000000000000000006cc6000000000000000000006c00000000000000000000000000000000000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c00000000000000000000000000000000000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c00000000000000000000000000000000000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c0c770000000c77000c770000000c7700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c00c7700000c77e000c777000000c7700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c000c77000c77e0000c777700000c7700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c0000c770c77e00000c777770000c7700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c00000c7777e000000c777777000c7700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c000000c77e0000000c77e777700c7700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c000000c7700000000c770e77770c7700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c000000c7700000000c7700e7777c7700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c000000c7700000000c77000e77777700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c000000c7700000000c770000e7777700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c000000c7700000000c7700000e777700000000000000000000000000000000000000000000000000
c6000000000000000000006cc6000000000000000000006c000000c7700000000c77000000e77700000000000000000000000000000000000000000000000000
0c66666666666666666666c00c66666666666666666666c0000000dee00000000dee0000000eee00000000000000000000000000000000000000000000000000
00cccccccccccccccccccc0000cccccccccccccccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00cc00cc00cc0ccc0ccc000007070777077707770000000000000000000000000000000000000000000000000000000000000000000000000777077707770777
0c055c055c0c5c5c5c55500007575057575757575000000000000000000000000000000000000000000000000000000000000000000000000075507557775755
0ccc0c500c5c5cc05cc0000007775777575757575000000000000000000000000000000000000000000000000000000000000000000000000075007507575770
005c5c500c5c5c5c0c55000000575755575757575000000000000000000000000000000000000000000000000000000000000000000000000075007507575755
0cc050cc0cc05c5c5ccc000000075777077757775000000000000000000000000000000000000000000000000000000000000000000000000075077707575777
00550005505500505055500000005055505550555000000000000000000000000000000000000000000000000000000000000000000000000005005550505055
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0a0aaa00aa0a0a0000000007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077707700000
0a5a50a55a055a5a5000000007575000000000000000000000000000000000000000000000000000000000000000000000000000000000000000075550750000
0aaa50a50a500aaa5000000007575000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700750000
0a5a50a50a5a0a5a5000000007575000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005750750000
0a5a5aaa0aaa5a5a5000000007775000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077757770000
00505055505550505000000000555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005550555000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc00
0c6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666c0
c611111111111111011111111111111101111111111111110111111111111111011111111111111011111111111111101111111111111110111111111111116c
c611111111111111011111111111111101111111111111110111111111111111011111111111111011111111111111101111111111111110111111111111116c
c611111111111111011111111111111101111111111111110111111111111111011111111111111011111111111111101111111111111110111111111111116c
c611111111111111101111111111111101111111111111110111111111111111011111111111111011111111111111101111111111111101111111111111116c
c611111111111111101111111111111110111111111111110111111111111111011111111111111011111111111111011111111111111101111111111111116c
c611111111111111101111111111111110111111111111110111111111111111011111111111111011111111111111011111111111111101111111111111116c
c611111111111111101111111111111110111111111111110111111111111111011111111111111011111111111111011111111111111101111111111111116c
c611111111111111110111111111111110111111111111110111111111111111011111111111111011111111111111011111111111111101111111111111116c
c611111111111111110111111111111110111111111111110111111111111111011111111111111011111111111111011111111111111101111111111111116c
c611111111111111110111111111111110111111111111110111111111111111011111111111111011111111111111011111111111111011111111111111116c
c611111111111111110111111111111110111111111111110111111111111111011111111111111011111111111111011111111111111011111111111111116c
c611111111111111111011111111111111011111111111111011111111111111011111111111110111111111111110111111111111111011111111111111116c
c611111111111111111011111111111111011111111111111011111111111111011111111111110111111111111110111111111111111011111111111111116c
c611111111111111111011111111111111011111111111111011111111111111011111111111110111111111111110111111111111111011111111111111116c
c600111111111111111011111111111111011111111111111011111111111111011111111111110111111111111110111111111111110111111111111111116c
c611000111111111111101111111111111011111111111111011111111111111011111111111110111111111111110111111111111110111111111111111006c
c611111001111111111101111111111111011111111111111011111111111111011111111111110111111111111110111111111111110111111111111000116c
c611111110001111111101111111111111011111111111111011111111111111011111111111110111111111111110111111111111110111111111100111116c
c611111111110001111101111111111111101111111111111011111111111111011111111111110111111111111110111111111111110111111100011111116c
c611111111111166611110111111111111101111111111111011111111111111011111111111110111111111111101111111111111110111110011111111116c
c611111111116677766770111777111111101111111111111011111111111111011111111111110111111111111101111111111111101110001111111111116c
c611111111116777776777777777770707000000000111111011111111111111011111111111110111111111111101111111111111101001111111111111116c
c611111111167777777677777777777777707171711000000000000000000000000000000000000000000000000000000000000000000111111111111111116c
c611111111167777777677777777771717101111111111111011111111111111011111111111110111111111111101111111111111101111111111111111116c
c611111111167777777677777777111111101111111111111011111111111111011111111111110111111111111101111111111111101111111111111111116c
c611111111116777776777777711111111101111111111111011111111111111011111111111110111111111111101111111111111101111111111111111116c
c611111111116677766770111111111111101111111111111011111111111111011111111111110111111111111101111111111111101111111111111111116c
c611111111111166611110111111111111101111111111111011111111111111011111111111110111111111111101111111111111101111111111111111116c
c611111111111111111110111111111111101111111111111011111111111111011111111111110111111111111101111111111111101111111111111111116c
c611111111111111111111011111111111110111111111111011111111111111011111111111110111111111111101111111111111101111111111111111116c
c600111111111111111111011111111111110111111111111101111111111111011111111111110111111111111101111111111111011111111111111111116c
c611000011111111111111011111111111110111111111111101111111111111011111111111110111111111111101111111111111011111111111111110006c
c611111100001111111111011111111111110111111111111101111111111111011111111111110111111111111101111111111111011111111111110001116c
c611111111110000111111011111111111110111111111111101111111111111011111111111110111111111111101111111111111011111111110001111116c
c611111111111111000011011111111111110111111111111101111111111111011111111111110111111111111101111111111111011111110001111111116c
c611111111111111111100000000001111110111111111111101111111111111011111111111110111111111111101111111111111011110001111111111116c
c611111111111111111111011111110000000000000011111101111111111111011111111111110111111111111101111111111111010001111111111111116c
c611111111111111111111011111111111110111111100000000000000000000000000001111110111111111111101111111000000001111111111111111116c
c611111111111111111111011111111111110111111111111101111111111111011111110000000000000000000000000000111111011111111111111111116c
c611111111111111111111011111111111110111111111111101111111111111011111111111110111111111111101111111111111011111111111111111116c
c611111111111111111111011111111111110111111111111101111111111111011111111111110111111111111101111111111111011111111111111111116c
c611111111111111111111011111111111110111111111111101111111111111011111111111110111111111111101111111111111011111111111111111116c
c611111111111111111111011111111111110111111111111101111111111111011111111111110111111111111101111111111111011111111111111111116c
c611111111111111111111101111111111110111111111111101111111111111011111111111110111111111111101111111111111011111111111111111116c
c61111111111111111111110111c77777777777711c77777777777711c777777777777111111110111111111111101111111111111011111111111111111116c
c61111111111111111111110111c77777777777711c77777777777711c777777777777111111110111111111111101111111111111011111111111111111116c
c60001111111111111111110111c771111111c7711c77eeeeeeeeee11deeeed77eeeee11c777777777777111111101111111111110111111111111111111116c
c61110000011111111111110111c771111111c7711c7711111101111111111c770111111c77777777777711c771101111c77111110111111111111111110006c
c61111111100000011111110111c771111111c7711c7711111101111111111c770111111deeeed77eeeee11c771101111c77111110111111111111110001116c
c61111111111111100000110111c771111111c7711c7777771101111111111c77011111111111c771111111c771101111c77111110111111111110001111116c
c61111111111111111111000000c770111111c7711c7777771101111111111c77011111111111c771111111c771101111c77111110111111100001111111116c
c61111111111111111111110111c771000000c7700c77eeee1101111111111c77011111111111c771111111c771101111c77111110111100011111111111116c
c61111111111111111111110111c771111111c7711c7700000000000000111c77011111111111c771111111c777777777777111110100011111111111111116c
c61111111111111111111110111c771111111c7711c7711111101111111000c77000000000000c770000000c777777777777000000011111111111111111116c
c61111111111111111111110111c771111111c7711c7777777777771111111c77011111111111c771111111deeeeeeeeed77111110111111111111111111116c
c61111111111111111111110111c771111111c7711c7777777777771111111c77011111111111c7711111111111101111c77111110111111111111111111116c
c61111111111111111111110111dee1111111dee11deeeeeeeeeeee1111111dee011111111111c7711111111111101111c77111110111111111111111111116c
c6111111111111111111111011111111111110111111111111110111111111111011111111111c771111111c777777777777111110111111111111111111116c
c6111111111111111111111011111111111110111111111111110111111111111011111111111dee1111111c777777777777111110111111111111111111116c
c61111111111111111111110111111111111110111111111111101111111111110111111111111011111111deeeeeeeeeeee111110111111111111111111116c
c6111111111111111111111011111111111111011111111111110111111111111011111aa111110111111111111101111111111110111111111111111111116c
c611111111111111111111101111111111111101111111111111011111111111110111a99a11111011111111111101111111111101111111111111111111116c
c60000001111111111111110111111111111110111111111111101111111111111011a9aa9a1111011111111111011111111111101111111111111111111106c
c6111111000000000011111011111111111111011111111111110111111111111101a9aaaa9a111011111111111011111111111101111111111111111000016c
c6111111111111111100000000000001111111011111111111111011111111111101a9aaaa9a511011111111111011111111111101111111111100000111116c
c61111111111111111111110111111100000000000111111111110111111111111011a9aa9a5511011111111111011111111111101111110000011111111116c
c611111111111111111111101111111111111101110000000011101111111111110111a99a55111011111111111011111111111101100001111111111111116c
c6111111111111111111111011111111111111011111111111000000000011111101111aa551111011111111111011111111100000011111111111111111116c
c611111111111111111111101111111111111101111111111111101111110000000000005511111011111111111011100000011101111111111111111111116c
c611111111111111111111101111111111111101111111111111101aa1111111110111111000000000000000000000011111111101111111111111111111116c
c61111111111111111111110111111111111110111111111111110a99a111111110111111111111011111111111011111111111101111111111111111111116c
c6111111111111111111111011111111111111011111111111111a9aa9a11111110111111111111011111111111011111111111101111111111111111111116c
c611111111111111111111110111111111111101111111111111a9aaaa9a1111111011111111111011111111111011111111111101111111111111111111116c
c611111111111111111111110111111111111110111111111111a9aaaa9a5111111011111111111011111111110111111111111101111111111111111111116c
c6111111111111111111111101111111111111101111111111111a9aa9a55111111011111111111011111111110111111111111101111111111111111111116c
c61111111111111111111111011111111111111011111111111111a99a551aa1111011111111111011111111110111111111111011111111111111111111116c
c611111111111111111111110111111111111110111111111111110aa551a99a111011111111111011111111110111111111111011111111111111111111116c
c6111111111111111111111101111111111111101111111111111101551a9aa9a11011111111111011111111110111111111111011111111111111111111116c
c600000000000111111111110111111111111110111111111111110111a9aaaa9a1011111111111011111111110111111111111011111111111111111111006c
c611111111111000000000000000000000000000000111111111110111a9aaaa9a5011111111111011111111110111111111111011111111111100000000116c
c6111111111111111111111101111111111111101110000000011101111a9aa9a55101111111111011111111101111111111111011110000000011111111116c
c61111111111111111111111011111111111111011111111111000000011a99a551101111111111011111111101111111111000000001111111111111111116c
c611111111111111111111110111111111111110111111111111110111000aa5511101111111111011111111101110000000111011111111111111111111116c
c611111111111111111111110111111111111110111111111111110111111155100000aa1111111011111110000001111111111011111111111111111111116c
c61111111111111111111111011111111111111011111111111111011111111111110a99a000011011000001101111111111111011111111111111111111116c
c6111111111111111111111101111111111111101111111111111110111111111111a9aa9a11100000111111101111111111110111111111111111111111116c
c611111111111111111111111011111111111110111111111111111011111111111a9aaaa9a1111011111111011111111111110111111111111111111111116c
c611111111111111111111111011111111111111011111111111111011111111111a9aaaa9a5181011111111011111111111110111111111111111111111116c
c6111111111111111111111110111111111111110111111111111110111111111111a9aa9a55181081111111011111111111110111111111111111111111116c
c61111111111111111111111101111111111111101111111111111101111111111111a99a551118081811811011111111111110111111111111111111111116c
c611111111111111111111111011111111111111011111111111111011111111111111aa5518118888818110181111111111110111111111111111111111116c
c611111111111111111111111011111111111111011111111111111101111111111111055811880000088110811111111111101111111111111111111111116c
c611111111111100000000000000000001111111011111111111111101111111111111011188000000000888111111111111101111111111111111111111116c
c600000000000011111111110111111110000000000000000000000000000000111118801180000000000080118811111100000000000000000000000000006c
c611111111111111111111110111111111111111011111111111111101111111000000088880000000000088880000000011110111111111111111111111116c
c611111111111111111111101111111111111110111111111111111011111111111111101800000000000008001111111111110111111111111111111111116c
c611111111111111111111101111111111111110111111111111111011111111111111888800000000000008111111111111111011111111111111111111116c
c611111111111111111111011111111111111101111111111111110111111111111111011800000000000008888111111111111101111111111111111111116c
c611111111111111111111011111111111111101111111111111110111111111111110111800000000000008011111111111111101111111111111111111116c
c611111111111111111110111111111111111011111111111111101111111111111110118800000000000008801111111111111110111111111111aa1111116c
c61111111111111111111011111111111111101111111111111110111111111111110111118000000000008110111111111111111011111111111a99a111116c
c6111111111111111111011111111111111101111111111111110111111111111111011118800000000000811101111111111111110111111111a9aa9a11116c
c611111111111111111101111111111111110111111111111111011111111111111011111118000000000811111011111111111111101111111a9aaaa9a1116c
c611111111111111111011111111111111101111111111111110111111111111111011111118880000088111111011111111111111101111111a9aaaa9a5116c
c6111111111111111110111111111111111011111111111111101111111111111101111111811888888118111111011111111111111101111111a9aa9a55116c
c61111111111111111011111111111111101111111111111110111111111111111011111181118181118111111111011111111111111101111111a99a551116c
c611111111111111110111111111111111011111111111111101111111111111101111111111181811181111111110111111111111111011111111aa5511116c
c611111111111111101111111111111110111111111111111011111111111111101111111111811811111111111111011111111111111101111111155111116c
0c6666666666666666666666666666666666666666666666666666666666666666666666666686686666666666666666666666666666666666666666666666c0
00cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc00

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011141411111414111114141111141500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021242421212424212124242121242500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2324212124242121242421212424212200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2324212124242121242421212424212200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021242421212424212124242121242500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021242421212424212124242121242500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2324212124242121242421212424212200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2324212124242121242421212424212200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021242421212424212124242121242500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021242421212424212124242121242500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2324212124242121242421212424212200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2324212124242121242421212424212200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021242421212424212124242121242500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3031343431313434313134343131343500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
01030000184501c4501f450244501f4501c4501845021700167002270016700167001670016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
01030000194501d4502045025450204501d4501945021700167002270016700167001670016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001a4501e4502145026450214501e4501a45021700167002270016700167001670016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001b4501f4502245027450224501f4501b45021700167002270016700167001670016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001c45020450234502845023450204501c45021700167002270016700167001670016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010200001d45021450244502945024450214501d45021700167002270016700167001670016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001e45022450254502a45025450224501e45021700167002270016700167001670016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001f45023450264502b45026450234501f45021700167002270016700167001670016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
0004000002120031200512006120081200a1200d1200f1201012012120141201612017120191201b1201c1201e120211202312025120281202a1202c1202e12030120321203412036120381203c1203e1203f120
000100003d6303c6303b6303963037630356303463032630316302f6302d6202c6202a620286202862025620246202362021620206101e6101d6101a610196101761014610126100f6100d610096100561001610
000100000f0400c0400a0400804007040060400504004040030400204001040010400104001000170001600016000160001500014000140001400013000110000f0000d0000a0000600003000020000000000000
01030000184501c4501f45024450284502b450304502b45028450244501f4501c4501845016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
01030000194501d4502045025450294502c450314502c4502945025450204501d4501945016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001a4501e45021450264502a4502d450324502d4502a45026450214501e4501a45016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001b4501f45022450274502b4502e450334502e4502b45027450224501f4501b4501b000167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001c4502045023450284502c4502f450344502f4502c4502845023450204501c45016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010200001d4502145024450294502d4503045029450304502d4502945024450214501d4501d000167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001e45022450254502a4502e4503145036450314502e4502a45025450224501e45016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010300001f45023450264502b4502f4503245037450324502f4502b45026450234501f45016700167001670024300167001670016700167001670017700177001700017700177001670016700167001670016700
010500002457023570215701f5701d5701c5701a570185702457023570215701f5701d5701c5701a570185702457023570215701f5701d5701c5701a570185702a5002550023500215001f5001e5001c5001a500
0003002005050227500505028750060502d750060503375007050367500705038750080503875008050367500705032750070502d75006050267500605020750050501975005050147500405018750040501c750
010600000c0530e05310053120531405316053180531a0531c0531e05320053220532405326053280532a0532c0532e05330053320533405336053380533a0533c053320033400336003380033a0033c00332003
000300000a0500c0500c0500905007050050500405004050050500605007050070500605004050020500205001050010500105000050000500005002000010000100001000010000200002000020000100001000
000200002415024150241502415024150241501f1501f1501f1501f1501f1501f1501a1501a1501a1501a1501a1501a1501515015150151501515015150151501515015150151501515015150151501515015150
000200003f61020610016000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400000c050150500d050160500e050170500f050180501005019050110501a050120501b050130501c050140501d050150501e050160501f0501705020050180502105019050220501a050230501b05024050
0106000024054290540e0020f0021000211002120021300214002150021600217002190021a0021b0021c0021d0021e0021f002200022100222002230022400225002260022700228002290022a0022b0022c002
00080000037550a755147551c755237552b755347553d7553f7553d7553975535755307552d7552a75526755237551f7551d7551a7551775514755107550e7550c75509755087550675505755037550275501755
01080000036200a620146201c620236202b620346203d6203f6203d6203962035620306202d6202a62026620236201f6201d6201a6201762014620106200e6200c62009620086200662005620036200262001620
010700003015530600301053010530105301003010507701000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000242501f250242301f230242101f2102f2051b0053c005360052f00528005210051c0051800514005110050e0050c0050a00508005070050600505005050050400503005020050100501005010051f005
000500000014005140071400c1401114013140181401d1401f14024140291402b1403014035140371403c1403714035140301402b14029140241401f1401d1401814013140111400c1400714005140001401a105
010700002015025150271502c1502215027150291502e15024150291502b150301503015000100001000010000000000000000000000000000000000000000000000000000000000000000000000000000000400
00050000180500000019050000001a050000001b050000001c050000001d050000001e050000001f0500000020050000002105000000220500000023050000002405025000250500000026050000002705000500
0006000124054290020e0020f0021000211002120021300214002150021600217002190021a0021b0021c0021d0021e0021f002200022100222002230022400225002260022700228002290022a0022b0022c002
010500001f0551905507005001050c105001050c1050010500005070050c1050000507005000050710505005001050010507005001050c105001050c1050010500005070050c1050000507005000050710511005
01080000242551f200242001f200242001f2002f2051b0053c005360052f00528005210051c0051800514005110050e0050c0050a00508005070050600505005050050400503005020050100501005010051f005
01090000150261a0261c02625026150261a0261c02625026150361a0361c03625036150361a0361c03625036150361a0361c03625036150361a0361c03625036150361a0361c03625036150361a0361c03625036
01ff0000094550010507005001050c105001050c1050010500005070050c1050000507005000050710505005001050010507005001050c105001050c1050010500005070050c1050000507005000050710511005
01ff00001c4550010507005001050c105001050c1050010500005070050c1050000507005000050710505005001050010507005001050c105001050c1050010500005070050c1050000507005000050710511005
00ff0000340050010507005001050c105001050c1050010500005070050c1050000507005000050710505005001050010507005001050c105001050c1050010500005070050c1050000507005000050710511005
01050000180000000019000000001a000000001b000000001c000000001d000000001e000000001f0000000020000000002100000000220000000023000000002400025000250000000026000000002700000500
01ff0000094050010507005001050c105001050c1050010500005070050c1050000507005000050710505005001050010507005001050c105001050c1050010500005070050c1050000507005000050710511005
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000275172a5172e51730517275172a5172e51730517275272a5272e52730527275272a5272e52730527275372a5372e53730537275372a5372e53730537275472a5472e54730547275472a5472e54730547
01100000295572a5572e55731557295572a5572e55731557295472a5472e54731547295472a5472e54731547295372a5372e53731537295372a5372e53731537295272a5272e52731527295272a5272e52731527
011000000845508445031550343508455084451435508445081550f15514455084451444514455051550814508455084450315503435084550844514355084450a1550a155123550644511355054450d35501445
01100000275172a5172e51731517275172a5172e51731517275272a5272e52731527275272a5272e52731527275372a5372e53731537275372a5372e53731537275472a5472e54731547275472a5472e54731547
011000000a05300000000000a053000030000000000090430a05300000000000a0530c0030000000000000000a0530a000000000a0530c0030000000000090430a05300000160000a0530c003000000000000000
01100000306352f6252162513625306352f6252162513625306352f6252162513625306352f6252162513625306352f6252162513625306352f6252162513625306352f6252162513625306352f625216250c625
011000000f4550f445031550a4350f4550f4451b3550f445031550a1550f4550a4450f4450f45500155031450f4550f445031550a4350f4550f4451b3550f445031550a155193550d445183550c445163550a445
__music__
01 3f3e3d7c
00 3f3e3d7a
00 3b3e3d79
00 3f3e3d7a
00 3f3e3d3c
00 3f3e3d3a
00 3b3e3d39
02 3f3e3d3a
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

