-- The look shared by every screen and by the map's signage. Plain Luau only:
-- fonts are Enum.Font names and colours are { r, g, b }.

return {
	-- Michroma is a display face. It is right for a handful of large words and
	-- unreadable below about 20px, so anything meant to be read rather than
	-- glanced at uses the body face.
	display = "Michroma",
	body = "GothamMedium",
	bodyBold = "GothamBold",

	-- One type scale, so nothing is sized by eye. Nothing on a screen should
	-- be smaller than `small`.
	size = {
		title = 30,
		heading = 20,
		label = 16,
		body = 15,
		small = 13,
		readout = 40, -- health and ammo
	},

	accent = { 255, 196, 30 },
	ink = { 30, 31, 36 },
	paper = { 255, 255, 255 },
	muted = { 160, 165, 176 },
	panel = { 24, 26, 32 },
	raised = { 40, 44, 54 },
	sunken = { 18, 19, 24 },
	danger = { 255, 70, 60 },
}
