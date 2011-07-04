local debug = not true

--LOAD EXTERNAL LIBS
local ui = require("ui")
local analytics = require("analytics")
local of = require("openfeint")
local _of={
	app_id = "217503",
	product_key	= "MbIlSMV5RLGRFGOmmco3UA",
	product_secret = "JIUcsEoBJogECixw2xDv1LR4ReaoSfabGWNEZRIs"
}
of.init(_of.product_key,_of.product_secret,"Zen Hopper",_of.app_id)
--of.launchDashboard("")
--"leaderboards"
--"challenges"
--"achievements"
--"friends"
--"playing"
--"highscore" NOTE: in this case an additional options table (see below)


analytics.init("YBKUTRHYXFATI5EF72UH")
analytics.logEvent("Game Loaded")

display.setStatusBar( display.HiddenStatusBar )
system.setIdleTimer(false)

--AUDIO
local audio_maintrack = audio.loadStream("music.wav")
local channel_maintrack = audio.play(audio_maintrack,{channel=2,loops=-1})
local channel_fx
local fx_miss1 = audio.loadStream("miss1.wav")
local fx_miss2 = audio.loadStream("miss2.wav")
local fx_miss3 = audio.loadStream("miss3.wav")
local fx_miss4 = audio.loadStream("miss4.wav")
local fx_step = audio.loadStream("step.wav")
local fx_levelup = audio.loadStream("levelup.wav")
local fx_die = audio.loadStream("die.wav")
local a_miss_sounds = {fx_miss1,fx_miss2,fx_miss3,fx_miss4}


--TABLES
--PILLAR TABLE
Pillar={}
function Pillar:new()
	local object = {} 
	local currentImage
	local imageOn
	local imageOff
	local alive
	local index
	local clicked
	return object
end
local pillars={}
local PILLARCOUNT = 20
--PILLAR END

--VARIABLES
local gt
local framelag = 0
local lasttime = 0
local score = 0
local level = 0
local misses = 0
local INIT_lives = 2
local lives = INIT_lives
local zenscore = 0
local state = 0
if debug then state = 3 end
local MAINMENU = 3
local IDLE = 4
local CREDITSVIEW=5
local GUIDEVIEW = 6
local LOADGAME = 7
local GAMELOOP = 8
local MISS_THRESHOLD = 3
local INIT_pillar_spawn_delay = 900
local INIT_target_speed = 0.01
local pillar_spawn_delay = INIT_pillar_spawn_delay
local next_pillar_index = 1
local pillar_speed = INIT_target_speed
local target_speed = INIT_target_speed
local font = "shanghai"
local leveltimer = {
	lasttime = 0,
	time_between_levels = 10000	
}
--animation states
local ANIM_MISS = 0
local ANIM_LEVELUP = 1
local ANIM_GAMEOVER = 2
local ANIM_IDLE = 3
local ANIM_ZENHOP = 4
local animstate = ANIM_IDLE


--FULL SCREEN TEXTURES
local bg_rect = display.newRect(0,0,320,480)
bg_rect:setFillColor(50,50,50)
local bg = display.newImage("Default.png")
local credits = display.newImage("CreditsBackground.png")
local instructions = display.newImage("InstructionsBackground.png")
local gameover = display.newImage("GameOverBackground.png")

--bg.isVisible = false
credits.isVisible = false
instructions.isVisible = false
gameover.isVisible = false


local function levelup()
	if state ~= GAMELOOP then return end
	
	--increse difficulty	
	target_speed = target_speed + 0.08
	if level == 0 then pillar_speed = target_speed end
	
	if level ~= 0 then 
		pillar_spawn_delay = pillar_spawn_delay - 140 
		animstate = ANIM_LEVELUP
	end
	
	if pillar_spawn_delay < 200 then pillar_spawn_delay = 200 end
	
	--print("level up!")
	level = level + 1
	txt_level.text = "level:::" .. level
	channel_fx = audio.play(fx_levelup)
	

	
	
	print("--------LEVEL " .. level .. " DATA-------")
	print("pillar speed:      " .. pillar_speed)
	print("target speed:      " .. target_speed)
	print("pillar spawn delay:" .. pillar_spawn_delay)
end

local function onPillarTouch(e)
	if e.phase == "began" then
		--GET TABLE RELATED TO THE EVENT
		 local pillar = e.target._parent--image parent table
		 local x = pillar.currentImage.x
		 local y = pillar.currentImage.y
		 pillar.currentImage:removeSelf()
		 pillar.currentImage = display.newImage("Pole_On.png")
		 pillar.currentImage.x = x
		 pillar.currentImage.y = y
		 pillar.clicked = true
	end
	return true
