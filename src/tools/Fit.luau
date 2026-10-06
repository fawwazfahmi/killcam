-- Shared steps for turning models brought in with Studio's Import 3D into
-- game assets. Used by FitWeapons and FitProps.
--
-- Every generated file carries marker meshes written by tools/models/build.py.
-- They give the origin, the forward, up and right directions and one stud of
-- length, so the result does not depend on the importer's scale or axis
-- settings.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(script.Parent.Palette)

local Fit = {}

function Fit.marker(model, name)
	local part = model:FindFirstChild(name, true)
	return if part and part:IsA("BasePart") then part else nil
end

local function folder(parent, name)
	local found = parent:FindFirstChild(name)
	if not found then
		found = Instance.new("Folder")
		found.Name = name
		found.Parent = parent
	end
	return found
end

-- Rescales `imported` to its authored size and returns the CFrame of its
-- origin, looking along the authored forward direction. On failure returns nil
-- and the reason.
function Fit.frame(imported)
	local origin = Fit.marker(imported, "MarkOrigin")
	local forward = Fit.marker(imported, "MarkForward")
	local up = Fit.marker(imported, "MarkUp")
	local right = Fit.marker(imported, "MarkRight")
	if not (origin and forward and up and right) then
		return nil, "a marker is missing (import with Merge Meshes off)"
	end

	-- The forward marker is authored exactly one stud from the origin.
	local length = (forward.Position - origin.Position).Magnitude
	if length < 1e-4 then
		return nil, "the markers overlap"
	end
	imported:ScaleTo(imported:GetScale() / length)

	local at = origin.Position
	local look = (forward.Position - at).Unit
	local lift = (up.Position - at).Unit
	if math.abs(look:Dot(lift)) > 0.02 then
		return nil, "the markers are skewed"
	end
	if (right.Position - at):Dot(look:Cross(lift)) < 0 then
		warn(`Fit: {imported.Name} was imported mirrored; its right-hand details are on the left`)
	end
	return CFrame.lookAt(at, at + look, lift)
end

-- Builds the finished Model: an invisible root part at `frame` as PrimaryPart,
-- plus every visible part of `imported`, coloured from the palette. Markers
-- stay behind in `imported`.
--
-- `detail`, for the high-detail weapons, is { finishes, parts } from
-- HdWeapons: parts are coloured by their listed finish instead of by name, and
-- get a "Group" attribute naming what they move with in animations.
function Fit.assemble(imported, rootName, frame, detail)
	local root = Instance.new("Part")
	root.Name = rootName
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = frame

	local model = Instance.new("Model")
	model.Name = imported.Name
	root.Parent = model
	model.PrimaryPart = root

	for _, part in imported:GetDescendants() do
		if not part:IsA("BasePart") or string.sub(part.Name, 1, 4) == "Mark" then
			continue
		end
		local spec = detail and detail.parts[part.Name]
		local finish = if spec then detail.finishes[spec.finish] else Palette[part.Name]
		if spec then
			part:SetAttribute("Group", spec.group)
		end
		if finish then
			part.Color = Color3.fromRGB(table.unpack(finish.color))
			part.Material = Enum.Material[finish.material]
		else
			warn(`Fit: {imported.Name}.{part.Name} has no palette entry; left as imported`)
		end
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
	end

	return model, root
end

-- Runs `fitOne` on every imported model in Workspace and files the results
-- under ReplicatedStorage.Assets.<folderName>, replacing models of the same
-- name. `fitOne(imported)` returns the finished Model; nil to leave the import
-- alone; or nil and a reason when it should have worked.
function Fit.run(label, folderName, fitOne)
	local destination = folder(folder(ReplicatedStorage, "Assets"), folderName)
	local recording = ChangeHistoryService:TryBeginRecording(label)
	local fitted = 0

	for _, imported in workspace:GetChildren() do
		if not imported:IsA("Model") or not Fit.marker(imported, "MarkOrigin") then
			continue
		end
		local model, problem = fitOne(imported)
		if not model then
			if problem then
				warn(`{label}: skipped {imported.Name}: {problem}`)
			end
			continue
		end
		local previous = destination:FindFirstChild(model.Name)
		if previous then
			previous:Destroy()
		end
		model.Parent = destination
		imported:Destroy()
		fitted += 1
		print(`{label}: {model:GetFullName()}`)
	end

	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	if fitted == 0 then
		warn(`{label}: nothing to fit was found in Workspace`)
	end
	return fitted
end

return Fit
