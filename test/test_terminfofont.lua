#!/usr/bin/env lua
---------------------------------------------------------------------
--     This Lua5 script is Copyright (c) 2019, Peter J Billam      --
--                         pjb.com.au                              --
--  This script is free software; you can redistribute it and/or   --
--         modify it under the same terms as Lua5 itself.          --
---------------------------------------------------------------------
local Version = '1.0  for Lua5'
local VersionDate  = '3nov2019'
local Synopsis = [[
  lua test_vfonts.lua
  https://pjb.com.au/comp/lua/terminfofont.html
]]
local iarg=1; while arg[iarg] ~= nil do
	if not string.find(arg[iarg], '^-[a-z]') then break end
	local first_letter = string.sub(arg[iarg],2,2)
	if first_letter == 'v' then
		local n = string.gsub(arg[0],"^.*/","",1)
		print(n.." version "..Version.."  "..VersionDate)
		os.exit(0)
	elseif first_letter == 'c' then
		whatever()
	else
		local n = string.gsub(arg[0],"^.*/","",1)
		print(n.." version "..Version.."  "..VersionDate.."\n\n"..Synopsis)
		os.exit(0)
	end
	iarg = iarg+1
end
local TIF = require 'terminfofont'
os.execute('clear')
local line = 6
local dx, dy
TIF.civis()

TIF.rectfill(10,21, 40,15, 'black')

dx,dy = TIF.show(1, line, 'ABCDEFG', 6)
line = line + dy
dx,dy = TIF.show(1, line, 'HIJKLMN', 1)
line = line + dy
dx,dy = TIF.show(1, line, '"OPQRST"',  2)
line = line + dy
dx,dy = TIF.show(1, line, 'UVWXYZ', 3)
line = line + dy
dx,dy = TIF.show(1, line, '?!:.;,-0123', 4)
line = line + dy
dx,dy = TIF.show(1,line, '456789+',  5)

-- TIF.moveto(0, TIF.lines-1) ; os.exit()
os.execute('sleep 5')
os.execute('clear')
line = 6
dx,dy = TIF.show(1, line, '/\\_|=@%&', 6)
line = line + dy
dx,dy = TIF.show(1, line, 'abcdefghi',  5)
line = line + dy-1
dx,dy = TIF.show(1, line, 'jklmnopqr',  4)
line = line + dy
dx,dy = TIF.show(1, line, "'stuvwxyz'",   3)
line = line + dy -1
dx,dy = TIF.show(1, line, 'pjb.com.au', 2)
line = line + dy
dx,dy = TIF.show(0, line, '[x][o]()^{}', 'blue')
os.execute('sleep 5')
os.execute('clear')

line = 6
dx,dy = TIF.show(1, line, '#*\'~"', 6)
TIF.cnorm()
TIF.moveto(0, TIF.lines-1)
os.exit()

