-- Copyright 2012-2016 Patrick Gundlach (patrick@gundla.ch)
-- Public repository: https://github.com/pgundlach/lua-check-hyphen
-- Licensed under the MIT license. See the file 'mit-license.txt' for exact terms.

-- Version: see Makefile


-- for debugging purpuse:
-- function w( ... )
-- 	texio.write_nl("--->" .. string.format(...))
-- end

local explode = function(s,p)
	local t = { }
	for s in unicode.utf8.gmatch(s,p) do
		if s ~= "" then
			t[#t+1] = s
		end
	end
	return t
end

luacheckhyphen = {}


local hyphenattr = luatexbase.new_attribute("hyphenattr")

luacheckhyphen.hyphenwords = {}
luacheckhyphen.all_hyphenatedwords = {}
luacheckhyphen.word_whitelist = {}
luacheckhyphen.rectangle = node.new("whatsit","pdf_literal")
luacheckhyphen.rectangle.data = string.format("q 0 0 10 10 re f S Q")

local a_glyph_node   = node.id("glyph")
local a_disc_node    = node.id("disc")
local a_glue_node    = node.id("glue")
local a_whatsit_node = node.id("whatsit")
local subtype_rightskip = 9


local sln = unicode.utf8

luacheckhyphen.deligature = function ( glyph_node )
	local head = glyph_node.components
	local str = ""
	while head do
	if head.id == a_glyph_node then
		if head.components then
			str = str .. luacheckhyphen.deligature(head)
		else
			str = str .. sln.char(head.char)
		end
	end
	head = head.next
	end
	return str
end


-- This functions analyzes the list beginning at head. If it encounters a box,
-- it recurses into the box. If it finds a disc node, it goes back until it finds the word
-- start. Then it analyzes the word und finds all hyphenation points. For example the German
-- word "Salpetersäure" has these disc nodes: , "Sal-petersäure", "Salpe-tersäure",
-- "Salpeter-säure", and "Salpetersäu-re". Each of these "word with hyphen" gets stored in
-- the hash hyphenwords
luacheckhyphen.collect_discs = function(head)
	local word_start
	local word
	-- this is where we store all the breakpoints
	local thisbreakpoint
	local word_with_hyphen
	local c
	local hyphencounter = #luacheckhyphen.hyphenwords + 1
	local sln = unicode.utf8
	local ligature_chars
	while head do
	if head.id == 0 then
	elseif head.id == a_disc_node then
		word_start = head
		word_end   = head
		while word_start.prev and word_start.prev.id ~= a_glue_node do
			word_start = word_start.prev
		end
		word = ""
		c = 0
		while word_start and word_start.id ~= a_glue_node do
			if word_start == head then -- disc
				-- there is a breakpoint after letter c
				node.set_attribute(head,hyphenattr,hyphencounter)
				thisbreakpoint = c
			elseif word_start.id == a_glyph_node then
				if word_start.components then
					ligature_chars = luacheckhyphen.deligature(word_start)
					word = word .. ligature_chars
					c = c + string.len(ligature_chars)
				elseif sln.match(sln.char(word_start.char),"%a") then
					c = c + 1
					word = word .. sln.char(word_start.char)
				end
			end
			word_start = word_start.next
		end
		if thisbreakpoint then
			word_with_hyphen = sln.sub(word,1,thisbreakpoint) .. "-" .. sln.sub(word,thisbreakpoint+1,-1)
			-- word with hyphen has all possible hyphenation points
			luacheckhyphen.hyphenwords[hyphencounter] = word_with_hyphen
			hyphencounter = #luacheckhyphen.hyphenwords + 1
		end
	end
	head = head.next
	end
	return true
end

-- Remove '-' from word
local function removedash( word )
	local ret = sln.gsub(word,"-","")
	return ret
end

luacheckhyphen.check_discs = function (head,parent)
	local c
	local word
	local tmp
	while head do
	if head.id < 2 then -- a box, recurse
		luacheckhyphen.check_discs(head.list,head)
		-- package luashowhyphens has disc-whatsit-rightskip, without luashowhyphens it is disc-rightskip
	elseif  head.id == a_disc_node and head.next and head.next.id == a_glue_node and head.next.subtype == subtype_rightskip or
			head.id == a_disc_node and head.next and head.next.next and head.next.id == a_whatsit_node and head.next.next.id == a_glue_node and head.next.next.subtype == subtype_rightskip then
		c = node.has_attribute(head,hyphenattr)
		word = luacheckhyphen.hyphenwords[c]
		if luacheckhyphen.word_whitelist[word] then
			-- word found, but OK (whitelisted)
		else
			if luachekchyphen.compact == nil or luachekchyphen.compact == "true" then
				local word_without_hyphen = sln.lower(removedash(word))
				local tmp = luacheckhyphen.all_hyphenatedwords[word_without_hyphen] or {}
				tmp[word] = true
				luacheckhyphen.all_hyphenatedwords[word_without_hyphen] = tmp
			else
				luacheckhyphen.all_hyphenatedwords[word] = true
			end
			if luacheckhyphen.drawmarks then
				tmp = node.copy(luacheckhyphen.rectangle)
				node.insert_after(parent,head,tmp)
			end
		end
	end
	head = head.next
	end
	return true
end

-- http://www.lua.org/pil/19.3.html
local function pairsByKeys (t)
	local a = {}
  	for n in pairs(t) do table.insert(a, n) end
  	table.sort(a)
  	local i = 0      -- iterator variable
  	local iter = function ()   -- iterator function
  		i = i + 1
  		if a[i] == nil then return nil
  		else return a[i], t[a[i]]
  		end
  	end
  return iter
end

luacheckhyphen.listhyphenatedwords = function()
	if luacheckhyphen.final == "true" then
		return
	end
	-- don't write if the use has turned that off!
	if not luacheckhyphen.nofile then
		local unknown_hyphenation_filename = tex.jobname .. ".uhy"
		local unknown_hyphenation_file = io.open(unknown_hyphenation_filename,"w")
		for k,v in pairsByKeys(luacheckhyphen.all_hyphenatedwords) do
			if luachekchyphen.compact == "true" or luachekchyphen.compact == nil then
				local hyphenationlist = {}
				local hyphenpos = {}
				for l,_ in pairs(v) do
					local tmp = string.find(l,"-")
					if tmp then
						hyphenpos[#hyphenpos + 1] = tmp
					end
					hyphenationlist[#hyphenationlist + 1] = l
				end
				table.sort(hyphenpos)
				local word_with_all_hyphenationpoints = {}
				local cur = 1
				for i=1,string.len(k) do
					if hyphenpos[cur] == i then
						word_with_all_hyphenationpoints[#word_with_all_hyphenationpoints + 1] =  "-"
						cur = cur + 1
					end
					word_with_all_hyphenationpoints[#word_with_all_hyphenationpoints + 1]  = string.sub(k,i, i)
				end
				unknown_hyphenation_file:write(table.concat(word_with_all_hyphenationpoints,"") .. "\n")
			else
				unknown_hyphenation_file:write(k .. "\n")
			end
		end
		unknown_hyphenation_file:close()
	end

	texio.write_nl("log","All words with unknown hyphenation below")
	for k,v in pairs(luacheckhyphen.all_hyphenatedwords) do
		texio.write_nl("log",k)
	end
end

luacheckhyphen.enable = function()
	if luacheckhyphen.final == "true" then
		return
	end
	local whitelistfile,err
	local filecontents
	if luacheckhyphen.whitelist then
		for i,v in ipairs(string.explode(luacheckhyphen.whitelist,",")) do
			whitelistfile,err = io.open(v)
			if not whitelistfile then
				texio.write_nl(err)
			else
				filecontents = whitelistfile:read("*a")
				for _,entry in ipairs(explode(filecontents,"[^%s]+")) do
					parts = string.explode(entry,"-")
					if #parts > 2 then
						local c = 1
						for c=1,#parts - 1 do
							local word = {}
							for i=1,#parts do
								word[#word + 1] = parts[i]
								if i == c then
									word[#word + 1] = "-"
								end
							end
							luacheckhyphen.word_whitelist[table.concat(word,"")] = true
						end
					else
						luacheckhyphen.word_whitelist[entry] = true
					end
				end
			end
		end
	end
	if luacheckhyphen.mark == "true" then
		luacheckhyphen.drawmarks = true
	end
	luatexbase.add_to_callback("pre_linebreak_filter", luacheckhyphen.collect_discs,"collect_discs")
	luatexbase.add_to_callback("post_linebreak_filter",luacheckhyphen.check_discs,"check_discs")
end

return luacheckhyphen

-- end of file
