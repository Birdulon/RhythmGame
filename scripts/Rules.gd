extends Node

const COLS := 8
const COLS_ANGLE_DEG := 360.0/COLS
const COLS_ANGLE_RAD := COLS_ANGLE_DEG * TAU/360.0  # deg2rad isn't a const function which is completely stupid
const FIRST_COLUMN_ANGLE_DEG := (COLS_ANGLE_DEG/2.0 if !(COLS%2) else 0.0) - 90.0  #-67.5

const COLS_TOUCH_ARC_DEG := 240.0/COLS

const JUDGEMENT_STRINGS := ['Perfect', 'Great', 'Good', 'Almost']
const JUDGEMENT_TIERS := 4
const JUDGEMENT_TIMES_PRE := [0.040, 0.090, 0.125, 0.150]
const JUDGEMENT_TIMES_POST := [0.040, 0.090, 0.125, 0.150]
const JUDGEMENT_TIMES_RELEASE_PRE := [0.040, 0.090, 0.125, 0.150]
const JUDGEMENT_TIMES_RELEASE_POST := [0.090, 0.140, 0.175, 0.200]  # Small grace period
const JUDGEMENT_TIMES_SLIDE_PRE := [0.090, 0.240, 0.4, 60.000]  # Small grace period, sort-of. Just be generous, really.
const JUDGEMENT_TIMES_SLIDE_POST := [0.090, 0.140, 0.175, 0.200]
const JUDGEMENT_SCORES = [1.0, 0.9, 0.75, 0.5, 0.0]
#var judge_scores = [1.0, 0.9, 0.75, 0.5, 0.0]
#var notetype_weights = [1.0, 1.0, 1.0, 1.0, 1.0]

const SCORE_STRINGS =  ['SSS', 'SS', 'S', 'A⁺', 'A', 'B⁺', 'B', 'C⁺', 'C', 'F']
const SCORE_CUTOFFS = [1.0, 0.975, 0.95, 0.9, 0.85, 0.8, 0.7, 0.6, 0.5]

const SLIDE_RADIUS2 = 10000.0  # Radius of 100px

