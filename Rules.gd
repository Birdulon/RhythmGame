extends Node

const COLS := 8
const COLS_ANGLE_DEG := 360.0/COLS
const COLS_ANGLE_RAD := COLS_ANGLE_DEG * TAU/360.0  # deg2rad isn't a const function which is completely stupid
const FIRST_COLUMN_ANGLE_DEG := (COLS_ANGLE_DEG/2.0 if !(COLS%2) else 0.0) - 90.0  #-67.5

const COLS_TOUCH_ARC_DEG := 240.0/COLS

const JUDGEMENT_STRINGS := ["Perfect", "Great", "Good", "Almost"]
const JUDGEMENT_TIERS := 4
const JUDGEMENT_TIMES_PRE := [0.040, 0.090, 0.125, 0.150]
const JUDGEMENT_TIMES_POST := [0.040, 0.090, 0.125, 0.150]
const JUDGEMENT_TIMES_RELEASE_PRE := [0.040, 0.090, 0.125, 0.150]
const JUDGEMENT_TIMES_RELEASE_POST := [0.090, 0.140, 0.175, 0.200]  # Small grace period
const JUDGEMENT_TIMES_SLIDE_PRE := [0.090, 0.140, 0.175, 0.200]  # Small grace period, sort-of
const JUDGEMENT_TIMES_SLIDE_POST := [0.090, 0.140, 0.175, 0.200]

const SCORE_STRINGS =  ["SSS", "SS", "S", "A⁺", "A", "B⁺", "B", "C⁺", "C", "F"]
const SCORE_CUTOFFS = [1.0, 0.975, 0.95, 0.9, 0.85, 0.8, 0.7, 0.6, 0.5]