extends PanelContainer

const windowSize = Vector2(700, 320)
const bigWindowSize = Vector2(700, 720)

var inputFolderFormat = "Logs - *"
var inputFileFormat = "(??) * - *"
var entryHeaderFormat = "*/*/*, *day"

enum INPUT_TYPES {DIRECTORY, FILE, FILES}
var inputType

var printEntry:bool = true
var printDate:bool = true

var searchKeyArray : PoolStringArray = [] #Holds the comma seperated search terms
var operationArray : PoolStringArray = [] #Stores the operation of each search term
var allTermsArray : PoolStringArray = [] #Stores every term, used in printing to output

var rng = RandomNumberGenerator.new()

#---------------------------- NODES
onready var SelectionInput = $MarginContainer/HBoxContainer/GUI/FileSelection/SelectionInput
onready var InputFileDialog = $SingleInputFileDialog
onready var SearchKeyInput = $MarginContainer/HBoxContainer/GUI/SearchKey/SearchKeyInput

onready var OutputFileConfirm = $OutputFileConfirmation
onready var OutputFileName = $OutputFileConfirmation/LineEdit

onready var FileCountOutput = $MarginContainer/HBoxContainer/GUI/Statistics/HBoxContainer/DataValues/FileCount
onready var EntryCountOutput = $MarginContainer/HBoxContainer/GUI/Statistics/HBoxContainer/DataValues/EntryCount
onready var MatchCountOutput = $MarginContainer/HBoxContainer/GUI/Statistics/HBoxContainer/DataValues/MatchCount
onready var ElapsedTimeOutput = $MarginContainer/HBoxContainer/GUI/Statistics/HBoxContainer/DataValues/ElapsedTime
onready var OutputWindow = $MarginContainer/HBoxContainer/OutputWindow
onready var OutputTextBox = $MarginContainer/HBoxContainer/OutputWindow/TextBox

onready var StatusBarOutput = $MarginContainer/HBoxContainer/GUI/StatusBar

onready var AppendButton = $MarginContainer/HBoxContainer/GUI/LowerControl/ExportControls/VBoxContainer/ExportModeButton/Append
onready var OverwriteButton = $MarginContainer/HBoxContainer/GUI/LowerControl/ExportControls/VBoxContainer/ExportModeButton/Overwrite

onready var printEntryButton = $MarginContainer/HBoxContainer/GUI/RunButtons/OutputButtons/PrintEntry
onready var printDateButton = $MarginContainer/HBoxContainer/GUI/RunButtons/OutputButtons/PrintDate

#---
onready var CaseSenseToggle = $MarginContainer/HBoxContainer/GUI/SearchKey/SearchKeyButtons/CaseSensitive

#============================ Functions

func _ready():
	OS.set_window_position(OS.get_screen_size()*0.5 - OS.get_window_size()*0.5)
#	reset_statistics()
	rng.randomize()

func _unhandled_input(event):
	#Removes focus from any other control node to allow ui_accept to press the 'run' button
	if event.is_action_pressed("ui_accept") and get_focus_owner() != null:
		get_focus_owner().release_focus()

func reset_statistics():
	FileCountOutput.text = "0"
	EntryCountOutput.text = "0"
	MatchCountOutput.text = "0"
	ElapsedTimeOutput.text = "0"
	StatusBarOutput.text = "Idle"
	OutputTextBox.bbcode_text = ""
#	LoadingBar.value = 0


#Recursively loops though directories and retrieves files
func directory_iterate(path):
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			#Filters out Non-Log Folders
			if dir.current_is_dir() and file_name.match(inputFolderFormat):
				directory_iterate(dir.get_current_dir() + "/" + file_name)
			#Filters out files that don't have the right naming scheme
			elif file_name.match(inputFileFormat):
				read_file(dir.get_current_dir() + "/" + file_name)
			file_name = dir.get_next()
	else:
		print_debug("ERROR: Bad Path Parameter: ", path)

func read_file(file):
	FileCountOutput.text = str(int(FileCountOutput.text) + 1)
	
	var f:File = File.new()
	var _err = f.open(file, File.READ)
	
	var line:String
	var currentHeaderPos:int = -1
	var nextHeaderPos:int = -1
	
	#Scan for the first header in the file
	while not f.eof_reached():
		line = f.get_line()
		if line.matchn(entryHeaderFormat):
			currentHeaderPos = f.get_position() - line.length() - 2
			EntryCountOutput.text = str(int(EntryCountOutput.text) + 1) #For the first header
			break
	
	#If the file doesn't have any headers or is formated wrong escape
	if currentHeaderPos == -1:
		print_debug("ERROR: Bad File Format: ", f.get_path())
		f.close()
		return
	
	#After getting header position run though each entry
	while not f.eof_reached():
		#TODO: Possible merge get_next_header with search entry to reduce entry scans
		nextHeaderPos = get_next_header(f, currentHeaderPos)
		if search_entry(f, currentHeaderPos, nextHeaderPos):
			print_to_output(f, currentHeaderPos, nextHeaderPos)
		if currentHeaderPos == nextHeaderPos:
			break
		currentHeaderPos = nextHeaderPos
	
	f.close()


