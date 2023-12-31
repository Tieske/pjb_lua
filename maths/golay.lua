#!/usr/bin/env lua
---------------------------------------------------------------------
--     This Lua5 script is Copyright (c) 2021, Peter J Billam      --
--                         pjb.com.au                              --
--  This script is free software; you can redistribute it and/or   --
--         modify it under the same terms as Lua5 itself.          --
---------------------------------------------------------------------
local Version = '1.0  for Lua5'
local VersionDate  = '9may2021'
local Synopsis = [[
golay [options] [filenames]
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
require 'DataDumper'

local function printf (...) print(string.format(...)) end

function str2bin (str)
	local arr = { string.byte(str,1,-1) }   -- PiL p.34
	local num = 0
	for i,v in ipairs(arr) do
		if v == 48 then
			num = (num<<1)
		elseif v == 49 then
			num = (num<<1) | 1
		end -- ignore unless 0 or 1
	end
	return num
end
function bin24_2str (num)
	return string.char(
		((num>>23)&1)+48, ((num>>22)&1)+48, ((num>>21)&1)+48,
		((num>>20)&1)+48, ((num>>19)&1)+48, ((num>>18)&1)+48,
		((num>>17)&1)+48, ((num>>16)&1)+48, ((num>>15)&1)+48,
		((num>>14)&1)+48, ((num>>13)&1)+48, ((num>>12)&1)+48, 32,
		((num>>11)&1)+48, ((num>>10)&1)+48, ((num>> 9)&1)+48,
		((num>> 8)&1)+48, ((num>> 7)&1)+48, ((num>> 6)&1)+48,
		((num>> 5)&1)+48, ((num>> 4)&1)+48, ((num>> 3)&1)+48,
		((num>> 2)&1)+48, ((num>> 1)&1)+48, (num&1)+48
	)
end
function bin12_2str (num)
	return string.char(
		((num>>11)&1)+48, ((num>>10)&1)+48, ((num>> 9)&1)+48,
		((num>> 8)&1)+48, ((num>> 7)&1)+48, ((num>> 6)&1)+48,
		((num>> 5)&1)+48, ((num>> 4)&1)+48, ((num>> 3)&1)+48,
		((num>> 2)&1)+48, ((num>> 1)&1)+48, (num&1)+48
	)
end

-- img/extended_binary_Golay_code.png
EncodingMatrix = {
	0x800, 0x400, 0x200, 0x100,
	0x080, 0x040, 0x020, 0x010,
	0x008, 0x004, 0x002, 0x001,
	0x9F1, 0x4FA, 0x27D, 0x93E,
	0xC9D, 0xE4E, 0xF25, 0xF92,
	0x7C9, 0x3E6, 0x557, 0xAAB,
}
DecodingMatrix = {
	0x8009F1, 0x4004FA, 0x20027D, 0x10093E,
	0x080C9D, 0x040E4E, 0x020F25, 0x010F92,
	0x0087C9, 0x0043E6, 0x002557, 0x001AAB,
}
NonAdjacentFaces = {   -- for giam.southernct.edu's decoding-check
	0x8009F1, 0x4004FA, 0x20027D, 0x10093E,
	0x80C9D,   0x40E4E,  0x20F25,  0x10F92,
	0x87C9,     0x43E6,   0x2557,   0x1AAB,
}
AdjacentFaces = {
	(~0x9F1)&0xFFF, (~0x4FA)&0xFFF, (~0x27D)&0xFFF, (~0x93E)&0xFFF,
	(~0xC9D)&0xFFF, (~0xE4E)&0xFFF, (~0xF25)&0xFFF, (~0xF92)&0xFFF,
	(~0x7C9)&0xFFF, (~0x3E6)&0xFFF, (~0x557)&0xFFF, (~0xAAB)&0xFFF,
}
OppositeFaces = {6,7,8,9,10,1,2,3,4,5,12,11}

function hamming_weight_24 (u)
	return ((u>>23) & 1) + ((u>>22) & 1) + ((u>>21) & 1) + ((u>>20) & 1)
		 + ((u>>19) & 1) + ((u>>18) & 1) + ((u>>17) & 1) + ((u>>16) & 1)
		 + ((u>>15) & 1) + ((u>>14) & 1) + ((u>>13) & 1) + ((u>>12) & 1)
		 + ((u>>11) & 1) + ((u>>10) & 1) + ((u>>9) & 1) + ((u>>8) & 1)
	     + ((u>>7) & 1) + ((u>>6) & 1) + ((u>>5) & 1) + ((u>>4) & 1)
	     + ((u>>3) & 1) + ((u>>2) & 1) + ((u>>1) & 1) + (u & 1)
	-- could use POPCNT etc according to machine HW type ...
	-- https://en.wikipedia.org/wiki/Hamming_weight
	-- man 2 uname
	-- BETTER: also available in posix
	--   P = require 'posix.sys.utsname' ; print(P.uname().machine)
	-- BEST: GCC >=3.4 includes a builtin function __builtin_popcount
end
function hamming_weight_12 (u)
	return ((u>>11) & 1) + ((u>>10) & 1) + ((u>>9) & 1) + ((u>>8) & 1)
	     + ((u>>7) & 1) + ((u>>6) & 1) + ((u>>5) & 1) + ((u>>4) & 1)
	     + ((u>>3) & 1) + ((u>>2) & 1) + ((u>>1) & 1) + (u & 1)
end

function golay_encode (array12)
	-- https://giam.southernct.edu/DecodingGolay/encoding.html
	-- but in a different numbering-order !!
	local crypt24 = 0
	for i,val in ipairs(EncodingMatrix) do
		crypt24 = crypt24 | ((hamming_weight_12(val&array12)) % 2) << (24-i)
	end
	return crypt24
end


function are_adjacent(face1, face2)
	local non_adjacency = NonAdjacentFaces[face1]
	local magic_bit = non_adjacency>>(12-face2) & 1
	return magic_bit == 0
end

function faces2mask(faces)
	local mask = 0
	for i,facenum in ipairs(faces) do mask = mask | (1 << (12-facenum)) end
	return mask
end


function golay_decode (crypt24)
  -- https://giam.southernct.edu/DecodingGolay/decoding.html
  -- valid code words have Hamming weights of 0, 8, 12, 16, or 24.
  -- local hw = hamming_weight_24(crypt24)
	local function decoding_check (crypt24, i)
		local hw = hamming_weight_24(crypt24 & NonAdjacentFaces[i])
		return hw%2 == 0
	end
	local function decode(crypt24)
		local plain12 = 0
		for i,val in ipairs(DecodingMatrix) do
			-- 20210512 not sure why this is hamming_weight_12 here ...
			plain12 = plain12 | ((hamming_weight_12(val&crypt24))%2) << (12-i)
		end
		return plain12
	end
	local failed_tab = {}
	local passed_tab = {}
	for i = 1, 12 do
		if not decoding_check(crypt24,i) then table.insert(failed_tab,i)
		else table.insert(passed_tab,i)
		end
	end
	if #failed_tab <= 2 then return decode(crypt24) end  -- speed
	local failed = faces2mask(failed_tab)
	local passed = faces2mask(passed_tab)
	local function adj (s, t)
		local for_all ; local to_all
		local adj_tab = { [0]={}, {}, {}, {}, {}, {} }
		if type(s) == 'string' then
			local b = { string.byte(s,1,-1) }
			if b[1] == 0x50 then for_all = passed_tab
			else for_all = failed_tab
			end
			if b[2] == 0x50 then  to_all = passed else  to_all = failed end
			for i,v in ipairs(for_all) do
				local n =  hamming_weight_12(to_all & AdjacentFaces[v])
				table.insert(adj_tab[n], v)
			end
			if b[3] == 0x53 then   -- S
				local n_adj = { #adj_tab[0], #adj_tab[1], #adj_tab[2],
			   	#adj_tab[3], #adj_tab[4], #adj_tab[5] } 
				return table.concat(n_adj, ' ')
			else
				return adj_tab
			end
--[[ -- unused... might be useful in the future
		else 
			for_all = s
			if type(t) == 'table' then
				to_all = faces2mask(t)
			else
				if t == 'P' then to_all = passed else  to_all = failed end
			end
printf('for_all = %s', DataDumper(for_all))
printf(' to_all = %s', bin12_2str(to_all))
			for i,v in pairs(for_all) do
				local n =  hamming_weight_12(to_all & AdjacentFaces[v])
				table.insert(adj_tab[n], v)
			end
			return adj_tab
]]
		end
	end

	local ffs = adj('FFS') ; local pps = adj('PPS')
	local ffa = adj('FFA') ; local ppa = adj('PPA')
	local function diagnostic()
		local pfs = adj('PFS') ; local fps = adj('FPS') -- XXXX
		local pfa = adj('PFA') ; local fpa = adj('FPA')
		printf('  ffs = %s  ffa = %s', ffs, DataDumper(ffa))
		printf('  fps = %s  fpa = %s', fps, DataDumper(fpa))
		printf('  pps = %s  ppa = %s', pps, DataDumper(ppa))
		printf('  pfs = %s  pfa = %s', pfs, DataDumper(pfa))
	end

	-- https://giam.southernct.edu/DecodingGolay/decoding.html
-- printf('  ffs = %s  ffa = %s', ffs, DataDumper(ffa))   -- XXXX
	if     ffs == '1 0 0 5 0 1' then   -- Parachute
		crypt24 = crypt24 ~ 1<<(12-ffa[0][1])
	elseif ffs == '0 0 0 5 0 1' then  -- + msg failure in skydiver
		-- crypt24 = crypt24 ~ 1<<OppositeFaces[ffa[5][1]]  -- :-)
		crypt24 = crypt24 ~ (1<<(24-ppa[5][1]) | 1<<(12-ppa[5][1]))  -- :-)
	elseif ffs == '1 0 5 0 0 0' then  -- + msg failure in its opposite
		crypt24 = crypt24 ~ (1<<(12-ffa[0][1]))
	elseif ffs == '0 1 0 4 2 1' then  -- + msg fail adjacent to skydiver
		crypt24 = crypt24 ~ (1<<(12-ffa[1][1]))
	elseif ffs == '1 0 2 2 1 0' then  -- + msg failure in parachute fringe
		crypt24 = crypt24 ~ (1<<12-ffa[0][1])
	elseif ffs == '0 0 5 0 0 0' then -- + 2 failures in skydiver and top
		local pfa = adj('PFA')
		crypt24 = crypt24 ~ (1<<(24-ppa[0][1]) | 1<<(24-pfa[0][1]))
		return crypt24 >> 12
	elseif ffs == '0 0 2 2 1 0' then -- + 2 fails in skydiver and fringe
		local pfa = adj('PFA')
		crypt24 = crypt24 ~ (1<<(24-pfa[0][1]) | 1<<(24-pfa[3][1]))
		return crypt24 >> 12
	elseif ffs == '0 0 1 3 2 1' then -- + 2 msg fails in skydiver and open
		local pfa = adj('PFA')
		for i,v in ipairs(ffa[3]) do
			if are_adjacent(v, ppa[2][1]) or are_adjacent(v, ppa[2][2]) then
				-- crypt24 = crypt24 ~ (1<<(24-ppa[4][1])|1<<(24-v)|1<<(24-v))
				crypt24 = crypt24 ~ (1<<(24-pfa[1][1]) | 1<<(24-ffa[2][1]))
        		return crypt24 >> 12
			end
		end
	elseif ffs == '1 2 2 0 0 0' then -- top and fringe  1,10
		for i,v in ipairs(ppa[3]) do
			if are_adjacent(v, ppa[1][1]) then
				crypt24 = crypt24 ~ (1<<(24-ppa[1][1]) | 1<<(24-v))
				return crypt24 >> 12
			end
		end
	elseif ffs == '0 1 3 3 0 0' then -- top and open  1,8

		local pfa = adj('PFA')
		for i,v in ipairs(ffa[3]) do
			if are_adjacent(v, ffa[1][1]) then
				crypt24 = crypt24 ~ (1<<(24-pfa[5][1]) | 1<<(24-v))
				return crypt24 >> 12
			end
		end
	elseif ffs == '0 0 0 0 10 0' then -- Tropics
		crypt24 = crypt24 ~ (1<<(12-passed_tab[1]) | 1<<(12-passed_tab[2]))
	elseif ffs == '0 0 0 0 5 6' then -- + msg failure in one of the poles
		local opp = OppositeFaces[passed_tab[1]]
		crypt24 = crypt24 ~ (1<<(12-passed_tab[1]) | 1<<(24-opp) | 1<<12-opp)
	-- elseif #failed_tab == 9 then  -- Cage or Deep-Bowl
	elseif ffs == '0 0 0 4 5 0' then -- Tropics with msg fail on the equator
		local pfa = adj('PFA')
		local opp = OppositeFaces[ppa[0][1]]
		for i,v in pairs(pfa[4]) do
			if v ~= opp then crypt24 = crypt24 ~ (1<<(24-v)) ; break ; end
		end
		crypt24 = crypt24 ~ (1<<(12-passed_tab[1]) | 1<<(12-passed_tab[2]))
	elseif pps=='3 0 0 0 0 0' or pps=='0 0 3 0 0 0' then -- Deep-Bowl or Cage
		local  a1 = AdjacentFaces[passed_tab[1]]
		local  a2 = AdjacentFaces[passed_tab[2]]
		local  a3 = AdjacentFaces[passed_tab[3]]
		local na1 = NonAdjacentFaces[passed_tab[1]]
		local na2 = NonAdjacentFaces[passed_tab[2]]
		local na3 = NonAdjacentFaces[passed_tab[3]]
		crypt24 = crypt24 ~ (a1 & na2 & na3)
		crypt24 = crypt24 ~ (na1 & a2 & na3)
		crypt24 = crypt24 ~ (na1 & na2 & a3)
	elseif ffs == '0 0 4 2 0 0' then   -- Diaper
		crypt24 = crypt24 ~ faces2mask(adj('FFA')[3])
	elseif adj('FFS') == '0 1 3 1 0 0' then  -- Diaper with err in adj=2 face
		-- 1) find the face (fna2) in ffa[2] not adjacent to the other two,
		local fna2 = 1
		if     are_adjacent(ffa[2][1], ffa[2][2]) then fna2 = 3
		elseif are_adjacent(ffa[2][1], ffa[2][3]) then fna2 = 2
		end
		fna2 = ffa[2][fna2]
		-- 2) find the face in passed adjacent to that and to ffa[1][1]
		local bad_face
		for i = 1,3 do
			if are_adjacent(ppa[3][i], fna2) then bad_face = ppa[3][i] ; break
			end
		end
		crypt24 = crypt24 ~ (1 << (24-bad_face))
		return crypt24>>12
	elseif ffs == '0 2 3 0 0 0' then  -- Diaper with err in adj=3 face
		for i,v in ipairs(ppa[2]) do
			if are_adjacent(v,ffa[1][1]) and are_adjacent(v,ffa[1][2]) then
				crypt24 = crypt24 ~ (1 << (24-v)) ; return crypt24>>12
			end
		end
		-- or Bent-Ring with a message failure in a points_in face
		-- seek the face in ppa[3] adjacent to both in ffa[1]
		-- then choose the one adjacent to two in ppa[2]
		for i,v in ipairs(ppa[3]) do
			if are_adjacent(v,ffa[1][1]) and are_adjacent(v,ffa[1][2]) then
				local n = 0
				for j,w in ipairs(ppa[2]) do
					if are_adjacent(v,w) then n = n + 1 end
					if n == 2 then
						crypt24 = crypt24 ~ (1<<(24-v)) ; return crypt24>>12
					end
				end
			end
		end
	elseif ffs  == '0 0 2 2 3 0' then   -- Diaper with msg error in waistline
		-- seek the face in ffa[4] adjacent to both faces in ffa[3]
		for i,v in ipairs(ffa[4]) do
			if are_adjacent(v, ffa[3][1]) and are_adjacent(v, ffa[3][2]) then
				crypt24 = crypt24 ~ (1 << (24-v)) ; return crypt24>>12
			end
		end
	elseif ffs == '0 0 3 4 0 0' then
		local ffa2 = ffa[2] ; local i = 1
		if  pps == '0 2 3 0 0 0' then
			if not are_adjacent(ppa[1][1], ppa[1][2]) then
				if     are_adjacent(ffa2[1], ffa2[2]) then i = 3
				elseif are_adjacent(ffa2[1], ffa2[3]) then i = 2
				end
			else
				-- Bent-Ring + msg-error in a checksum-error face
				--seek the face in ffa[3] not adjacent to either in ppa[1]
				local ffa3 = ffa[3]
				for i,v in ipairs(ffa3) do
					if not are_adjacent(v, ppa[1][1]) and
					   not are_adjacent(v, ppa[1][2]) then
						crypt24 = crypt24 ~ (1<<(24-v)) ; return crypt24>>12
					end
				end
			end
			crypt24 = crypt24 ~ (1 << (24-ffa2[i])) ; return crypt24>>12
		elseif pps == '1 1 2 1 0 0' then
			-- Diaper with a message failure in a elbow|knee face
			local pfa = adj('PFA')
			for i,v in ipairs(ffa[2]) do
				if not are_adjacent(v, pfa[2][1]) then
					crypt24 = crypt24 ~ (1 << (24-v)) ; return crypt24>>12
				end
			end
		end
	elseif ffs == '0 0 5 2 0 0' then
		-- Bent-Ring with a message failure in a shoulder face (10)
		local fpa = adj('FPA')
		for i,v in ipairs(ffa[2]) do
			if are_adjacent(v, fpa[2][1]) and are_adjacent(v, fpa[2][2]) then
				crypt24 = crypt24 ~ (1 << (24-v)) ; return crypt24>>12
			end
		end
	elseif ffs  == '0 0 6 0 0 0' then   -- Bent-Ring
		crypt24 = crypt24 ~ (1<<(12-ppa[2][1]) | 1<<(12-ppa[2][2]))
	elseif ffs  == '0 0 2 4 1 0' then -- + message fail in an inside-face
		crypt24 = crypt24 ~ (1<<(24-ffa[4][1])) ; return crypt24>>12
	elseif #failed_tab == 5 then -- Cobra Islands or Broken-Tripod 3 errors
		if ffs == '0 1 1 3 0 0' then   -- Cobra
			-- seek the face in ffa[2] adjacent to both in fpa[2]')
			-- & its 2 passed neighbors that neighbor a ffa[3] face
			local neighbors_2 = passed & AdjacentFaces[ffa[2][1]]
			mask = 0
			for i,v in ipairs(ffa[3]) do mask = mask | AdjacentFaces[v] end
			crypt24 = crypt24 ~ (neighbors_2 & (passed & mask))
			crypt24 = crypt24 ~ (1 << (12 - ffa[2][1]))
		elseif ffs  == '0 4 1 0 0 0' then
			local neighbors_2 = failed & AdjacentFaces[ffa[2][1]]
			crypt24 = crypt24 ~ (1 << (12 - ffa[2][1]))
			-- and the passed faces adjacent to 2 failed faces
			for i,v in ipairs(passed_tab) do
				local neighbors =
				  hamming_weight_12(failed & AdjacentFaces[v])
				if neighbors == 2 then crypt24 = crypt24 ~ (1<<(12-v)) end
			end
		elseif ffs == '0 2 1 2 0 0' then   -- print('Broken-Tripod')
			crypt24 = crypt24 ~ (1 << (12 - ffa[2][1]))
			for i,v in ipairs(passed_tab) do
				local neighbors =
				  hamming_weight_12(failed & AdjacentFaces[v])
				if neighbors == 2 or neighbors == 4 then
					crypt24 = crypt24 ~ (1<<(12-v))
				end
			end
		end
		
	end
	return decode(crypt24)