end

local touchbuffer = 20
local function onScreenTouch(e)
	if e.phase ~= "began" then return end
	--check pillar collisions
	local p
	local hit = false
	for i=1, PILLARCOUNT do 
		p = pillars[i]
		local x = p.currentImage.x
		local y = p.currentImage.y
		if 		e.x >= (x - 32) - touchbuffer
			and e.x <= x + 32 + touchbuffer
			and e.y >= (y - 64) - touchbuffer
			and e.y <= y + touchbuffer
			then
			
			--check for zen hop touch
			local zenbuffer = 10
			if 		e.x >= x - zenbuffer
				and e.x <= x + zenbuffer
				and e.y >= (y-64) + zenbuffer
				and e.y <= (y) - zenbuffer
				then
				animstate = ANIM_ZENHOP
				score = score + 1000
			end	
			
			score = score + 100
			txt_score.text = "score:::" .. score
			p.clicked = true
			p.currentImage.y = -p.currentImage.y
			p.currentImage.isVisible = false
			p.currentImage = p.imageOn
			p.currentImage.isVisible = true
			p.currentImage.x = x
			p.currentImage.y = y
			if math.random() < 0.1 then
				--random miss
				local r = math.random(1,4)
				channel_fx = audio.play(a_miss_sounds[r])
			else
				channel_fx = audio.play(fx_step)
			end
			hit = true
			return
		end
	end
	
	if not hit and state == GAMELOOP then
		if lives == 0 then
			state = GAMEOVER
			return
		end
		
		if not debug then
			lives = lives -1 end
		txt_lives.text = "lives:::" .. lives
		animstate = ANIM_MISS
	end
end
Runtime:addEventListener("touch",onScreenTouch)

--CONSTRUCTOR
local function main()
	--create pillar objects
	for i=PILLARCOUNT,1,-1 do 
		pillars[i] = Pillar:new()
		pillars[i].imageOff = display.newImage("Pole_Off.png")
		pillars[i].imageOn = display.newImage("Pole_On.png")
		pillars[i].imageOn.isVisible = false
		pillars[i].currentImage = pillars[i].imageOff
		pillars[i].currentImage.y = -pillars[i].currentImage.height
		pillars[i].alive = false
		pillars[i].clicked = false

		--pillars[i].currentImage._parent = pillars[i]
		--pillars[i].currentImage:addEventListener("touch",onPillarTouch)
		pillars[i].index = i
		if i % 2 == 0 then
			pillars[i].currentImage.x = 320/3	
		else
			pillars[i].currentImage.x = 320/1.5
		end
		
		pillars[i].imageOn.x = pillars[i].currentImage.x
		
	end
end
main()



--TEXT FIELDS
local fontsize = 18
txt_level = display.newText("level:::1",224,450,font,fontsize)
txt_score = display.newText("score:::0",26,450,font,fontsize)
txt_lives = display.newText("lives:::" .. INIT_lives,124,10,font,fontsize)
txt_begin = display.newText(":::BEGIN:::",80,210,font,40)
txt_begin.isVisible = false

local group_hud = display.newGroup()
group_hud:insert(txt_score)
group_hud:insert(txt_level)
group_hud:insert(txt_lives)
group_hud.isVisible = false

txt_zenscore = display.newText("zen score:::0",100,450,font,fontsize)
txt_zenscore.isVisible = false

--top layer graphics
local texture_miss = display.newImage("Miss.png",100,204)
local texture_levelup = display.newImage("LevelUp.png",40,204)
local texture_zenhop = display.newImage("ZenHop.png",40,204)
texture_zenhop.isVisible = false
texture_miss.isVisible = false
texture_levelup.isVisible = false

local function loadMainMenu(event)

	if event.phase == "began" then
		if credits.isVisible then 
			--transition.to(credits,{alpha=0})
			credits.isVisible = false
		elseif instructions.isVisible then 
			--transition.to(instructions,{alpha=0})
			instructions.isVisible = false
		else
			gameover.isVisible = false
		end
		
		bg.isVisible = true
		
		state = MAINMENU
	end
	--print("click dood")
end

credits:addEventListener("touch",loadMainMenu)
instructions:addEventListener("touch",loadMainMenu)
gameover:addEventListener("touch",loadMainMenu)



--BUTTONS
--local btn_back = display.newImage("Back.png")

