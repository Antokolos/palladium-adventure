# warning-ignore-all:unused_class_variable
# warning-ignore-all:shadowed_variable
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
# class_name PLDRuntimeNode

# Expected to be added to the SceneTree as a singleton object.

# ############################################################################ #
# Imports
# ############################################################################ #

var PLDStaticCommonUtils := load("res://addons/palladium/core/singletons/common_utils.tscn") as PackedScene
var PLDStaticMedia := load("res://addons/palladium/core/singletons/media.tscn") as PackedScene
var PLDStaticGameState := load("res://addons/palladium/core/singletons/game_state.tscn") as PackedScene
var PLDStaticLipsyncManager := load("res://addons/palladium/core/singletons/lipsync_manager.tscn") as PackedScene
var PLDStaticCutsceneManager := load("res://addons/palladium/core/singletons/cutscene_manager.tscn") as PackedScene
var PLDStaticConversationManager := load("res://addons/palladium/core/singletons/conversation_manager.tscn") as PackedScene
var PLDStaticStoryNode := load("res://addons/palladium/core/singletons/story_node.tscn") as PackedScene

var PLDSettings := load("res://addons/palladium/core/singletons/settings.gd") as GDScript
var PLDScenes := load("res://db/scenes.gd") as GDScript
var PLDChars := load("res://db/chars.gd") as GDScript
var PLDDB := load("res://db/db.gd") as GDScript
var PLDPrefs := load("res://db/prefs.gd") as GDScript

# ############################################################################ #
# Signals
# ############################################################################ #

# ############################################################################ #
# Properties
# ############################################################################ #

# ############################################################################ #

# ############################################################################ #
# "Static" Properties
# ############################################################################ #

var common_utils: Node = PLDStaticCommonUtils.instance().init(self)
var MEDIA: Node = PLDStaticMedia.instance().init(self)
var game_state: Node = PLDStaticGameState.instance().init(self)
var lipsync_manager: Node = PLDStaticLipsyncManager.instance().init(self)
var cutscene_manager: Node = PLDStaticCutsceneManager.instance().init(self)
var conversation_manager: Node = PLDStaticConversationManager.instance().init(self)
var story_node: Node = PLDStaticStoryNode.instance().init(self)

var settings: PLDSettings = PLDSettings.new(self)
var SCENES: PLDScenes = PLDScenes.new(self)
var CHARS: PLDChars = PLDChars.new(self)
var DB: PLDDB = PLDDB.new(self)
var PREFS: PLDPrefs = PLDPrefs.new(self)

# ############################################################################ #
# Internal Properties
# ############################################################################ #

# ############################################################################ #
# Overrides
# ############################################################################ #

func _init():
	name = "__PLDRT"
	add_child(common_utils)
	add_child(MEDIA)
	add_child(game_state)
	add_child(lipsync_manager)
	add_child(cutscene_manager)
	add_child(conversation_manager)
	add_child(story_node)

# ############################################################################ #
# Internal Methods
# ############################################################################ #

# ############################################################################ #
# Private Methods
# ############################################################################ #

# ############################################################################ #
# Internal Class
# ############################################################################ #