end

function str2_12bit_msgblocks (s)
	local msgblocks = {}
	local i = 1
	while true do
		if i > string.len(s) then break end
		local by1, by2, by3 = string.byte(s, i, i+2)
		by1 = by1 or 0 ;  by2 = by2 or 0 ;  by3 = by3 or 0
		table.insert(msgblocks, (by1<<4 | by2>>4))
		table.insert(msgblocks, ((by2&63)<<8 | by3))
		i = i + 3
	end
	return msgblocks
end
function msgblocks2golayblocks(msgblocks)
	local golayblocks = {}
	for i,v in ipairs(msgblocks) do
		table.insert(golayblocks, golay_encode(v))
	end
	return golayblocks
end
function golayblocks2msgblocks(golayblocks)
	local msgblocks = {}
	for i,v in ipairs(golayblocks) do
		table.insert(msgblocks, golay_decode(v))
	end
	return msgblocks
end
function msgblocks2str(msgblocks)
	local s_arr = {}
	local i = 1
	while true do
		if i > #msgblocks then break end
		local b1 = msgblocks[i]
		local b2 = msgblocks[i+1] or 0
		table.insert(s_arr, string.char(b1>>4))
		table.insert(s_arr, string.char((b1&15)<<4 | b2>>8))
		table.insert(s_arr, string.char(b2&255))
		i = i + 2
	end
	return table.concat(s_arr)
