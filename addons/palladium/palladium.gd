tool
extends EditorPlugin

func _enter_tree():
	_add_autoloads()

func _exit_tree():
	_remove_autoloads()

## Registers the Ink runtime node as an autoloaded singleton.
func _add_autoloads():
	add_autoload_singleton("__PLDRT", "res://addons/palladium/core/singletons/pld_runtime.gd")

## Unregisters the Ink runtime node from autoloaded singletons.
func _remove_autoloads():
	remove_autoload_singleton("__PLDRT")