#Takes in a file and the current header and then iterates though the lines until the next header is found
#Returns the next headers start position
func get_next_header(f:File, currentHeaderPos:int) -> int:
	f.seek(currentHeaderPos)
	var line:String = f.get_line()
	var currentHeaderText:String = line
	
	while not f.eof_reached():
		#Return the cursors position is the next header is found
		if line.matchn(entryHeaderFormat) and not line.match(currentHeaderText):
			EntryCountOutput.text = str(int(EntryCountOutput.text) + 1) #For all other headers
			return f.get_position() - line.length() - 2
		line = f.get_line()
	
	f.seek_end(0)
	return f.get_position()

#Runs though an entry line by line comparing it to the searchKeyArray
#Returns a bool based on the evaluation of the terms (Should the entry be printed)
func search_entry(f:File, currentHeaderPos:int, nextHeaderPos:int) -> bool:
	#Create an array to store whether or not a match has been found
	var storedMatches:Array = []
	for i in operationArray.size():
		if operationArray[i] == "NOT":
			storedMatches.append(true)
		else:
			storedMatches.append(false)
	
	var line:String
	f.seek(currentHeaderPos)
	
	#For every line check every term
	while f.get_position() < nextHeaderPos:
		line = f.get_line()

		for i in operationArray.size():
			if storedMatches[i] != true or operationArray[i] == "NOT": #Shortcircut if term has already been met
				match operationArray[i]:
					"NOT":
						if find_match(line, searchKeyArray[i]):
							storedMatches[i] = false
							return false
					"AND":
						if find_match(line, searchKeyArray[i]):
							storedMatches[i] = true
					"OR":
						var tempOrArray:Array = Array(searchKeyArray[i].split(" or ", true, 0))
						for j in tempOrArray.size():
							if find_match(line, tempOrArray[j]) and storedMatches[i] == false:
								storedMatches[i] = true
					_:
						print_debug("ERROR: Invalid Operation in operationArray")
	
	#Depending on if all terms have been met output a boolean
	for i in storedMatches.size():
		if storedMatches[i] != true:
			return false
	return true

#Compares a line of text with a keyword
#Returns bool depending on if term is contained within line
func find_match(line:String, term:String) -> bool:
	if not CaseSenseToggle.pressed:
		term = term.to_lower()
		line = line.to_lower()
	
	if term in line:
		return true
	else:
		return false

#Prints out an entry given a start and end header position
func print_to_output(f:File, currentHeaderPos:int, nextHeaderPos:int):
	
	#TODO: Use this to get the end of a file to add a new line
#	f.seek_end(0)
#	print("END: ", f.get_position())
	
	f.seek(currentHeaderPos)
	var line:String = ""
	
	while f.get_position() < nextHeaderPos:
		
		
		line = f.get_line()
		
		if printDate and not printEntry:
			if line.matchn(entryHeaderFormat):
				OutputTextBox.bbcode_text += line + "\n"
				return
		
		elif printDate and printEntry:
			for i in allTermsArray.size():
				if find_match(line, allTermsArray[i]):
					line = "[color=lime]" + line + "[/color]"
		OutputTextBox.bbcode_text += line + "\n"


#Unused
#func loop_through_entry(f:File, currentHeaderPos:int, nextHeaderPos:int):
#	f.seek(currentHeaderPos)
#	var line:String = f.get_line()
#	while f.get_position() < nextHeaderPos:
#		line = f.get_line()


#Converts the user input to a poolStringArray
func parse_search_keys():
	searchKeyArray = SearchKeyInput.text.split(",", false, 0)
	for i in searchKeyArray.size():
		searchKeyArray[i] = searchKeyArray[i].strip_edges()

#Creates the matching operationArray to the searchKeyArray
func prepare_search_terms():
	#Clears the operationArray and corrects its size
	operationArray.resize(searchKeyArray.size())
	for j in operationArray.size():
		operationArray[j] = ""
	
	#Passes in the operation of each term from the searchKeyArray into the operationArray
	for i in searchKeyArray.size():
		if "-" in searchKeyArray[i] or "NOT " in searchKeyArray[i].to_lower():
			operationArray[i] = "NOT"
			searchKeyArray[i] = searchKeyArray[i].replace("-", "")
		elif " or " in searchKeyArray[i].to_lower():
			operationArray[i] = "OR"
		else:
			operationArray[i] = "AND"
	
	sort_search_keys()
	
	#Generates the allTermsArray used in output printing
	var tempString:String = SearchKeyInput.text.replace(" or ", ",")
	tempString = tempString.replace(" ", "")
	allTermsArray = tempString.split(",", false)