local function handleCreditsBtn(event) state = CREDITSVIEW end
local function handleGuideBtn(event) state = GUIDEVIEW end
local function handlePlayBtn(event) state = LOADGAME end

local btn_play = ui.newButton{
	default = "Play.png",
	onPress = handlePlayBtn	
}
local btn_credits = ui.newButton{
	default = "Credits.png",
	onPress = handleCreditsBtn
}
local btn_guide = ui.newButton{
	default = "Guide.png",
	onPress = handleGuideBtn
}

--SET BUTTON POSITIONS
buttons = {btn_play,btn_guide,btn_credits}

for i=1,#buttons do 
	buttons[i].y = (60*i) + 110
	buttons[i].x = 150
	buttons[i].isVisible = false
end

--INTRO SEQUENCE 
local part = display.newImage("Part.png")
local _12 = display.newImage("12.png")
local studios = display.newImage("studios.png")
local swooshy = display.newImage("Swooshy.png")
part.alpha = 0
_12.alpha = 0
studios.alpha = 0
swooshy.alpha = 0
bg.isVisible = false
--transition.to(bg,{alpha=0,time=1000})

local function introSequence(e)

	if state == 0 then 
		transition.to(part,{alpha=1,time=400})
		transition.to(_12,{alpha=1,time=800})
		transition.to(studios,{alpha=1,time=1200})
		transition.to(swooshy,{alpha=1,time=1400})
		state = state + 1
		timer.performWithDelay(4000,introSequence,1)
	elseif state == 1 then
		transition.to(part,{alpha=0,time=400})
		transition.to(_12,{alpha=0,time=800})
		transition.to(studios,{alpha=0,time=1200})
		transition.to(swooshy,{alpha=0,time=1400})
		state = state + 1
		timer.performWithDelay(1600,introSequence,1)
	elseif state == 2 then
	
		part:removeSelf()
		_12:removeSelf()
		studios:removeSelf()
		swooshy:removeSelf()
		
		state = 3
		--PASS CONTROL TO MAIN LOOP
	end
	
end
timer.performWithDelay(1000,introSequence,1)

--SPAWN PILLAR
local function onTimer_spawnPillar(event) 
	if state ~= GAMELOOP then return end
	
	--WAKE UP PILLAR--ALIVE = TRUE
	pillars[next_pillar_index].alive = true
	
	if next_pillar_index == PILLARCOUNT then 
		next_pillar_index = 1
	else 
		next_pillar_index = next_pillar_index + 1
	end

	timer.performWithDelay(pillar_spawn_delay,onTimer_spawnPillar,1)
end

local function setIsVisible_txt_begin()
	txt_begin.isVisible = false
end

--ANIMATION LOOP
local function animationloop()
	
	if animstate == ANIM_IDLE then
		if texture_miss.alpha <= 0 and texture_miss.isVisible then 
			texture_miss.isVisible = false end
		if texture_levelup.alpha <= 0 and texture_levelup.isVisible then 
			texture_levelup.isVisible = false end
	
	--MISS
	elseif animstate == ANIM_MISS then
		texture_miss.alpha=1
		texture_miss.isVisible = true
		texture_miss.xScale = 1.4
		texture_miss.yScale = 1.4
		transition.to(texture_miss,{xScale=1,yScale=1,time=100})
		transition.to(texture_miss,{alpha=0,time=100,delay=1000})
		animstate = ANIM_IDLE
	
	--LEVEL UP
	elseif animstate == ANIM_LEVELUP then 
		--print("bam")
		texture_levelup.alpha=1
		texture_levelup.isVisible = true
		texture_levelup.xScale = 1.4
		texture_levelup.yScale = 1.4
		transition.to(texture_levelup,{xScale=1,yScale=1,time=100})
		transition.to(texture_levelup,{alpha=0,time=100,delay=1000})
		animstate = ANIM_IDLE
	
	--ZENHOP
	elseif animstate == ANIM_ZENHOP then 
		print("ZENHOP")
		texture_zenhop.alpha=1
		texture_zenhop.isVisible = true
		texture_zenhop.xScale = 1.4
		texture_zenhop.yScale = 1.4
		transition.to(texture_zenhop,{xScale=1,yScale=1,time=100})
		transition.to(texture_zenhop,{alpha=0,time=100,delay=1000})
		animstate = ANIM_IDLE
	end
	
end