# Not really a fan of Simply Love grading
# Scoring can probably be fine with a strictly positive scheme, but I really dislike having so many grades and the ± feels meaningless.
# I think a SSS/SS/S/A/B/C/D/E/F(ail) grading scheme is sufficient, perhaps with a + to signify a full combo clear
# * could also be used for full perfect clear, though these suffixes would be meaningless at the highest grades which practically require FC/PFC
const STEPMANIA_METRICS = {
	'Casual': {  # Taken from Simply Love.
		'GRADE_STRINGS': ['****', '***', '**', '*', 'S⁺', 'S', 'S¯', 'A⁺', 'A', 'A¯', 'B⁺', 'B', 'B¯', 'C⁺', 'C', 'C¯', 'D'],
		'GRADE_CUTOFFS': [1.00, 0.99, 0.98, 0.96, 0.94, 0.92, 0.89, 0.86, 0.83, 0.80, 0.76, 0.72, 0.68, 0.64, 0.60, 0.55, -999],
		'JUDGEMENT_WEIGHTS': {
			1: 3,
			2: 2,
			3: 1,
			4: 0,
			5: 0,
			'Miss': 0,
			'Held': 3,
			'LetGo': 0,
		},
		'TIMING_SECONDS': {
			1: 0.0215,
			2: 0.0430,
			3: 0.1020,
			4: 0.1020,
			5: 0.1020,
			'Hold': 0.320,
			'Roll': 0.350,
		},
		'TIMING_SECONDS_ADD': 0.0015
	},
	'ITG': {  # In The Groove - taken from Simply Love.
		'GRADE_STRINGS': ['****', '***', '**', '*', 'S⁺', 'S', 'S¯', 'A⁺', 'A', 'A¯', 'B⁺', 'B', 'B¯', 'C⁺', 'C', 'C¯', 'D'],
		'GRADE_CUTOFFS': [1.00, 0.99, 0.98, 0.96, 0.94, 0.92, 0.89, 0.86, 0.83, 0.80, 0.76, 0.72, 0.68, 0.64, 0.60, 0.55, -999],
		'JUDGEMENT_WEIGHTS': {
			1: 5,
			2: 4,
			3: 2,
			4: 0,
			5: -6,
			'Miss': -12,
			'Held': 5,
			'LetGo': 0,
		},
		'TIMING_SECONDS': {
			1: 0.0215,
			2: 0.0430,
			3: 0.1020,
			4: 0.1350,
			5: 0.1800,
			'Hold': 0.320,
			'Roll': 0.350,
		},
		'TIMING_SECONDS_ADD': 0.0015
	},
	'ITG+': {  # My modification of ITG to be strictly positive.
		'GRADE_STRINGS': ['****', '***', '**', '*', 'S⁺', 'S', 'S¯', 'A⁺', 'A', 'A¯', 'B⁺', 'B', 'B¯', 'C⁺', 'C', 'C¯', 'D'],
		'GRADE_CUTOFFS': [1.00, 0.99, 0.98, 0.96, 0.94, 0.92, 0.89, 0.86, 0.83, 0.80, 0.76, 0.72, 0.68, 0.64, 0.60, 0.55, 0],
		'JUDGEMENT_WEIGHTS': {
			1: 17,
			2: 16,
			3: 14,
			4: 12,
			5: 6,
			'Miss': 0,
			'Held': 17,
			'LetGo': 12,
		},
		'TIMING_SECONDS': {
			1: 0.0215,
			2: 0.0430,
			3: 0.1020,
			4: 0.1350,
			5: 0.1800,
			'Hold': 0.320,
			'Roll': 0.350,
		},
		'TIMING_SECONDS_ADD': 0.0015
	},
	'ECFA': {  # Everybody Can Fantastic Attack - taken from Simply Love. Stricter than ITG.
		'GRADE_STRINGS': ['****', '***', '**', '*', 'S⁺', 'S', 'S¯', 'A⁺', 'A', 'A¯', 'B⁺', 'B', 'B¯', 'C⁺', 'C', 'C¯', 'D'],
		'GRADE_CUTOFFS': [1.00, 0.99, 0.98, 0.96, 0.94, 0.92, 0.89, 0.86, 0.83, 0.80, 0.76, 0.72, 0.68, 0.64, 0.60, 0.55, -999],
		'JUDGEMENT_WEIGHTS': {
			1: 5,
			2: 5,
			3: 4,
			4: 2,
			5: 0,
			'Miss': -12,
			'Held': 5,
			'LetGo': 0,
		},
		'TIMING_SECONDS': {
			1: 0.0110,
			2: 0.0215,
			3: 0.0430,
			4: 0.1020,
			5: 0.1350,
			'Hold': 0.320,
			'Roll': 0.350,
		},
		'TIMING_SECONDS_ADD': 0.0015
	}
}

#ITG = {
#	LifePercentChangeW1=0.008,
#	LifePercentChangeW2=0.008,
#	LifePercentChangeW3=0.004,
#	LifePercentChangeW4=0.000,
#	LifePercentChangeW5=-0.050,
#	LifePercentChangeMiss=-0.100,
#	LifePercentChangeLetGo=IsGame('pump') and 0.000 or -0.080,
#	LifePercentChangeHeld=IsGame('pump') and 0.000 or 0.008,
#	LifePercentChangeHitMine=-0.050,
#},
#['FA+'] = {
#	LifePercentChangeW1=0.008,
#	LifePercentChangeW2=0.008,
#	LifePercentChangeW3=0.008,
#	LifePercentChangeW4=0.004,
#	LifePercentChangeW5=0,
#	LifePercentChangeMiss=-0.1,
#	LifePercentChangeLetGo=-0.08,
#	LifePercentChangeHeld=0.008,
#	LifePercentChangeHitMine=-0.05,
#},

#['FA+'] = {
#	TimingWindowAdd=0.0015,
#	RegenComboAfterMiss=5,
#	MaxRegenComboAfterMiss=10,
#	MinTNSToHideNotes='TapNoteScore_W4',
#	HarshHotLifePenalty=true,
#
#	PercentageScoring=true,
#	AllowW1='AllowW1_Everywhere',
#	SubSortByNumSteps=true,
#
#	TimingWindowSecondsW1=0.011000,
#	TimingWindowSecondsW2=0.021500,
#	TimingWindowSecondsW3=0.043000,
#	TimingWindowSecondsW4=0.102000,
#	TimingWindowSecondsW5=0.135000,
#	TimingWindowSecondsHold=0.320000,
#	TimingWindowSecondsMine=0.065000,
#	TimingWindowSecondsRoll=0.350000,
#},


# Might move this to a more general singleton later
func get_input_action_map() -> Dictionary:
	var dict = {}
	for key in InputMap.get_actions():
		dict[key] = InputMap.get_action_list(key)
	return dict

onready var action_map := get_input_action_map()
