-- Copyright 2012 Patrick Gundlach, patrick@gundla.ch
-- Public repository: https://github.com/pgundlach/lua-check-hyphen (issues/pull requests,...)
-- Version: see Makefile


-- for debugging purpuse:
-- function w( ... )
--   texio.write_nl(string.format(...))
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

luachekchyphen = {}


luachekchyphen.hyphenattr = luatexbase.new_attribute("hyphenattr")
luachekchyphen.hyphenwords = {}
luachekchyphen.all_hyphenatedwords = {}
luachekchyphen.word_whitelist = {}
luachekchyphen.rectangle = node.new("whatsit","pdf_literal")
luachekchyphen.rectangle.data = string.format("q 0 0 10 10 re f S Q")

luachekchyphen.deligature = function ( glyph_node )
  local sln = unicode.utf8
  local head = glyph_node.components
  local str = ""
  while head do
    if head.id == 37 then
      if head.components then
        str = str .. luachekchyphen.deligature(head)
      else
        str = str .. sln.char(head.char)
      end
    end
    head = head.next
  end
  return str
end


luachekchyphen.collect_discs = function(head)
  local word_start
  local word
  -- this is where we store all the breakpoints
  local thisbreakpoint
  local word_with_hyphen
  local c
  local hyphencounter = #luachekchyphen.hyphenwords + 1
  local sln = unicode.utf8
  local ligature_chars
  while head do
    if head.id == 0 then
    elseif head.id == 7 then --disc
      word_start = head
      word_end   = head
      while word_start.prev and word_start.prev.id ~= 10 do
        word_start = word_start.prev
      end
      word = ""
      c = 0
      while word_start and word_start.id ~= 10 do
        if word_start == head then -- disc
          -- there is a breakpoint after letter c
          node.set_attribute(head,luachekchyphen.hyphenattr,hyphencounter)
          thisbreakpoint = c
        elseif word_start.id == 37 then
          if word_start.components then
            ligature_chars = luachekchyphen.deligature(word_start)
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
        luachekchyphen.hyphenwords[hyphencounter] = word_with_hyphen
        hyphencounter = #luachekchyphen.hyphenwords + 1
      end
    end
    head = head.next
  end
  return true
end

luachekchyphen.check_discs = function (head,parent)
  local c
  local word
  local tmp
  while head do
    if head.id < 2 then
      luachekchyphen.check_discs(head.list,head)
    elseif head.id == 7 and head.next and head.next.id == 10 then -- disc
      c = node.has_attribute(head,luachekchyphen.hyphenattr)
      word = luachekchyphen.hyphenwords[c]
      if luachekchyphen.word_whitelist[word] then
      	  -- word found, but OK (whitelisted)
      else
	      luachekchyphen.all_hyphenatedwords[word] = true
     	  if luachekchyphen.drawmarks then
     	  	tmp = node.copy(luachekchyphen.rectangle)
     	  	node.insert_after(parent,head,tmp)
     	  end
	  end
    end
    head = head.next
  end
  return true
end

luachekchyphen.listhyphenatedwords = function()
	if luachekchyphen.final == "true" then
		return
	end
    local unknown_hyphenation_filename = tex.jobname .. ".uhy"
    local unknown_hyphenation_file = io.open(unknown_hyphenation_filename,"w")
  
    texio.write_nl("All words with unknown hyphenation below")
    for k,v in pairs(luachekchyphen.all_hyphenatedwords) do
  	    texio.write_nl(k)
    	unknown_hyphenation_file:write(k .. "\n")
    end
    unknown_hyphenation_file:close()
    texio.write_nl("All words with unknown hyphenation above\n")
end

luachekchyphen.enable = function()
	if luachekchyphen.final == "true" then
		return
	end
  	local whitelistfile,err
  	local filecontents
  	if luachekchyphen.whitelist then
  		for i,v in ipairs(string.explode(luachekchyphen.whitelist,",")) do
  			whitelistfile,err = io.open(v)
  			if not whitelistfile then
  				texio.write_nl(err)
	  		else
  				filecontents = whitelistfile:read("*a")
  				for _,entry in ipairs(explode(filecontents,"[^%s]+")) do
  					luachekchyphen.word_whitelist[entry] = true
	  			end
  			end
  		end
 	end
  	if luachekchyphen.mark == "true" then
  		luachekchyphen.drawmarks = true
  	end
    luatexbase.add_to_callback("pre_linebreak_filter", luachekchyphen.collect_discs,"collect_discs")
    luatexbase.add_to_callback("post_linebreak_filter",luachekchyphen.check_discs,"check_discs")
end

return luachekchyphen

-- end of file
