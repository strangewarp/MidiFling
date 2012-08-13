
local MidiFling = pd.Class:new():register("midifling-data-parse")



local function parseNoteAgainstAdc(adcval, bounds, target, kind, midinote, ntab)

	local pos = 2 -- Flag note byte for modification, or...
	if target == "velocity" then
		pos = 3 -- Flag velocity byte instead
	end
	
	if kind == "range" then -- The ADC value will control a MIDI value outright
	
		midinote[pos] = adcval
		
	elseif kind == "deviate" then -- The ADC value will deviate its assigned MIDI value within user-defined bounds
	
		midinote[pos] =
			math.min(127,
				math.max(0,
					midinote[pos]
					+ adcval
					+ bounds[1]
				)
			)
		
	elseif kind == "random" then -- The MIDI value will deviate by a random amount, within an ADC-defined range
	
		local range = math.abs(bounds[1]) + math.abs(bounds[2])
		local modrange = range - adcval
		rangelow = adcval + bounds[1]
		rangehigh = bounds[2] - adcval
	
		midinote[pos] =
			math.min(127,
				math.max(0,
					math.random(
						midinote[pos] + rangelow,
						midinote[pos] + rangehigh
					)
				)
			)
		
	end

	-- Convert input table into note table, or create it if it's empty
	if #ntab < 1 then
		ntab = midinote
	else
		ntab[pos] = midinote[pos]
	end
	
	return {ntab, midinote[2]}
	
end



-- Send naked number color values to the Pd function that will turn them into GUI colors
function MidiFling:updateGUI()

	for k, v in pairs(self.vtab) do
	
		local ctab = {}
		local vb = v.bounds
		
		local rsize = math.abs(vb[1]) + math.abs(vb[2])
		
		ctab[] = k - 1
		ctab[] = (math.abs(v.val) / rsize) * 256
		
		pd.send("midifling-gui-parser", "list", ctab)
	
	end
	
end



function MidiFling:initialize(sel, atoms)

	-- 1. All incoming ADC data
	-- 2. All MIDI-IN values
	-- 3. List of MIDI preferences
	self.inlets = 3
	
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
	
	-- ADC-value table; empty until filled by the user-preferences from the Pd program
	self.vtab = {}
	
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
		
		-- Map ADC value to a range. This value will later modulate MIDI commands
		local b = vtab.bounds
		local range = math.abs(b[1]) + math.abs(b[2])
		self.vtab[key].val = math.floor(range * f)
		
	end
	
end



-- Parse incoming MIDI values
function MidiFling:in_2_list(midi)

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
function MidiFling:in_3_list(t)
	
	if self.vtab[t[1]] == nil then
		self.vtab[t[1] = {}
	end
	
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
