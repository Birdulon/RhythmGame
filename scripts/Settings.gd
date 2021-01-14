# A slightly redundant proxy to ProjectSettings
# This is mostly used so that signals can be used to respond to settings changes
extends Node

signal subsampling_changed(xy)

var subsampling: Vector2 setget SSXY_set, SSXY_get
var subsampling_x: float setget SSX_set, SSX_get
var subsampling_y: float setget SSY_set, SSY_get

func SSX_set(x: float):
	ProjectSettings.set_setting('rendering/quality/subsampling/x', x)
	emit_signal('subsampling_changed', self.subsampling)
func SSY_set(y: float):
	ProjectSettings.set_setting('rendering/quality/subsampling/y', y)
	emit_signal('subsampling_changed', self.subsampling)
func SSXY_set(xy: Vector2):
	ProjectSettings.set_setting('rendering/quality/subsampling/x', xy.x)
	ProjectSettings.set_setting('rendering/quality/subsampling/y', xy.y)
	emit_signal('subsampling_changed', self.subsampling)

func SSX_get() -> float:
	return ProjectSettings.get_setting('rendering/quality/subsampling/x')
func SSY_get() -> float:
	return ProjectSettings.get_setting('rendering/quality/subsampling/y')
func SSXY_get() -> Vector2:
	return Vector2(self.subsampling_x, self.subsampling_y)
