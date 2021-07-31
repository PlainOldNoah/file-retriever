extends PanelContainer

const windowSize = Vector2(800, 360)
const bigWindowSize = Vector2(800, 720)

var inputFolderFormat = "Logs - *"
var inputFileFormat = "(??) * - *"
var entryHeaderFormat = "*/*/*, *"

enum INPUT_TYPES {DIRECTORY, FILE, FILES}
var inputType

var printEntry:bool = false
var printDate:bool = true

var searchKeyArray : PoolStringArray = []

var rng = RandomNumberGenerator.new()

#---------------------------- NODES
onready var SelectionInput = $MarginContainer/GUI/PanelContainer/VBoxContainer/HBoxContainer/SelectionInput
onready var InputFileDialog = $SingleInputFileDialog
onready var SearchKeyInput = $MarginContainer/GUI/PanelContainer/VBoxContainer/HBoxContainer2/SearchKeyInput

onready var FileCountOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/FileCount
onready var EntryCountOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/EntryCount
onready var MatchCountOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/MatchCount
onready var ElapsedTimeOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/ElapsedTime
onready var OutputWindow = $MarginContainer/GUI/OutputWindow
onready var OutputTextBox = $MarginContainer/GUI/OutputWindow/TextBox

onready var StatusBarOutput = $MarginContainer/GUI/Progress/VBoxContainer/StatusBar
onready var LoadingBar = $MarginContainer/GUI/Progress/VBoxContainer/ProgressBar

onready var AppendButton = $MarginContainer/GUI/LowerHalf/RightSide/Export/VBoxContainer/HBoxContainer/Append
onready var OverwriteButton = $MarginContainer/GUI/LowerHalf/RightSide/Export/VBoxContainer/HBoxContainer/Overwrite
onready var printEntryButton = $MarginContainer/GUI/LowerHalf/LeftSide/OperationButtons/VBoxContainer/HBoxContainer2/PrintEntry
onready var printDateButton = $MarginContainer/GUI/LowerHalf/LeftSide/OperationButtons/VBoxContainer/HBoxContainer2/PrintDate
#============================ Functions

func _ready():
	OS.set_window_position(OS.get_screen_size()*0.5 - OS.get_window_size()*0.5)
	reset_Statistics()
	rng.randomize()

func reset_Statistics():
	FileCountOutput.text = "0"
	EntryCountOutput.text = "0"
	MatchCountOutput.text = "0"
	ElapsedTimeOutput.text = "0"
	StatusBarOutput.text = "Idle"
	OutputTextBox.bbcode_text = ""
	LoadingBar.value = 0


#Recursively loops though directories and retrieves files
func directory_Iterate(path):
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			#Filters out Non-Log Folders
			if dir.current_is_dir() and file_name.match(inputFolderFormat):
#				print("Directory: " + file_name)
				directory_Iterate(dir.get_current_dir() + "/" + file_name)
			#Filters out files that don't have the right naming scheme
			elif file_name.match(inputFileFormat):
#				print("File: " + file_name)
				read_File(dir.get_current_dir() + "/" + file_name)
			file_name = dir.get_next()
	else:
		print_debug("ERROR: Bad Path Parameter: ", path)


func read_File(file):
	FileCountOutput.text = str(int(FileCountOutput.text) + 1)
	
	#TODO
#	LoadingBar.value = ((int(FileCountOutput.text) / 55) * 100)
	
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
					MatchCountOutput.text = str(int(MatchCountOutput.text) + 1)
					line = f.get_line()
					
					while not line.strip_escapes().empty():
						print_to_output(line)
						line = f.get_line()
					OutputTextBox.bbcode_text += "\n"
					
				else: line = f.get_line()
		
		line = f.get_line()
	f.close()


func find_Match(line:String) -> bool:
	for i in searchKeyArray.size():
		if searchKeyArray[i].to_lower() in line.to_lower():
			return true
	return false


