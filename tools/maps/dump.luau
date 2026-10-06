-- Prints a map layout from src/server/Maps as JSON, for tools/maps/plan.py.
--   lune run tools/maps/dump NightYard

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local name = process.args[1]
local layout = luau.load(fs.readFile(`src/server/Maps/{name}.luau`))()
print(serde.encode("json", layout))
