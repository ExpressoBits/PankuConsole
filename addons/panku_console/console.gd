## Panku Console. Provide a runtime GDScript REPL so your can run any script expressions in your game!
##
## This class will be an autoload ([code] Console [/code] by default) if you enable the plugin. The basic idea is that you can run [Expression] based on an environment(or base instance) by [method execute]. You can view [code]default_env.gd[/code] to see how to prepare your own environment.
## [br]
## [br] What's more, you can...
## [br]
## [br] ● Send in-game notifications by [method notify]
## [br] ● Output something to the console window by [method output]
## [br] ● Manage widgets plans by [method add_widget], [method save_current_widgets_as], etc.
## [br] ● Lot's of useful expressions defined in [code]default_env.gd[/code].
##
## @tutorial:            https://github.com/Ark2000/PankuConsole
class_name PankuConsole extends CanvasLayer

## Emitted when the visibility (hidden/visible) of console window changes.
signal console_window_visibility_changed(is_visible:bool)

## The input action used to toggle console. By default it is KEY_QUOTELEFT.
var toggle_console_action:String

## If [code]true[/code], pause the game when the console window is active.
var pause_when_active:bool

@onready var _resident_logs = $ResidentLogs
@onready var _console_window = $LynxWindows/ConsoleWindow
@onready var _console_ui = $LynxWindows/ConsoleWindow/Body/Content/PankuConsoleUI
@onready var _base_instance = $BaseInstance
@onready var _windows = $LynxWindows

const _monitor_widget_pck = preload("res://addons/panku_console/components/widgets2/monitor_widget.tscn")

var _envs = {}
var _envs_info = {}
var _expression = Expression.new()

## Returns whether the console window is opened.
func is_console_window_opened():
	return _console_window.visible

## Register an environment that run expressions.
## [br][code]env_name[/code]: the name of the environment
## [br][code]env[/code]: The base instance that runs the expressions. For exmaple your player node.
func register_env(env_name:String, env:Object):
	_envs[env_name] = env
	output("[color=green][Info][/color] [b]%s[/b] env loaded!"%env_name)
	if env is Node:
		env.tree_exiting.connect(
			func(): remove_env(env_name)
		)
	if env.get_script():
		var env_info = PankuUtils.extract_info_from_script(env.get_script())
		for k in env_info:
			var keyword = "%s.%s" % [env_name, k]
			_envs_info[keyword] = env_info[k]

## Return the environment object or [code]null[/code] by its name.
func get_env(env_name:String) -> Node:
	return _envs.get(env_name)

## Remove the environment named [code]env_name[/code]
func remove_env(env_name:String):
	if _envs.has(env_name):
		_envs.erase(env_name)
		for k in _envs_info.keys():
			if k.begins_with(env_name + "."):
				_envs_info.erase(k)
	notify("[color=green][Info][/color] [b]%s[/b] env unloaded!"%env_name)

## Generate a notification
func notify(any) -> void:
	var text = str(any)
	_resident_logs.add_log(text)
	output(text)

func output(any) -> void:
	_console_ui.output(any)

#This only return the expression result
func execute(exp:String) -> Dictionary:
#	print(exp)
	var failed := false
	var result
	var error = _expression.parse(exp, _envs.keys())
	if error != OK:
		failed = true
		result = _expression.get_error_text()
	else:
		result = _expression.execute(_envs.values(), _base_instance, true)
		if _expression.has_execute_failed():
			failed = true
			result = _expression.get_error_text()
	return {
		"failed": failed,
		"result": result
	}
	
func add_widget2(exp:String, update_period:= 999999.0, position:Vector2 = Vector2(0, 0), size:Vector2 = Vector2(100, 20), title_text := ""):
	if title_text == "": title_text = exp
	var w = _monitor_widget_pck.instantiate()
	w.position = position
	w.size = size
	w.update_exp = exp
	w.update_period = update_period
	w.title_text = title_text
	_windows.add_child(w)

func _input(_e):
	if Input.is_action_just_pressed(toggle_console_action):
		_console_ui._input_area.input.editable = !_console_window.visible
		await get_tree().process_frame
		_console_window.visible = !_console_window.visible

func _ready():
	assert(get_tree().current_scene != self, "Do not run this directly")

	pause_when_active = ProjectSettings.get("panku/pause_when_active")
	toggle_console_action = ProjectSettings.get("panku/toggle_console_action")
	
	print(PankuConfig.get_config())
	_console_window.hide()
	_console_window.visibility_changed.connect(
		func():
			console_window_visibility_changed.emit(_console_window.visible)
			if pause_when_active:
				get_tree().paused = _console_window.visible
	)
	#check the action key
	#the open console action can be change in the export options of panku.tscn
	assert(InputMap.has_action(toggle_console_action), "Please specify an action to open the console!")

	#add info of base instance
	var env_info = PankuUtils.extract_info_from_script(_base_instance.get_script())
	for k in env_info: _envs_info[k] = env_info[k]

	var w_data = PankuConfig.get_config()["widgets_data"]
	for w in w_data:
		add_widget2(w["exp"], w["period"], w["position"], w["size"], w["title"])

func _notification(what):
	#quit event
	if what == 1006:
		var widgets_data = []
		for w in _windows.get_children():
			if w is MonitorWidget:
				widgets_data.push_back({
					"exp": w.update_exp,
					"position": w.position,
					"size": w.size,
					"period": w.update_period,
					"title": w.title_text
				})
		var cfg = PankuConfig.get_config()
		cfg["widgets_data"] = widgets_data
		PankuConfig.set_config(cfg)
