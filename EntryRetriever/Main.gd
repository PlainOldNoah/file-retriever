extends PanelContainer

const WindowSize = Vector2(800, 350)

var inputFolderFormat = "Logs - *"
var inputFileFormat = "(??) * - *"

enum INPUT_TYPES {DIRECTORY, FILE, FILES}
var inputType

#---------------------------- NODES
onready var SelectionInput = $MarginContainer/GUI/PanelContainer/VBoxContainer/HBoxContainer/SelectionInput

onready var FileCountOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/FileCount
onready var EntryCountOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/EntryCount
onready var MatchCountOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/MatchCount
onready var ElapsedTimeOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/ElapsedTime
onready var StatusBarOutput = $MarginContainer/GUI/Progress/VBoxContainer/StatusBar

onready var InputFileDialog = $SingleInputFileDialog

onready var AppendButton = $MarginContainer/GUI/LowerHalf/RightSide/Export/VBoxContainer/HBoxContainer/Append
onready var OverwriteButton = $MarginContainer/GUI/LowerHalf/RightSide/Export/VBoxContainer/HBoxContainer/Overwrite
#============================ Functions

func _ready():
	OS.set_window_position(OS.get_screen_size()*0.5 - OS.get_window_size()*0.5)
	resetStatistics()

func resetStatistics():
	FileCountOutput.text = "0"
	EntryCountOutput.text = "0"
	MatchCountOutput.text = "0"
	ElapsedTimeOutput.text = "0"
	StatusBarOutput.text = "Idle"

#Recursively loops though directories and retrieves files
func directoryIterate(path):
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			#Filters out Non-Log Folders
			if dir.current_is_dir() and file_name.match(inputFolderFormat):
				print("Directory: " + file_name)
				directoryIterate(dir.get_current_dir() + "/" + file_name)
			#Filters out files that don't have the right naming scheme
			elif file_name.match(inputFileFormat):
				print("File: " + file_name)
				FileCountOutput.text = str(int(FileCountOutput.text) + 1)
			file_name = dir.get_next()
	else:
		print_debug("ERROR: Bad Path Parameter: ", path)

#---------------------------- Buttons

func _on_Run_pressed():
	resetStatistics()
	directoryIterate(SelectionInput.text)


func _on_Clear_pressed():
	resetStatistics()

func _on_Quit_pressed():
	get_tree().quit()


func _on_ExportBtn_pressed():
	pass # Replace with function body.


func _on_FileSelect_pressed():
	InputFileDialog.popup_centered_ratio(0.8)


func _on_Append_pressed():
	if AppendButton.pressed == true:
		OverwriteButton.pressed = false

func _on_Overwrite_pressed():
	if OverwriteButton.pressed == true:
		AppendButton.pressed = false


func _on_WindowToggleBtn_pressed():
	pass # Replace with function body.

#File Input
func _on_SingleInputFileDialog_dir_selected(dir):
	inputType = INPUT_TYPES.DIRECTORY
	SelectionInput.text = dir

func _on_SingleInputFileDialog_file_selected(path):
	inputType = INPUT_TYPES.FILE
	SelectionInput.text = path
