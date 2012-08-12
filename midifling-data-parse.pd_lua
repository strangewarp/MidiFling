
local MidiFling = pd.Class:new():register("midifling-data-parse")



local function parseNoteAgainstAdc(adcval, chan, command, note, velo, target, kind, ntab)

	local nb = {}
	local nb[1] = chan + command
	local nb[2] = note
	local nb[3] = velo
	
	local pos = 2
	if target == "velocity" then
		pos = 3
	end
	
	if kind == "range" then
		nb[pos] = adcval
	elseif kind == "deviate" then
		nb[pos] = math.min(127, math.max(0, nb[pos] + adcval))
	elseif kind == "random" then
		nb[pos] = math.min(127, math.max(0, nb[pos] + math.random(adcval)))
	end

	if #ntab < 1 then
		ntab = nb
	else
		ntab[pos] = nb[pos]
	end
	
	return ntab, note, nb[2]
	
end



function MidiFling:initialize(sel, atoms)

	-- 1. Arduinome-style ADC data
	-- 2. Arc-style delta data
	-- 3. All MIDI-IN values
	-- 4. List of MIDI preferences
	self.inlets = 4
	
	-- All MIDI-THRU values
	self.outlets = 1
	
	-- Table for mapping sustains to their modified note values, to compensate for incoming note-offs
	self.sustains = {}
	for i = 0, 15 do
		self.sustains[i] = {}
		for ii = 0, 127 do
			self.sustains[i][ii] = ii
		end
	end
	
	-- Default ADC-value table
	self.vtab = {
		{
			chan = 8,
			target = "note",
			kind = "deviate",
			size = 30,
			val = 1,
		},
		{
			chan = 8,
			target = "velocity",
			kind = "range",
			size = 127,
			val = 1,
		},
		{
			chan = 9,
			target = "note",
			kind = "random",
			size = 30,
			val = 1,
		},
		{
			chan = 9,
			target = "velocity",
			kind = "range",
			size = 127,
			val = 1,
		},
	}
	
	return true
	
end



function MidiFling:in_1_list(l)

	local key = l[1] + 1
	local f = l[2]
	
	local vtab = self.vtab[key]

	if (key >= 1)
	and (key <= #self.vtab)
	then
		
		if vtab.kind == "range" then
		
			self.vtab[key].val = math.floor(vtab.size * f)
			
		elseif (vtab.kind == "deviate")
		or (vtab.kind == "random")
		then
		
			self.vtab[key].val = (vtab.size / f) + (vtab.size - (vtab.size / 2))
		
		end
		
	end
	
end



function MidiFling:in_2_list(l)
	
end



function MidiFling:in_3_list(l)

	local out = {}
	local offset = 0
	local preoffset = 0

	local chan = l[1] % 16
	local command = l[1] - chan
	local note = l[2]
	local velo = l[3]
	
	if command == 128 then
	
		out = {
			128 + chan,
			self.sustains[chan][note],
			velo
		}
	
		self.sustains[chan][note] = note
		
		self:outlet(1, "list", out)
	
	elseif command == 144 then
	
		for k, v in pairs(self.vtab) do
		
			if v.chan == chan then
			
				if v.kind == "range" then
				
					if v.target == "note" then
					
						self.sustains[chan][note] = v.val
					
						if #out < 1 then
							out = {
								144 + chan,
								v.val,
								velo
							}
						else
							out[2] = v.val
						end
						
					elseif v.target == "velocity" then
					
						self.sustains[chan][note] = note
						
						if #out < 1 then
							out = {
								144 + chan,
								note,
								v.val
							}
						else
							out[3] = v.val
						end
					
					end
				
				elseif (v.kind == "deviate") then
				
					if v.target == "note" then
					
						offset = note + v.val
						offset = math.max(0, offset)
						offset = math.min(127, offset)
				
						self.sustains[chan][note] = offset
					
						if #out < 1 then
							out = {
								144 + chan,
								offset,
								velo
							}
						else
							out[2] = offset
						end
						
					elseif v.target == "velocity" then
					
						offset = velo + v.val
						offset = math.max(0, offset)
						offset = math.min(127, offset)
				
						self.sustains[chan][note] = note
						
						if #out < 1 then
							out = {
								144 + chan,
								note,
								offset
							}
						else
							out[3] = offset
						end
					
					end
				
				elseif (v.kind == "random") then
				
					if v.target == "note" then
					
						offset = note + math.random(v.val)
						offset = math.max(0, offset)
						offset = math.min(127, offset)
				
						self.sustains[chan][note] = offset
					
						if #out < 1 then
							out = {
								144 + chan,
								offset,
								velo
							}
						else
							out[2] = offset
						end
						
					elseif v.target == "velocity" then
					
						offset = velo + math.random(v.val)
						offset = math.max(0, offset)
						offset = math.min(127, offset)
				
						self.sustains[chan][note] = note
						
						if #out < 1 then
							out = {
								144 + chan,
								note,
								offset
							}
						else
							out[3] = offset
						end
					
					end
				
				end
			
			end
		
		end
	
		self:outlet(1, "list", out)
	
	end
	
end



-- Get a list of user-defined ADC/MIDI preferences
function MidiFling:in_4_list(l)
	
	local p = 1
	
	for i = 1, i > #l, 4 do
	
		self.vtab[p] = {
			chan = l[i],
			target = l[i + 1],
			kind = l[i + 2],
			size = l[i + 3],
			val = 1,
		}
	
		p = p + 1
	
	end
	
end