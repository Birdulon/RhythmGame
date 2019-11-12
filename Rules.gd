extends Node

const COLS := 8
const COLS_ANGLE_DEG := 360.0/COLS
const COLS_ANGLE_RAD := COLS_ANGLE_DEG * TAU/360.0  # deg2rad isn't a const function which is completely stupid
const FIRST_COLUMN_ANGLE_DEG := (COLS_ANGLE_DEG/2.0 if !(COLS%2) else 0.0) - 90.0  #-67.5

const COLS_TOUCH_ARC_DEG := 240.0/COLS
