---------------------------------------------------------------------
--     This Lua5 module is Copyright (c) 2020, Peter J Billam      --
--                         pjb.com.au                              --
--  This module is free software; you can redistribute it and/or   --
--         modify it under the same terms as Lua5 itself.          --
---------------------------------------------------------------------
-- Example usage:
-- local EL = require 'elliptic_curve'
-- EL.foo()

local M = {} -- public interface
M.Version = '1.0'
M.VersionDate = '25feb2020'

------------------------------ private ------------------------------
local function warn(...)
    local a = {}
    for k,v in pairs{...} do table.insert(a, tostring(v)) end
    io.stderr:write(table.concat(a),'\n') ; io.stderr:flush()
end
local function die(...) warn(...);  os.exit(1) end
local function qw(s)  -- t = qw[[ foo  bar  baz ]]
    local t = {} ; for x in s:gmatch("%S+") do t[#t+1] = x end ; return t
end

local floor     = math.floor
local tointeger = math.tointeger
local RA        = nil -- rational.lua will be required if needed

---------------------------- Z/pZ ----------------------------------

function gcd (small, big)   -- consult urls.html
	small = tointeger(small)
	big   = tointeger(big)
	if small == big then return small end
	if small > big then small, big = big, small end
	local remainder
	while true do
		remainder = big % small
		if remainder == 0 then return small end
		big = small ; small = remainder
	end
end

function inverse (a, n) -- see urls.html "extended Euclidean algorithm"
	n = tointeger(n) -- if n is not already prime then n and a must be coprime
	a = tointeger(a) -- % n
	if a == 1 then return 1 end  -- is its own inverse
	if a == 0 then die('inverse called with a = 0') end
	-- if a == 0 then return nil, 'inverse called with a = 0' end
	if gcd(a,n)>1 then return nil,tostring(a)..' and '..n..' not coprime' end
	local quotient = {[-1]=1, [0]=1}
	local remainder
	local x = {0, 1}
	local i = 1 ; while true do
		quotient[i]  = floor(n/a)
		if not x[i] then -- inline i==1 and 1==2 because of quotient[i-2]
			x[i] = x[i-2] - x[i-1] * quotient[i-2]
		end
		remainder = n % a
		-- warn('i=',i,', ',n,'÷',a,', q[',i,']=',quotient[i],
		-- ', remainder=',remainder,', x[',i,']=',x[i])
		if remainder == 0 then
			-- warn('  returning ',x[i-1] - x[i] * quotient[i-1])
			return x[i-1] - x[i] * quotient[i-1]
		end
		n = a
		a = remainder
		i = i + 1
	end
end

function mod_mul (a, b, p)
	return (a*b) % p   -- could test for maxint etc
end

function mod_div (i, j, p)
	return mod_mul(i, inverse(j,p), p)
end

local infty = 'infty'   -- the point at infinity

function sqrt_modp (p)
-- first question: is x2 a quadratic residue of p ?
-- https://en.wikipedia.org/wiki/Modular_square_root
-- https://en.wikipedia.org/wiki/Chinese_remainder_theorem
-- https://math.stackexchange.com/questions/633160/modular-arithmetic-find-the-square-root
--   suppose you want to find (x)^(1/2) mod p(prime) then simply
--   calculate (x)^((p+1)/4) mod p.   Eg: in your case x=3 and p=11,
--   3^((11+1)/4)=27= 5 mod 11. similarly -5 will be a root.
-- https://math.stackexchange.com/questions/1895058/how-to-find-modulus-square-root?rq=1
-- If x2 is a quadratic residue (mod p) and p%4 == 3 then x2^((p+1)/4) is a
-- solution to x^2 ≡ a (mod p).  If p%4 == 1 there is no analogous formula.
-- In that case, one may use the Tonelli-Shanks algorithm.
--https://en.wikipedia.org/wiki/Tonelli%E2%80%93Shanks_algorithm
--https://en.wikipedia.org/wiki/Tonelli%E2%80%93Shanks_algorithm#The_algorithm
-- https://warwick.ac.uk/fac/sci/wdsi/people?selectedLetter=c#cremona-john
--  John Cremona works in computational number theory, in the area of
--  elliptic curves and modular forms. He is interested in tabulating these
--  sysetematically, and his database of elliptic curves, first published
--  within a book (Algorithms for Modular Elliptic Curves, CUP (1992)),
--  is a standard reference in the field.
	if p == 2 then
		return function (x2) return x2%2 end
	-- elseif p%4 == 3 then   -- x = x2 ^ ((p+1)/4)
	else  -- p%4 = 1   use the Tonelli-Shanks algorithm ?
		return function (x2)
			x2 = x2%p
			for i = 1, p/2 do  -- brute-force ...
				if (i*i)%p == x2 then return i end 
			end
			return nil
		end
	end
end
M.sqrt_modp     = sqrt_modp -- for debugging purposes

function y_gen_modp (a, b, p)   -- elliptic equation is y^2 = x^3 + a*x + b
	return function (xp)
		xp = xp%p
		local y_squared = (x*(x%p)%p + (a*x)%p + b)%p
		return sqrt_modp(y_squared, p)
	end
end

function add_gen_modp (a, b, p)
	-- a closure-generator add_gen_modp, because p,a,b rarely change
	-- elliptic equation is y^2 = x^3 + a*x + b
	-- a,b, xp,yp, xq,yq, s, xr,yr all Z/pZ
	-- the integer needed for crypto is the Elliptic Curve Discrete Logarithm
	-- we calculate a Z/pZ gradient, using modular arithmetic
	-- he adopts Z/pZ only from 07:00 onward
	-- at 10:48 he clearly gives points on the curve as xA,yA and xB,yB
	-- and at 11:25 he say a point on the curve is an ordered pair.
	-- see 12:20 for the example! 13:25 "remember, we're computing in mod 17"!
	-- so use mod_div()    20200226 passes first test :-)
	return function (xp, yp, xq, yq)   -- (
		if yp == infty then return xq,yq end
		if yq == infty then return xp,yp end
		if xp == xq then
			if yp == yq then   -- same point; use the tangent
				local s  = mod_div((3*xp*xp + a)%p, 2*yp, p)  -- 04:28
				local xr = s*s - 2*xp                     -- 04:40
				local yr = s*(xp-xr) - yp              -- 04:51
				return xr % p, yr % p
			else
				return 0,infty
			end
		end
		local s  = mod_div((yq-yp)%p, (xq-xp)%p, p)
		local xr = s*s - (xp+xq)   -- 03:40
		local yr = s*(xp-xr) - yp  -- 03:43
		return xr % p, yr % p
	end
end

function scalarmul_gen_modp (a, b, p)
	-- a closure-generator add_gen_modp, because p,a,b rarely change
	-- elliptic equation is y^2 = x^3 + a*x + b  mod p
	return function (xp, yp, k)   -- 06:00
		local total_x = xp
		local total_y = yp
		local addfunc = add_gen_modp (a, b, p)
		for i = 2,k do
			total_x, total_y = addfunc(total_x, total_y, xp, yp)
		end
		return total_x, total_y
	end
end

-- The Discrete Logarithm Problem is hard!  07:10
-- The Generator G and its Order            07:43
-- the Order n is the smallest positive integer k such that k*G = infty
-- the Cofactor h is the number of points on the elliptic curve defined by G
-- the Cofactor should be as small as possible, 1 is ideal
-- Domain parameters are { p,a,b,G,n,h }    08:32

------------------------------ R -----------------------------------

function y_gen_real (a, b)
	if 4*a*a*a + 27*b*b == 0 then return nil,
		'4*a^3 + 27*b^2 must not be zero; a='..tostring(a)..' b='..tostring(b)
	end
	local sqrt = math.sqrt
	return function (x)
		local y_squared = x*x*x + a*x + b
		if y_squared >= 0.0 then return sqrt(y_squared) else return nil end
	end
end

function add_gen_real (a, b)
	-- a closure-generator add_gen_real, because a,b rarely change
	-- elliptic equation is y^2 = x^3 + a*x + b
	if 4*a*a*a + 27*b*b == 0 then return nil,
		'4*a^3 + 27*b^2 must not be zero; a='..tostring(a)..' b='..tostring(b)
	end
	local infty = 'infty'   -- the point at infinity. Here, a string
	return function (xp, yp, xq, yq)
		if yp == infty then return xq,yq end
		if yq == infty then return xp,yp end
		if xp == xq then
			if yp == yq then   -- same point; use the tangent
				local s  = ((3*xp*xp) + a) / (2*yp)  -- 04:28
				local xr = s*s - 2*xp                -- 04:40
				local yr = s*(xp-xr) - yp            -- 04:51
				return xr, yr
			else
				return infty
			end
		end
		local s  = (yq-yp) / (xq-xp)
		local xr = s*s - (xp+xq)
		local yr = s*(xp-xr) - yp
		return xr, yr
	end
end

function scalarmul_gen_real (a, b)
	-- a closure-generator add_gen_real, because a,b rarely change
	-- elliptic equation is y^2 = x^3 + a*x + b
	if 4*a*a*a + 27*b*b == 0 then return nil,
		'4*a^3 + 27*b^2 must not be zero; a='..tostring(a)..' b='..tostring(b)
	end
	return function (xp, yp, k)   -- 06:00
		local total_x = xp
		local total_y = yp
		local addfunc = add_gen_real (a, b)
		for i = 2,k do
			total_x, total_y = addfunc(total_x, total_y, xp, yp)
		end
		return total_x, total_y
	end
end

------------------------------ Q -----------------------------------

function y_gen_rat (a, b)
--	if 4*a*a*a + 27*b*b == 0 then return nil,
--		'4*a^3 + 27*b^2 must not be zero; a='..tostring(a)..' b='..tostring(b)
--	end
	local sqrt = math.sqrt   -- ARGHHHhhh
	return function (x)
		local y_squared = RA.add(RA.add(RA.mul(x,RA.mul(x,x)) , RA.mul(a,x)) , b)
		return { math.tointeger(math.sqrt(y_squared[1])),
		         math.tointeger(math.sqrt(y_squared[2])) }
	end
end

function add_gen_rat (a, b)
	-- a closure-generator add_gen_rat, because a,b rarely change
	-- elliptic equation is y^2 = x^3 + a*x + b
	local infty = 'infty'   -- the point at infinity
	return function (xp, yp, xq, yq)
		-- use rational.lua! a,b integer; xp,yp, xq,yq, s, xr,yr all rational
		-- NO! a and b can be rational !
		--     (only in Ash and Gross must a,b be integers !)
		-- the rest of this all needs replacing !
		if yp[1] == infty then return xq,yq end
		if yq[1] == infty then return xp,yp end
		if RA.eq(xp,xq) then
			if RA.eq(yp,yq) then   -- same point; use the tangent
			-- ((3*xp*xp)%p + a) / (2*yp)  -- 04:28
				local s = RA.div( RA.add(RA.mul({3,1},RA.mul(xp,xp)), a),
			                      RA.mul({2,1}, yp) )
				-- s*s - 2*xp                  -- 04:40
				local xr = RA.sub(RA.mul(s,s), RA.mul({2,1},xp))
				-- s*(xp-xr) - yp              -- 04:51
				local yr = RA.sub(RA.mul(s, (RA.sub(xp,xr))), yp)
				return xr, yr
			else
				return {1,1}, {infty,1}
			end
		end
		-- (yq-yp) / (xq-xp)
		local s  = RA.div(RA.sub(yq,yp), RA.sub(xq,xp))
		-- s*s - (xp+xq)   -- 03:40
		local xr = RA.sub(RA.mul(s,s), RA.add(xp,xq))
		-- s*(xp-xr) - yp  -- 03:43
		local yr = RA.sub(RA.mul(s,RA.sub(xp,xr)), yp)
		return xr, yr
	end
end

function scalarmul_gen_rat (a, b)
	-- a closure-generator add_gen_rat, because a,b rarely change
	-- elliptic equation is y^2 = x^3 + a*x + b  mod p
	return function (xp, yp, k)   -- 06:00
		local total_x = xp
		local total_y = yp
		local addfunc = add_gen_rat (a, b)
		for i = 2,k do
			total_x, total_y = addfunc(total_x, total_y, xp, yp)
		end
		return total_x, total_y
	end
end

------------------------------ public ------------------------------

M.Version = "1.0  for Lua5"
M.VersionDate  = '17feb2020'
M.Synopsis = [[
  local EL = require 'elliptic_curve'
]]

-- the default is Z/pZ
M.add_gen       = add_gen_modp
M.scalarmul_gen = scalarmul_gen_modp

function M.set_numberfield (s)
	-- this is the numberfield of a and b, possibly also of xp,yp, xq,yq
	if     s == 'Q'    or string.find(s, '^rat') then
		if not RA then RA = require 'rational' end
		-- if xp,yp, xq,yq are rational then so is the gradient, and xr,yr
		-- but even if x is rational, y involves srqt and thus must be real!
		M.y_gen         = y_gen_rat
		M.add_gen       = add_gen_rat
		M.scalarmul_gen = scalarmul_gen_rat
		return true
	elseif s == 'R'    or string.find(s, '^real') then
		M.y_gen         = y_gen_real
		M.add_gen       = add_gen_real
		M.scalarmul_gen = scalarmul_gen_real
		return true
	elseif s == 'C'    or string.find(s, '^complex') then
		M.add_gen       = add_gen_complex
		M.scalarmul_gen = scalarmul_gen_complex
		return true
	elseif s == 'Z/pZ' or string.find(s, '^mod') then
		M.y_gen         = y_gen_modp
		M.add_gen       = add_gen_modp
		M.scalarmul_gen = scalarmul_gen_modp
		return true
	else
		return nil, 'unrecognised numberfield '..tostring(s)
	end
end

return M

--[=[

=pod

=head1 NAME

elliptic.lua - some functions needed by elliptic curves in Z/pZ, R and Q

=head1 SYNOPSIS

 local EL = require 'elliptic'
 EL.set_numbers('Q') -- rational; can also be 'F', 'Z/pZ'

=head1 DESCRIPTION

This module provides some functions needed by elliptic curves
in Z/pZ (modular arithmetic), R (real numbers) and Q (rational numbers)

=head1 FUNCTIONS

=over 3

=item I<set_numberfield(str)>

if I<str> is "C<R>" or "C<real>"
if I<str> is "C<Q>" or "C<rational>"
if I<str> is "C<Z/pZ>" or "C<modular>"

=back

=head2 Functions on Modular Integers B<Z/pZ>

=over 3

=item I<gcd (small, big)>

This is a low-level function which you should not need to invoke.

=item I<inverse (a, p)>

This is a low-level function which you should not need to invoke.

see urls.html "extended Euclidean algorithm"

=item I<mul (i, j, p)>

This is a low-level function which you should not need to invoke.

=item I<mod_div (i, j, p)>

This is a low-level function which you should not need to invoke.

=item I<add_gen_modp (a, b, p)>

This returns a closure with the given parameters.

	function (xp, yp, xq, yq)

=item I<scalarmul_gen_modp (a, b, p)>

This returns a closure with the given parameters.

	function (xp, yp, k)   -- 06:00

=back

=head2 Functions on Real Numbers B<R>

=over 3

y_gen_real (a, b)
	function (x)
add_gen_real (a, b)
	return function (xp, yp, xq, yq)
scalarmul_gen_real (a, b)
	return function (xp, yp, k)   -- 06:00

=back

=head2 Functions on Rational Numbers B<Q>

add_gen_rat (a, b)
	return function (xp, yp, xq, yq)
scalarmul_gen_rat (a, b, p)
	return function (xp, yp, k)   -- 06:00

=over 3

=item I<y_gen_real (a, b)>

=item I<add_gen_real (a, b)>

=item I<scalarmul_gen_real (a, b)>

=item I<add_gen_rat (a, b)>

With my elliptic equation, the first four Weierstrass coefficients are zero.
https://www.lmfdb.org/EllipticCurve/Q/?start=50&hst=List&conductor=1-99
a,b = -11,-14  -1,14  -1,0   4,0  -135,-594   -15,22   0,-27   0,1
   -4,-3   1,-10   -299,1990   -59,-138   -19,30   1,2

=item I<scalarmul_gen_rat (a, b, p)>

=back

=head1 DOWNLOAD

This module is available at
http://pjb.com.au/comp/lua/elliptic.html

=head1 AUTHOR

Peter J Billam, http://pjb.com.au/comp/contact.html

=head1 SEE ALSO

 "Elliptic Tales", Ash and Gross
 https://www.youtube.com/watch?v=F3zzNa42-tQ
 https://en.wikipedia.org/wiki/Chinese_remainder_theorem
 https://warwick.ac.uk/fac/sci/wdsi/people?selectedLetter=c#cremona-john
 https://www.lmfdb.org/
 https://www.lmfdb.org/EllipticCurve/Q/
 https://www.lmfdb.org/EllipticCurve/Q/?start=50&hst=List&conductor=1-99
 http://pjb.com.au/

=cut

]=]

