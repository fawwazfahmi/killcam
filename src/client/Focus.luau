-- Lets a controller steer a menu. While one is open the controller moves
-- between its buttons, A presses the one it is on (that part is Roblox's own),
-- and B closes it. Menus can open on top of one another; closing the top one
-- hands the controller back to the one beneath.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Focus = {}

local CLOSE_ACTION = "CloseMenu"
local CLOSE_PRIORITY = 3000 -- above anything the game itself binds

local open = {} -- { frame, close }, the top one last

local function usingController()
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Gamepad1
end

local function steer()
	local top = open[#open]
	if top and usingController() and top.frame:IsDescendantOf(game) then
		GuiService:Select(top.frame)
	elseif not top then
		GuiService.SelectedObject = nil
	end
end

-- True while any menu is open: the game should leave the controller alone.
function Focus.active()
	return #open > 0
end

-- `frame` holds the menu's buttons, and `close` shuts it.
function Focus.on(frame, close)
	Focus.off(frame)
	table.insert(open, { frame = frame, close = close })
	if #open == 1 then
		ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				local top = open[#open]
				if top then
					-- After this press has finished being handed round, so that
					-- the game does not also take it as a press of its own.
					task.defer(top.close)
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, CLOSE_PRIORITY, Enum.KeyCode.ButtonB)
	end
	steer()
end

function Focus.off(frame)
	for index, entry in open do
		if entry.frame == frame then
			table.remove(open, index)
			break
		end
	end
	if #open == 0 then
		ContextActionService:UnbindAction(CLOSE_ACTION)
		GuiService.SelectedObject = nil
	else
		steer()
	end
end

-- Picking up a controller with a menu already open.
UserInputService.LastInputTypeChanged:Connect(function()
	if #open > 0 and usingController() and not GuiService.SelectedObject then
		steer()
	end
end)

return Focus