func print_to_output(line):
	if printDate and not printEntry:
		if line.matchn(entryHeaderFormat):
			OutputTextBox.bbcode_text += line
	elif printDate and printEntry:
		if find_Match(line):
			OutputTextBox.bbcode_text += "[color=lime]" + line + "[/color]" + "\n"
		else:
			OutputTextBox.bbcode_text += line + "\n"
	else:
		return


func generate_rand_date() -> String:
	var date = OS.get_date()
	var year = rng.randi_range(2017, date.year)
	var month = 01
	var day = 1
	
	if year != date.year:
		month = rng.randi_range(1, 12)
	else:
		month = rng.randi_range(1, date.month)
	
	var maxDay = 31
	if year == date.year and month == date.month:
		maxDay = date.day
	elif month == 2:
		if year % 4 == 0:
			maxDay = 29
		else:
			maxDay = 28
	elif month == 4 or month == 6 or month == 9 or month == 11:
		maxDay = 30
	day = rng.randi_range(1, maxDay)
	
	year = str(year)
	year.erase(0, 2)
	
	var output = str(month) + "/" + str(day) + "/" + year
	return output

#---------------------------- Buttons

func _on_Run_pressed():
	reset_Statistics()
	parse_Search_Keys()
	#TODO: This should be temporary and reworked later
	#This checks the input field to see if a directory or txt file is input
	if SelectionInput.text.match("*.txt"):
		inputType = INPUT_TYPES.FILE
	else:
		inputType = INPUT_TYPES.DIRECTORY
	
	StatusBarOutput.text = "Running"
	var starTime = OS.get_ticks_msec()
	
	match inputType:
		INPUT_TYPES.DIRECTORY:
			directory_Iterate(SelectionInput.text)
		INPUT_TYPES.FILE:
			read_File(SelectionInput.text)
	ElapsedTimeOutput.text = str((OS.get_ticks_msec() - starTime) / 1000.0)
	StatusBarOutput.text = "Finished"


func _on_Clear_pressed():
	reset_Statistics()

func _on_Quit_pressed():
	get_tree().quit()


func _on_Search_Keys_text_changed(_new_text):
	parse_Search_Keys()

func parse_Search_Keys():
	searchKeyArray = SearchKeyInput.text.split(",", true, 0)
	for i in searchKeyArray.size():
		searchKeyArray[i] = searchKeyArray[i].strip_edges()

func _on_ExportBtn_pressed():
	pass # Replace with function body.


func _on_FileSelect_pressed():
	InputFileDialog.popup_centered_ratio(1.0)
	InputFileDialog.current_path = SelectionInput.text
	InputFileDialog.current_dir = SelectionInput.text

func _on_Append_pressed():
	if AppendButton.pressed == true:
		OverwriteButton.pressed = false

func _on_Overwrite_pressed():
	if OverwriteButton.pressed == true:
		AppendButton.pressed = false


func _on_WindowToggleBtn_toggled(button_pressed):
	OutputWindow.visible = button_pressed
	if button_pressed:
		OS.min_window_size = bigWindowSize
		OS.window_size.y = bigWindowSize.y
	if not button_pressed:
		OS.min_window_size = windowSize
		OS.window_size.y = windowSize.y

#File Input
func _on_SingleInputFileDialog_dir_selected(dir):
	inputType = INPUT_TYPES.DIRECTORY
	SelectionInput.text = dir

func _on_SingleInputFileDialog_file_selected(path):
	inputType = INPUT_TYPES.FILE
	SelectionInput.text = path

#Can only print entries if the date is printed as well.
func _on_PrintDate_toggled(button_pressed):
	printDate = button_pressed
	if printDate == false:
		printEntryButton.pressed = false

func _on_PrintEntry_toggled(button_pressed):
	printEntry = button_pressed
	if printEntry == true:
		printDateButton.pressed = true


func _on_RandomDate_pressed():
	SearchKeyInput.text = generate_rand_date()