end
local s1 = 'ABCXYZ'
local b1 = str2_12bit_msgblocks(s1)
local co = msgblocks2golayblocks(b1)
local b2 = golayblocks2msgblocks(co)
local s2 = msgblocks2str(b2)
-- print(s2)
-- os.exit()

-----------------------------------------
local i_test = 0;  local Failed = 0
function ok(b,s)
    i_test = i_test + 1
    if b then
        io.write('ok '..i_test..' - '..s.."\n")
        return true
    else
        io.write('not ok '..i_test..' - '..s.."\n")
        Failed = Failed + 1
        return false
    end
end
function finish()
	if     Failed == 0 then print('passed all tests') ; os.exit(0)
	elseif Failed == 1 then print('1 test failed') ; os.exit(1)
	elseif Failed  > 1 then printf('%d tests failed', Failed) ; os.exit(1)
	else print('Failed =', Failed)
	end
end

-- TESTS
n = str2bin('101010110110')
-- printf('   n    = %s', bin12_2str(n))
local crypt_n = golay_encode(n)
local plain12 = golay_decode(crypt_n)
ok(plain12 == n, 'golay_encode and golay_decode')

corrupt = crypt_n ~ (2<<15)
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'one error in the message block')

corrupt = crypt_n ~ (5<<13)
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'two errors in the message block')

