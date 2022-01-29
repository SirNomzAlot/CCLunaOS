os.loadAPI("/os/info")
os.loadAPI("/os/button")
os.loadAPI("/os/graphics")
os.loadAPI("/os/textBuffer")
os.loadAPI("/os/window")

os.loadAPI("/apps/terminal")
standard = os.pullEvent
--os.pullEvent = os.pullEventRaw

local settings = info.getData()
local users = {}
local brake = false
local inPrompt=true
local currentUser=nil
local currentDir="/home"

local w,h = term.getSize()
local version = info[0]
local asleep = false

local nOption = 1
local bk = graphics.loadImage("/os/background")
local bkColor
local txtColor
local barColor
local renderStack = {}

--System Buttons

button.makeButton("systemStart",1,1,4,1,"Luna",settings["bar"],false,
function ()
	button.setVal("systemSetings","visible",not button.getVal("systemSetings","visible"))
	button.setVal("systemLogout","visible",not button.getVal("systemLogout","visible"))
	button.setVal("systemShutdown","visible",not button.getVal("systemShutdown","visible"))
	button.setVal("systemReboot","visible",not button.getVal("systemReboot","visible"))
end)

button.makeButton("systemSetings",1,2,8,1,"Settings",settings["bar"],false,
function ()
	print("opened settings")
end)

button.makeButton("systemLogout",1,3,8,1,"Logout  ", settings["bar"],false,
function ()
	button.softPress("systemStart")
	setUserProp("")
	softRestart()
end)

button.makeButton("systemShutdown",1,4,8,1,"Shutdown",settings["bar"],false,
function ()
	os.shutdown()
end)

button.makeButton("systemReboot",1,5,8,1,"Reboot  ",settings["bar"],false,
function ()
	os.reboot()
end)

-- System Rendering

function drawDesktop()
	drawRenderStack()
	graphics.drawImage(bk,1,1)
	drawBar()
	textBuffer.drawBuffer()
	button.drawButtons()
	graphics.drawScreen()
	sleep(0.3)
end

function drawBar()
	time = textutils.formatTime(os.time())
	if settings["barTop"] then
		graphics.drawSimpleLineX(1,1,w,settings["bar"])
		button.setVal("systemStart","visible",true)
		graphics.write(w-#time,1,time)
	else
		graphics.drawLine(1,h,w,h,settings["bar"])
		graphics.write(w-#time,h,time)
		button.setVal("systemStart","y",h)
		button.setVal("systemShutdown","y",h-1)
		button.setVal("systemShutdown","y",h-2)
		button.setVal("systemStart","visible",true)
	end
end

function drawRenderStack()
	for i=1,#renderStack do
		renderStack[i]['draw']()
	end
end

-- System I/O

function  input()
	parallel.waitForAny(mouse,mouseD,key,specialKey)
end

function mouse()
	local event, click, x, y = os.pullEvent("mouse_click")
	if click==1 then
		button.click(x,y)
	end
	if click==2 then
		--doshit
	end
end

function mouseD()
	local button, x, y = os.pullEvent("mouse_drag")
	window.windowDrag()
end

function key()
	local event, character = os.pullEvent("char")
	if inPrompt then
		graphics.ttAdd(character)
	end
end

function specialKey()
	local event, key, isHeld = os.pullEvent("key")
	if key==14 then
		graphics.ttSub()
	end
end

-- System Login Functions

function makeUser()
	inPrompt=true
	graphics.cursorEnd(13,4)
	textBuffer.addText("mkusr",2,3,"Create User")
	textBuffer.addText("usnm",3,4,"Username: ")
	local username = read("")
	textBuffer.addTextVis("pass1",3,5,"Password: ",false)
	textBuffer.addTextVis("pass2",3,6,"Confirm : ",false)
	graphics.cursorEnd(13,5)
	while (true) do
		textBuffer.makeVisible("pass1")
		inPrompt=false
		local pass1 = read("")
		textBuffer.makeVisible("pass2")
		graphics.moveCursor(-#pass1,1)
		local pass2 = read("")
		inPrompt=true
		if (pass1==pass2) then
			break
		end
		textBuffer.addText("nmatch",3,5,"Passwords do not match")
		textBuffer.setVal("pass1",2,6)
		textBuffer.setVal("pass2",2,7)
		textBuffer.invertVis("pass2")
		graphics.cursorEnd(13,6)
	end
	textBuffer.removeAll()
	graphics.ttClear()
	serialize(users, "/home/uspss")
	settings["hasUser"]=true
	info.edit("hasUser",true)
	createUserDir(username)
	users[username]=pass1
	inPrompt=false
	setUserProp(username)
end

function login()
	inPrompt=true
	graphics.cursorEnd(13,4)
	textBuffer.addText("lgn",2,3,"Login")
	textBuffer.addText("usnm", 3,4, "Username: ")
	local username = read("")
	textBuffer.addText("pass", 3,5,"Password: ")
	while (true) do
		textBuffer.setVal("pass",4,true)
		inPrompt=false
		graphics.cursorEnd(13,5)
		local pass1 = read("")
		inPrompt=true
		graphics.ttClear()
		if (users[username]==pass1) then
			break
		end
		textBuffer.addText("incr", 2,3,"Incorrect login credentials")
		textBuffer.setVal("lgn",4,false)
		textBuffer.setVal("pass",4,false)
		graphics.cursorEnd(13,4)
		username = read()
	end
	textBuffer.removeAll()
	graphics.cursorEnd(w,h+1)
	inPrompt=false
	setUserProp()
end

function loginFunc()
	if not settings["hasUser"] or #users==0 then
		makeUser()
	else
		login()
	end
end

function setUserProp(username)
	currentDir="/home/"..username
	currentUser=username
end

function createUserDir(name)
	fs.makeDir("/home/"..name)
	fs.makeDir("/home/"..name.."/Desktop")
	fs.makeDir("/home/"..name.."/Trash")
	fs.makeDir("/home/"..name.."/Documents")
end

--System Utilities

function serialize(item, desitnation)
	file = fs.open(desitnation,"w")
	file.write(textutils.serialize(item))
	file.close()
end

function unserialize(destination)
	file = fs.open(destination,"r")
	hold = textutils.unserialize(file.readAll())
	file.close()
	return hold
end

function softRestart()
	brake = true
end

--System Start and Run

function runTime()  
	while not asleep do
		parallel.waitForAny(drawDesktop,input)
		if brake then
			break
		end
		--sleep(1)
	end
end

function init()
	info.load()
	settings = info.getData()
	users=unserialize("/home/uspss")
	while true do
		brake = false
		parallel.waitForAny(loginFunc,runTime)
		runTime()
	end
end

init()
