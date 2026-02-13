return {
	-- 0	vehicle has no storage
	-- 1	vehicle has no trunk storage
	-- 2	vehicle has no glovebox storage
	-- 3	vehicle has trunk in the hood
	Storage = {
		[`jester`] = 3,
		[`adder`] = 3,
		[`osiris`] = 1,
		[`pfister811`] = 1,
		[`penetrator`] = 1,
		[`autarch`] = 1,
		[`bullet`] = 1,
		[`cheetah`] = 1,
		[`cyclone`] = 1,
		[`voltic`] = 1,
		[`reaper`] = 3,
		[`entityxf`] = 1,
		[`t20`] = 1,
		[`taipan`] = 1,
		[`tezeract`] = 1,
		[`torero`] = 3,
		[`turismor`] = 1,
		[`fmj`] = 1,
		[`infernus`] = 1,
		[`italigtb`] = 3,
		[`italigtb2`] = 3,
		[`nero2`] = 1,
		[`vacca`] = 3,
		[`vagner`] = 1,
		[`visione`] = 1,
		[`prototipo`] = 1,
		[`zentorno`] = 1,
		[`trophytruck`] = 0,
		[`trophytruck2`] = 0,
	},

	-- slots, maxWeight; default weight is 8000 per slot
	glovebox = {
		[0] = {5, 55000},		-- Compact
		[1] = {5, 55000},		-- Sedan
		[2] = {5, 55000},		-- SUV
		[3] = {5, 55000},		-- Coupe
		[4] = {5, 55000},		-- Muscle
		[5] = {5, 55000},		-- Sports Classic
		[6] = {5, 55000},		-- Sports
		[7] = {5, 55000},		-- Super
		[8] = {1, 3000},		-- Motorcycle
		[9] = {5, 55000},		-- Offroad
		[10] = {5, 55000},		-- Industrial
		[11] = {5, 55000},		-- Utility
		[12] = {5, 55000},		-- Van
		[13] = {1, 3000},		-- Motorcycle
		[14] = {5, 55000},		-- Boat
		[15] = {5, 55000},		-- Helicopter
		[16] = {5, 55000},		-- Plane
		[17] = {5, 55000},		-- Service
		[18] = {5, 55000},		-- Emergency
		[19] = {5, 55000},		-- Military
		[20] = {5, 55000},		-- Commercial (trucks)
		models = {
			--[`xa21`] = {11, 88000}
		}
	},

	trunk = {
		[0] = {20, 110000},		-- Compact
		[1] = {25, 300000},		-- Sedan
		[2] = {35, 500000},		-- SUV
		[3] = {16, 110000},		-- Coupe
		[4] = {20, 200000},		-- Muscle
		[5] = {20, 200000},		-- Sports Classic
		[6] = {20, 200000},		-- Sports
		[7] = {10, 60000},		-- Super
		[8] = {5, 20000},		-- Motorcycle
		[9] = {30, 500000},		-- Offroad
		[10] = {45, 1200000},	-- Industrial
		[11] = {40, 500000},	-- Utility
		[12] = {45, 800000},	-- Van
		[13] = {1, 5000},	-- Cycles
		[14] = {25, 400000},	-- Boat
		[15] = {20, 200000},	-- Helicopter
		[16] = {25, 300000},	-- Plane
		[17] = {45, 600000},	-- Service
		[18] = {20, 300000},	-- Emergency
		[19] = {45, 200000},	-- Military
		[20] = {25, 120000},	-- Commercial
		[21] = {100, 1000000},	-- Trains
		models = {
			--[`xa21`] = {11, 10000}
		},
	}
}