corrupt = crypt_n ~ (21<<13)
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'three errors in the message block')

corrupt = crypt_n ~ (1<<(12-6))
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'one error in the skydiver checksum in a Parachute')

corrupt = crypt_n ~ (1<<(12-7))
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'one checksum error in the open in a Parachute')

corrupt = crypt_n ~ (1<<(12-11))
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'one checksum error in the fringe in a Parachute')

corrupt = crypt_n ~ (1<<(12-1))
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'one checksum error in the top in a Parachute')

corrupt = crypt_n ~ (2<<5 | 2<<17)
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Parachute with message failure in the skydiver face')

corrupt = crypt_n ~ (2<<5 | 2<<22)
plain12 = golay_decode(corrupt)
ok(plain12 == n,
  'Parachute with message failure in the face opposite the skydiver')

corrupt = crypt_n ~ (2<<5 | 2<<23)   -- or 15,16,18,19,23
plain12 = golay_decode(corrupt)
ok(plain12 == n,
  'Parachute with message failure in a face adjacent to skydiver')

corrupt = crypt_n ~ (2<<5 | 2<<21)   -- or 15,16,18,19,23
plain12 = golay_decode(corrupt)
ok(plain12 == n,
  'Parachute with message failure in a face in the parachute fringe')

corrupt = crypt_n ~ (2<<5 | 1<<18 | 1<<23 )
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Parachute + 2 message failures in the skydiver and top')