#Sorts the arrays to be NOT, AND, then OR
func sort_search_keys():
	var tempSearchKeyArray:PoolStringArray = []
	var tempOperationArray:PoolStringArray = []
		
	for k in searchKeyArray.size():
		if "NOT" in operationArray[k]:
			tempSearchKeyArray.append(searchKeyArray[k])
			tempOperationArray.append(operationArray[k])
			
	for k in searchKeyArray.size():
		if "AND" in operationArray[k]:
			tempSearchKeyArray.append(searchKeyArray[k])
			tempOperationArray.append(operationArray[k])
			
	for k in searchKeyArray.size():
		if "OR" in operationArray[k]:
			tempSearchKeyArray.append(searchKeyArray[k])
			tempOperationArray.append(operationArray[k])
	
	searchKeyArray = tempSearchKeyArray
	operationArray = tempOperationArray


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


#============================ Buttons and Signals

#Major control function for running the program
func _on_Run_pressed():
	#Initializing
	reset_statistics()
	parse_search_keys()
	
	prepare_search_terms()
	
	print("STARTING...")

	StatusBarOutput.text = "Running"
	yield(get_tree().create_timer(0.02), "timeout")


#	#This checks the input field to see if a directory or txt file is input
	if SelectionInput.text.match("*.txt"):
		inputType = INPUT_TYPES.FILE
	else:
		inputType = INPUT_TYPES.DIRECTORY


	var startTime = OS.get_ticks_msec()

	match inputType:
		INPUT_TYPES.DIRECTORY:
			directory_iterate(SelectionInput.text)
		INPUT_TYPES.FILE:
			read_file(SelectionInput.text)

	ElapsedTimeOutput.text = str((OS.get_ticks_msec() - startTime) / 1000.0)

	if FileCountOutput.text == "0":
		reset_statistics()
		StatusBarOutput.text = "ERROR: Bad File Path"
	else:
		StatusBarOutput.text = "Finished"


#File/Input location selection
func _on_FileSelect_pressed():
	InputFileDialog.popup_centered_ratio(1.0)
	InputFileDialog.current_path = SelectionInput.text
	InputFileDialog.current_dir = SelectionInput.text

func _on_FilesSelect_pressed():
	pass # Replace with function body.

func _on_FromOutput_toggled(button_pressed):
	pass # Replace with function body.


#Search Key Input and Control
func _on_Search_Keys_text_changed(_new_text):
	parse_search_keys()

func _on_RandomDate_pressed():
	if not SearchKeyInput.text.empty():
		SearchKeyInput.text += ", "
	SearchKeyInput.text += generate_rand_date()
	parse_search_keys()

func _on_TodaysDate_pressed():
	pass # Replace with function body.

func _on_CaseSensitive_toggled(button_pressed):
	pass # Replace with function body.


#Control for what is output after running
func _on_PrintDate_toggled(button_pressed):
	printDate = button_pressed
#	if printDate == false:
#		printEntryButton.pressed = false

func _on_PrintEntry_toggled(button_pressed):
	printEntry = button_pressed
#	if printEntry == true:
#		printDateButton.pressed = true

func _on_PrintLine_toggled(button_pressed):
	pass # Replace with function body.


#Popup Controls
func _on_SingleInputFileDialog_dir_selected(dir):
	inputType = INPUT_TYPES.DIRECTORY
	SelectionInput.text = dir

func _on_SingleInputFileDialog_file_selected(path):
	inputType = INPUT_TYPES.FILE
	SelectionInput.text = path

func _on_OutputFileConfirmation_confirmed():

	var outputFileName:String = OutputFileName.text

	outputFileName = outputFileName\
	.replace("/", "_").replace("\\", "_").replace(":", "_")\
	.replace("*", "_").replace("?", "_").replace("\"", "_")\
	.replace("<", "_").replace(">", "_").replace("|", "_")\
	
	if outputFileName.empty():
		outputFileName = "newFile"
	
	var outputFilePath = "user://" + outputFileName + ".txt"

	var file2Check = File.new()
	var doFileExist = file2Check.file_exists(outputFilePath)
	
	var file = File.new()
	var fileStatus = 3
	if AppendButton.pressed == false or not doFileExist:
		fileStatus = 2

	file.open(outputFilePath, fileStatus)
	StatusBarOutput.text = "File Saved: " + OS.get_user_data_dir()
	file.store_string(OutputTextBox.bbcode_text)
	file2Check.close()
	file.close()


#Exporting Text to File
func _on_ExportBtn_pressed():
	OutputFileConfirm.popup()


#Terminal Buttons that reset or end the program
func _on_Help_pressed():
	pass # Replace with function body.

func _on_Clear_pressed():
	reset_statistics()

func _on_Quit_pressed():
	get_tree().quit()
