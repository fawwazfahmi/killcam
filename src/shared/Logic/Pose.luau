-- The end-of-match poses, as plain numbers: what every joint is doing at a
-- moment in time, for each mood. Pure maths, so it can be unit tested; the
-- podium service turns these into joint rotations on an R15 character.
--
-- Angles are degrees, applied as CFrame.Angles(x, y, z) on top of a joint's
-- own rest position. Signs follow R15: a positive X pitches a part forward
-- (head down, lean forward) and Z swings an arm away from the body.
--
-- `root` is how the whole body moves: `lift` in studs (up is positive) and
-- `turn` in degrees about the vertical.

local Pose = {}

-- Every joint a pose may touch. All moods fill all of them, so no joint is
-- ever left holding the previous pose.
Pose.JOINTS = {
	"Neck",
	"Waist",
	"LeftShoulder",
	"RightShoulder",
	"LeftElbow",
	"RightElbow",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
}

local function joints(values)
	local full = {}
	for _, name in Pose.JOINTS do
		full[name] = values[name] or { 0, 0, 0 }
	end
	return full
end

local MOODS = {}

-- Winners: a bounce on the spot, arms thrown up and alternating, hips swinging.
function MOODS.Celebrate(t)
	local beat = t * 5.2 -- about 50 beats in ten seconds
	local bounce = math.abs(math.sin(beat))
	local swing = math.sin(beat * 0.5)
	return {
		root = { lift = bounce * 0.9, turn = swing * 16 },
		joints = joints({
			Neck = { -10 - bounce * 8, swing * 14, 0 },
			Waist = { -4, swing * 10, swing * 6 },
			RightShoulder = { 0, 0, 120 + bounce * 40 },
			LeftShoulder = { 0, 0, -(120 + (1 - bounce) * 40) },
			RightElbow = { -(20 + bounce * 35), 0, 0 },
			LeftElbow = { -(20 + (1 - bounce) * 35), 0, 0 },
			RightHip = { -bounce * 14, 0, 0 },
			LeftHip = { -(1 - bounce) * 14, 0, 0 },
			RightKnee = { bounce * 26, 0, 0 },
			LeftKnee = { (1 - bounce) * 26, 0, 0 },
		}),
	}
end

-- The MVP whose team lost: doubled over, hands to the face, shoulders
-- shaking. A slow heave underneath a fast tremor.
function MOODS.Cry(t)
	local sob = math.sin(t * 2.4) -- the heave of the shoulders
	local tremor = math.sin(t * 17) * 0.5 + math.sin(t * 23) * 0.3 -- the shaking
	return {
		root = { lift = -0.5 - math.max(sob, 0) * 0.35, turn = tremor * 3 },
		joints = joints({
			Neck = { 34 + math.max(sob, 0) * 10, tremor * 4, 0 },
			Waist = { 30 + math.max(sob, 0) * 9, 0, tremor * 3 },
			-- Arms folded up so the hands cover the face.
			RightShoulder = { -62, 0, 26 },
			LeftShoulder = { -62, 0, -26 },
			RightElbow = { -108 - math.max(sob, 0) * 8, 0, 0 },
			LeftElbow = { -108 - math.max(sob, 0) * 8, 0, 0 },
			RightHip = { 10, 0, 0 },
			LeftHip = { 10, 0, 0 },
			RightKnee = { 18, 0, 0 },
			LeftKnee = { 18, 0, 0 },
		}),
	}
end

-- The other losers on the podium: head down, arms hanging, a slow shift of
-- weight from one foot to the other.
function MOODS.Sulk(t)
	local shift = math.sin(t * 0.9)
	return {
		root = { lift = -0.2, turn = shift * 5 },
		joints = joints({
			Neck = { 24, shift * 8, 0 },
			Waist = { 10, shift * 4, shift * 3 },
			RightShoulder = { 12, 0, 8 },
			LeftShoulder = { 12, 0, -8 },
			RightElbow = { -14, 0, 0 },
			LeftElbow = { -14, 0, 0 },
			RightHip = { 2 + math.max(shift, 0) * 5, 0, 0 },
			LeftHip = { 2 + math.max(-shift, 0) * 5, 0, 0 },
			RightKnee = { math.max(shift, 0) * 10, 0, 0 },
			LeftKnee = { math.max(-shift, 0) * 10, 0, 0 },
		}),
	}
end

function Pose.moods()
	local names = {}
	for name in MOODS do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- The pose for `mood` at `t` seconds into the ceremony. An unknown mood
-- stands still rather than erroring.
function Pose.sample(mood, t)
	local build = MOODS[mood]
	if not build then
		return { root = { lift = 0, turn = 0 }, joints = joints({}) }
	end
	return build(t)
end

return Pose