corrupt = crypt_n ~ (2<<5 | 1<<18 | 1<<22 )
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Parachute + 2 message failures in the skydiver and fringe')

corrupt = crypt_n ~ (2<<5 | 1<<18 | 1<<17 )
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Parachute + 2 message failures in the skydiver and open')

corrupt = crypt_n ~ (2<<5 | 1<<23 | 1<<14 )
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Parachute + 2 message failures in top and fringe')

corrupt = crypt_n ~ (2<<5 | 1<<23 | 1<<16 )
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Parachute + 2 message failures in top and open')

-- these two-failures-in-open-and-fringe case all seem to just pass !? :-)
corrupt = crypt_n ~ (1<<23 | 2<<16 | 1<<14 )
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Parachute + 2 neighbouring failures in open and fringe')
corrupt = crypt_n ~ (1<<23 | 2<<16 | 1<<22 )
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Parachute + 2 non-neighbour failures in open and fringe')
corrupt = crypt_n ~ (1<<23 | 2<<16 | 1<<21 )
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Parachute + 2 opposite failures in open and fringe')

corrupt = crypt_n ~ (33<<4)
plain12 = golay_decode(corrupt)
ok(plain12 == n,
  'two errors in the checksum block on opposite faces in a Tropics')

corrupt = crypt_n ~ (33<<4 | 1<<16)
plain12 = golay_decode(corrupt)
ok(plain12 == n,
  'Tropics with a message failure in one of the poles')

