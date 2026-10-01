-- Simplify requiring stackline from init.lua.
-- Resolve paths from this file so symlinks or inherited HOME values do not
-- make Hammerspoon look in the wrong config directory.

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local stackline_dir = source:match("(.*/)")

package.path = stackline_dir .. "?.lua;" .. package.path
return require 'stackline.stackline'
