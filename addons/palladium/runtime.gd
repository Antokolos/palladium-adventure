# ############################################################################ #
# Copyright © 2022-present NLB project <antokolos@gmail.com>
# All Rights Reserved
#
# This file is part of Palladium framework.
# Palladium framework is licensed under the terms of the MIT license.
# ############################################################################ #

extends Node

# Hiding this type to prevent registration of "private" nodes.
# See https://github.com/godotengine/godot-proposals/issues/1047
# class_name PLDRuntime

static func init(root_node, stop_on_error = true):
	if root_node.has_node("__PLDRT"):
		return root_node.get_node("__PLDRT")

	var _pld_runtime = load("res://addons/palladium/core/singletons/pld_runtime.gd").new()

	root_node.add_child(_pld_runtime)

	return _pld_runtime

static func deinit(root_node):
	var _pld_runtime = root_node.get_node("__PLDRT")
	root_node.remove_child(_pld_runtime)
	_pld_runtime.queue_free()