corrupt = crypt_n ~ (33<<4 | 1<<13)
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Tropics with a message failure on the equator')

corrupt = crypt_n ~ (1<<3 | 1<<2)  -- 12  -- 9,10
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'two errors in the checksum block in a Diaper')

corrupt = crypt_n ~ (1<<17 | 1<<3 | 1<<2)  -- + 7, 9,10
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Diaper with a message failure in an adj=2 face')

corrupt = crypt_n ~ (1<<14 | 1<<3 | 1<<2)  -- + 10, 9,10
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Diaper with a message failure in an adj=3 face')

corrupt = crypt_n ~ (1<<16 | 1<<3 | 1<<2)  -- + 8, 9,10
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Diaper with a message failure in a waistline face')

corrupt = crypt_n ~ (1<<20 | 1<<3 | 1<<2)  -- + 4, 9,10
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Diaper with a message failure in a head|foot face')

corrupt = crypt_n ~ (1<<18 | 1<<3 | 1<<2)  -- + 6, 9,10
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Diaper with a message failure in a elbow|knee face')

corrupt = crypt_n ~ 9  -- 9,12
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'two errors in the checksum block in a Bent-Ring')

corrupt = crypt_n ~ (9 | 1<<19)  -- + 5, 9,12
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Bent-Ring with a message failure in an inside face')

