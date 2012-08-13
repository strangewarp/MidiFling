
local MidiFling = pd.Class:new():register("midifling-data-parse")



local function parseNoteAgainstAdc(adcval, bounds, target, kind, midinote, ntab)

	local pos = 2 -- Flag note byte for modification, or...
	if target == "velocity" then
		pos = 3 -- Flag velocity byte instead
	end
	
	if kind == "range" then -- The ADC value will control a MIDI value outright
	
		midinote[pos] = adcval
		
	elseif kind == "deviate" then -- The ADC value will deviate from its assigned MIDI value by a user-defined amount
	
		midinote[pos] =
			math.min(127,
				math.max(0,
					midinote[pos] + adcval
				)
			)
		
	elseif kind == "random" then -- The ADC value will deviate by a random amount, within a user-defined range and bias
	
		midinote[pos] =
			math.min(127,
				math.max(0,
					math.random(
						adcval,
						adcval + bounds[2]
					)
					+ midinote[pos]
				)
			)
		
	end

	if #ntab < 1 then
		ntab = midinote
	else
		ntab[pos] = midinote[pos]
	end
	
	return {ntab, midinote[2]}
	
end



function MidiFling:updateGUI()

	for k, v in ipairs(self.vtab) do
	
		local ctab = {}
		local vb = v.bounds
		
		local rsize = math.abs(vb[1]) + math.abs(vb[2])
		
		ctab[] = k - 1
		ctab[] = (math.abs(v.val) / rsize) * 256
		
		pd.send("midifling-gui-parser", "list", ctab)
	
	end
	
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
			bounds = {-15, 30},
			val = 1,
		},
		{
			chan = 8,
			target = "velocity",
			kind = "range",
			bounds = {0, 127},
			val = 1,
		},
		{
			chan = 9,
			target = "note",
			kind = "random",
			bounds = {-15, 30},
			val = 1,
		},
		{
			chan = 9,
			target = "velocity",
			kind = "range",
			bounds = {40, 52},
			val = 1,
		},
	}
	
	return true
	
end



-- Get incoming ADC data, and map it to internal variables, based on several user-defined effects
function MidiFling:in_1_list(l)

	local key = l[1] + 1
	local f = l[2]
	local vtab = self.vtab[key]

	-- If the ADC key maps to a user-defined ADC, then save its value internally
	if (key >= 1)
	and (key <= #self.vtab)
	then
		
		local b = vtab.bounds
		
		if vtab.kind == "range" then -- Map ADC value to a range. This value will later serve as a full command
		
			self.vtab[key].val =
				math.floor(
					math.max(b[1], b[2])
					* f
				)
			
		elseif (vtab.kind == "deviate")
		or (vtab.kind == "random")
		then -- Map ADC value to a range, plus offset (usually negative). This value will later modulate a command
		
			self.vtab[key].val =
				math.floor(b[2] * f)
				+ b[1]
		
		end
		
	end
	
end



function MidiFling:in_2_list(l)
	
end



-- Parse incoming MIDI values
function MidiFling:in_3_list(midi)

	local out = {}

	-- Pick apart the table of MIDI values into local variables
	local chan = midi[1] % 16
	local command = midi[1] - chan
	local note = midi[2]
	local velo = midi[3]
	
	if command == 128 then -- NOTE-OFF: use the note value to reference a pointer holding the saved offset sustain value
	
		out = {
			128 + chan,
			self.sustains[chan][note],
			velo
		}
	
		self.sustains[chan][note] = note
		
	elseif command == 144 then -- NOTE-ON: modify note values based upon internal ADC values, then save a sustain reference
	
		for k, v in pairs(self.vtab) do
		
			if v.chan == chan then
			
				local results = parseNoteAgainstAdc(v.val, v.bounds, v.target, v.kind, midi, out)
				out = results[1]
				self.sustains[chan][results[2]] = out[2]
			
			end
		
		end
	
	end
	
	self:outlet(1, "list", out)

end



-- Get a list of user-defined ADC/MIDI preferences, and map them to the table of internal ADC values their pointer indicates
function MidiFling:in_4_list(t)
	
	self.vtab[t[1]] = {
		chan = t[2],
		target = t[3],
		kind = t[4],
		bounds = {
			t[5],
			t[6],
		},
		val = 1,
	}
	
end
