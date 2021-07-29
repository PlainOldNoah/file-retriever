extends PanelContainer

const WindowSize = Vector2(800, 360)

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
onready var OutputTextBox = $MarginContainer/GUI/OutputWindow/TextBox

onready var InputFileDialog = $SingleInputFileDialog

onready var AppendButton = $MarginContainer/GUI/LowerHalf/RightSide/Export/VBoxContainer/HBoxContainer/Append
onready var OverwriteButton = $MarginContainer/GUI/LowerHalf/RightSide/Export/VBoxContainer/HBoxContainer/Overwrite
#============================ Functions

func _ready():
	OS.set_window_position(OS.get_screen_size()*0.5 - OS.get_window_size()*0.5)
	reset_Statistics()

func reset_Statistics():
	FileCountOutput.text = "0"
	EntryCountOutput.text = "0"
	MatchCountOutput.text = "0"
	ElapsedTimeOutput.text = "0"
	StatusBarOutput.text = "Idle"

#Recursively loops though directories and retrieves files
func directory_Iterate(path):
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			#Filters out Non-Log Folders
			if dir.current_is_dir() and file_name.match(inputFolderFormat):
				print("Directory: " + file_name)
				directory_Iterate(dir.get_current_dir() + "/" + file_name)
			#Filters out files that don't have the right naming scheme
			elif file_name.match(inputFileFormat):
				print("File: " + file_name)
				read_File(dir.get_current_dir() + "/" + file_name)
			file_name = dir.get_next()
	else:
		print_debug("ERROR: Bad Path Parameter: ", path)


var entryHeaderFormat = "*/*/*, *"
func read_File(file):
	FileCountOutput.text = str(int(FileCountOutput.text) + 1)
	
	var f = File.new()
	f.open(file, File.READ)
	
	var line = f.get_line()
	var entryHeaderPos = 0
	
	#Read though until file
	while not f.eof_reached():
		#Checking for headers and marking their position
		if line.matchn(entryHeaderFormat):
			EntryCountOutput.text = str(int(EntryCountOutput.text) + 1)
			entryHeaderPos = f.get_position() - line.length() - 2
		
			
			while not line.strip_escapes().empty():
				if find_Match(line):
					f.seek(entryHeaderPos)
					line = f.get_line()
					
					while not line.strip_escapes().empty():
						print_to_output(line)
						line = f.get_line()
					OutputTextBox.bbcode_text += "\n"
					
				else: line = f.get_line()
		
		line = f.get_line()
	f.close()

func find_Match(line:String) -> bool:
	if line.matchn("*today*"):
		MatchCountOutput.text = str(int(MatchCountOutput.text) + 1)
		return true
	else: return false

func print_to_output(line):
	if find_Match(line):
		OutputTextBox.bbcode_text += "[color=lime]" + line + "[/color]" + "\n"
	else:
		OutputTextBox.bbcode_text += line + "\n"

#---------------------------- Buttons

func _on_Run_pressed():
	reset_Statistics()
	
	#TODO: This should be temporary and reworked later
	#This checks the input field to see if a directory or txt file is input
	if SelectionInput.text.match("*.txt"):
		inputType = INPUT_TYPES.FILE
	else:
		inputType = INPUT_TYPES.DIRECTORY
	
	match inputType:
		INPUT_TYPES.DIRECTORY:
			directory_Iterate(SelectionInput.text)
		INPUT_TYPES.FILE:
			read_File(SelectionInput.text)


func _on_Clear_pressed():
	reset_Statistics()

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