corrupt = crypt_n ~ (9 | 1<<15)  -- + 9, 9,12
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Bent-Ring with a message failure in a checksum-error face')

corrupt = crypt_n ~ (9 | 1<<14)  -- + 10, 9,12
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Bent-Ring with a message failure in a shoulder face')

corrupt = crypt_n ~ (9 | 1<<13)  -- + 11, 9,12
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Bent-Ring with a message failure in a points_in face')

corrupt = crypt_n ~ (9 | 1<<16)  -- + 8, 9,12
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'Bent-Ring with a message failure in a points-out face')

corrupt = crypt_n ~ 21  -- 8,10,12
local plain12 = golay_decode(corrupt)
ok(plain12 == n, 'three errors in the checksum block in a Cage')

corrupt = crypt_n ~ (1<<9 | 1<<8 | 1<<1)  -- 3,4,11
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'three errors in the checksum block in a Cobra')

corrupt = crypt_n ~ (1<<9 | 1<<6 | 1<<1)  -- 3,6,11
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'three errors in the checksum block in a Islands')

corrupt = crypt_n ~ (1<<10 | 1<<1 | 1)  -- 2,11,12
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'three errors in the checksum block in a Broken-Tripod')

corrupt = crypt_n ~ (1<<7 | 1<<3 | 1)  -- 5,9,12
plain12 = golay_decode(corrupt)
ok(plain12 == n, 'three errors in the checksum block in a Deep-Bowl')