--GAME
local function update(event)
	
	gt = system.getTimer()
	framelag = gt - lasttime
	lasttime = gt
	
	--CHECK LEVELUP
	if gt > leveltimer.lasttime + leveltimer.time_between_levels then
		leveltimer.lasttime= gt
		levelup()
	end
	
	--MAINMENU
	if state == MAINMENU then
		--LOAD MAIN MENU
		--transition.to(bg,{alpha=1,time=800})
		group_hud.isVisible = false
		--txt_zenscore.isVisible = true
		--SET TEXT FIELDS
		txt_lives.text = "lives:::" .. lives
		txt_score.text = "score:::" .. score
		txt_level.text = "level:::" .. level
		
		bg.isVisible = true
		for i=1,#buttons do
			buttons[i].isVisible = true
			--transition.from(buttons[i],{alpha=1})
		end
		
		--load main track
		audio.fade({channel=2,volume=1,time=1000})
		state = IDLE
		if debug then state = LOADGAME end
	elseif state == IDLE then
		--IDLE
	
	--CREDITS VIEW
	elseif state == CREDITSVIEW then
		
		for i=1,#buttons do
			buttons[i].isVisible = false
			--transition.to(buttons[i],{alpha=0,y=(500),time=i*400,delay=400,transition=easing.outQuad})
		end
		bg.isVisible = false
		credits.isVisible = true
		--transition.to(bg,{alpha=0})
		--transition.to(credits,{alpha=1})
		state = IDLE
	
	--GUIDE / INSTRUCTIONS
	elseif state == GUIDEVIEW then
		for i=1,#buttons do
			buttons[i].isVisible = false
		end
		bg.isVisible = false
		instructions.isVisible = true
		--transition.to(bg,{alpha=0})
		--transition.to(instructions,{alpha=1})
		state = IDLE
	
	--PRE GAME LOADING
	elseif state == LOADGAME then
		--LOAD GAME STUFF
		
		analytics.logEvent("Game Started")
		
		txt_begin.alpha=1
		txt_begin.isVisible = true
		transition.to(txt_begin,{alpha=0,time=1000,delay=2000,onComplete=setIsVisible_txt_begin})
		bg.isVisible = false
		for i=1,#buttons do
			buttons[i].isVisible = false
			--transition.to(buttons[i],{alpha=0,y=(500),time=i*400,delay=400,transition=easing.outQuad})
		end
		
		txt_zenscore.isVisible = false
		group_hud.isVisible = true
		
		state = GAMELOOP
		
		--timers
		onTimer_spawnPillar()
		levelup()
		
	--GAME LOOP
	elseif state == GAMELOOP then
		for i=1,PILLARCOUNT do 
			if pillars[i].alive then
				
				--check screen bounds
				if pillars[i].currentImage.y > 480 + pillars[i].currentImage.height then
				
					if not pillars[i].clicked then
						if lives == 0 then 
							if not debug then
								state = GAMEOVER end
							return
						end
						
						if not debug then
							lives = lives - 1
						end
						
						txt_lives.text = "lives:::" .. lives
					end
					
					pillars[i].alive = false
					pillars[i].clicked = false
					pillars[i].currentImage.y = -pillars[i].currentImage.height
					pillars[i].currentImage.isVisible = false
					pillars[i].currentImage = pillars[i].imageOff
					pillars[i].currentImage.isVisible = true
					pillars[i].currentImage.y = -pillars[i].currentImage.height
					
				else
					--UPDATE PILLAR Y
					if pillar_speed < target_speed then 
						pillar_speed = pillar_speed + 0.0001 
						
					end
					
					pillars[i].currentImage.y = pillars[i].currentImage.y + (pillar_speed * framelag)
				end
			end
		end
		
	elseif state == GAMEOVER then
	
		analytics.logEvent("Game Overs")
		
		--reset
		for i=1, PILLARCOUNT do 
			pillars[i].currentImage.y = -pillars[i].currentImage.height
			pillars[i].clicked = false
			pillars[i].alive = false
			
			--reset pillar texture
			pillars[i].currentImage.isVisible = false
			pillars[i].currentImage = pillars[i].imageOff
			pillars[i].currentImage.isVisible = true
			pillars[i].currentImage.y = -pillars[i].currentImage.height
			
		end
		
		lives = INIT_lives
		score = 0
		level = 0
		pillar_speed = INIT_target_speed
		misses = 0
		pillar_spawn_delay = INIT_pillar_spawn_delay
		target_speed = INIT_target_speed
		leveltimer.lasttime = 0
		
		--fade out maintrack
		audio.fade({channel=2,time=4000})
		
		fx_channel = audio.play(fx_die)
		
		gameover.isVisible = true
		state = IDLE
	end
	
	animationloop()
	
end
Runtime:addEventListener("enterFrame",update)