function enc_dec_all_possible_plaintexts()
	for p = 0,4095 do
		local c = golay_encode(p)
		if golay_decode(c) ~= p then return false end
	end
	return true
end
ok(enc_dec_all_possible_plaintexts(),
  'encode and decode all possible plaintexts')

function all_one_bit_errors()
	for i = 1, 24 do
		local corrupt = crypt_n ~ (1<<(24-i))
		local plain12 = golay_decode(corrupt)
		if plain12 ~= n then
			printf('i = %d   corrupt = %s   plain12 = %s',
			  i, bin24_2str(corrupt), bin12_2str(plain12))
			return false
		end
	end
	return true
end
ok(all_one_bit_errors(), 'all possible single-bit errors')

function all_two()
	for i = 1, 23 do
		local corrupt1 = crypt_n ~ (1<<(24-i))
		for j = i+1, 24 do 
			local corrupt2= corrupt1 ~ (1<<(24-j))
			local plain12 = golay_decode(corrupt2)
			if plain12 ~= n then
				printf('  i=%d j=%d  corrupt2 = %s   plain12 = %s',
				  i, j, bin24_2str(corrupt2), bin12_2str(plain12))
				return false
			end
		end
	end
	return true
end
ok(all_two(), 'all possible two-bit errors')

function all_three()
	for i = 1, 23 do
		local corrupt1 = crypt_n ~ (1<<(24-i))
		for j = i+1, 24 do 
			local corrupt2= corrupt1 ~ (1<<(24-j))
			for k = j+1, 24 do 
				local corrupt3= corrupt2 ~ (1<<(24-k))
				local plain12 = golay_decode(corrupt2)
				if plain12 ~= n then
					printf('  i=%d j=%d k=%d   corrupt3=%s   plain12=%s',
				  	i, j, k, bin24_2str(corrupt3), bin12_2str(plain12))
					return false
				end
			end
		end
	end
	return true
end
ok(all_three(), 'all possible three-bit errors')
-- XXXX

finish()


--[=[


=pod

=head1 NAME

 golay.lua  -- tests the extended Golay code G24 using lua bit-ops

=head1 SYNOPSIS

 golay.lua

=head1 DESCRIPTION

This script tests the encoding and decoding with the extended Golay code G24
using the Generator Matrix given in
https://en.wikipedia.org/wiki/Binary_Golay_code

So far (20210514)
it will detect and correct up to 3 errors in the message block,
or 1 error in the checksum block.

When fully implemented, any
3-bit errors can be corrected or any 7-bit errors can be detected.

=head1 ARGUMENTS

=over 3

=item I<-v>

Print the Version

=back

=head1 DOWNLOAD

This script is available at /home/pjb/lua/maths/golay.lua

=head1 AUTHOR

Peter J Billam, https://pjb.com.au/comp/contact.html

=head1 SEE ALSO

 https://en.wikipedia.org/wiki/Binary_Golay_code
 https://en.wikipedia.org/wiki/Hamming_distance
 https://en.wikipedia.org/wiki/Hamming_weight
 https://giam.southernct.edu/DecodingGolay/introduction.html
 https://giam.southernct.edu/DecodingGolay/encoding.html
 https://giam.southernct.edu/DecodingGolay/decoding.html
 https://giam.southernct.edu/DecodingGolay/example.html
 https://giam.southernct.edu/DecodingGolay/generalizations.html
 https://giam.southernct.edu/DecodingGolay/conclusions.html
 https://giam.southernct.edu/DecodingGolay/references.html
 V. Pless, Introduction to the Theory of Error-Correcting Codes,
   second edition, Wiley, New York, 1989.
 V. Pless, Decoding the Golay codes,
   IEEE Trans. Info. Theory 32 (1986), 561-567. 
 https://gcc.gnu.org/onlinedocs/gcc/Using-Assembly-Language-with-C.html
 https://pjb.com.au/

=cut

]=]
