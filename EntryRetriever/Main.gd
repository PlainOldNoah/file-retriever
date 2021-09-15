extends PanelContainer

var inputFolderFormat = "Logs - *"
var inputFileFormat = "(??) * - *"
var entryHeaderFormat = "*/*/*, *day"
var startingDate = {"year":2017, "month":1, "day":1,}

enum INPUT_TYPES {DIRECTORY, FILE, FILES}
var inputType

var currentHeaderText:String = ""
var line:String = "" setget set_line
var currentHeaderPos:int = -1 #f.position of beginning of current header
var nextHeaderPos:int = -1    #f.position of the next header OR f.seek_end(0) position
var endOfFilePos:int = -1     #f.seek_end(0)

var searchKeyArray : PoolStringArray = [] #Holds the comma seperated search terms
var operationArray : PoolStringArray = [] #Stores the operation of each search term
var allTermsArray : PoolStringArray = [] #Stores every term, used in printing to output

enum printOptions {FULL, DATE, MATCHEDLINE}
export (printOptions) var printOption = printOptions.FULL

var estimatedTotalDays: int = 0

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

onready var CaseSenseToggle = $MarginContainer/HBoxContainer/GUI/SearchKey/SearchKeyButtons/CaseSensitive

#============================ Functions

func _ready():
	OS.set_window_position(OS.get_screen_size()*0.5 - OS.get_window_size()*0.5)
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

#Main control func for opening files and reading entires
#Reads line by line and funs various functions to see if entires should be printed
func read_file(file):
	FileCountOutput.text = str(int(FileCountOutput.text) + 1)
	
	var f:File = File.new()
	var _err = f.open(file, File.READ)
	
	initialize_file_read(f)
	
	#If the file doesn't have any headers or is formated wrong escape
	if currentHeaderPos == -1:
		print_debug("ERROR: Bad File Format: ", f.get_path())
		f.close()
		return
	
	#Main loop for reading entries
	while not f.eof_reached() and nextHeaderPos != endOfFilePos:
		if search_entry(f):
			continue_to_next_header(f)
			print_to_output(f)
		else:
			continue_to_next_header(f)
			
		currentHeaderPos = nextHeaderPos
		currentHeaderText = line
		
	f.close()

#Gets the position of the End of the File, The First Header, The Second Header (If it exists)
func initialize_file_read(f:File):
	#Reset positions and lines of text
	currentHeaderText = ""
	line = ""
	currentHeaderPos = -1
	nextHeaderPos = -1
	endOfFilePos = -1
	
	#Get the final position of the file
	f.seek_end(0)
	endOfFilePos = f.get_position()
	f.seek(0)
	
#	#Get the first and second header positions
#	while not f.eof_reached():
#		line = f.get_line()
#		if line.matchn(entryHeaderFormat):
#			#Scan for the First Header in the File
#			if currentHeaderText.empty():
#				currentHeaderText = line
#				currentHeaderPos = f.get_position() - line.length() - 2
#			#Scan for the second Header in the File
#			else:
#				nextHeaderPos = f.get_position() - line.length() - 2
#				return
				
	while not f.eof_reached():
#		line = f.get_line()
		print("Init")
		set_line(f.get_line())
		
		if line.matchn(entryHeaderFormat) and currentHeaderText.empty():
			currentHeaderText = line
			currentHeaderPos = f.get_position() - line.length() - 2
			#Scan for the second Header in the File
			return
	
	#If there is no Next Header then set it to the end of the file
	currentHeaderPos = -1
	return

#Goes from the next header position
func continue_to_next_header(f:File):
#	print("FIRST: ", currentHeaderPos, " | CURR: ", f.get_position(), " | NEXT: ", nextHeaderPos)

	#Scan though the rest of the file to find the next header
	while not f.eof_reached():
#	while not f.eof_reached():
		#Return the cursors position is the next header is found
		if line.matchn(entryHeaderFormat) and not line.match(currentHeaderText):
			nextHeaderPos = f.get_position() - line.length() - 2
			return
		
		print("cont to header")
		set_line(f.get_line())
#		line = f.get_line()
	
	#If all else fails just return the end of file position
	nextHeaderPos = endOfFilePos
	return


#--------------Version 2

#	print("FIRST: ", currentHeaderPos, " | CURR: ", f.get_position(), " | NEXT: ", nextHeaderPos)
##	f.seek(nextHeaderPos)
#	line = f.get_line()
#	currentHeaderPos = nextHeaderPos
#	currentHeaderText = line
#
#	#Scan though the rest of the file to find the next header
#	while f.get_position() < endOfFilePos:
#		#Return the cursors position is the next header is found
#		if line.matchn(entryHeaderFormat) and not line.match(currentHeaderText):
#			nextHeaderPos = f.get_position() - line.length() - 2
#			return
#		line = f.get_line()
#
#	#If all else fails just return the end of file position
#	nextHeaderPos = endOfFilePos
#	return

#-------------- Version 1

#Takes in a file and the current header and then iterates though the lines until the next header is found
#Returns the next headers start position
#func OLD_get_next_header(f:File, currentHeaderPos:int) -> int:
#	f.seek(currentHeaderPos)
#	var line:String = f.get_line()
#	currentHeaderText = line
#
#	while not f.eof_reached():
#		#Return the cursors position is the next header is found
#		if line.matchn(entryHeaderFormat) and not line.match(currentHeaderText):
#			EntryCountOutput.text = str(int(EntryCountOutput.text) + 1) #For all other headers
#			return f.get_position() - line.length() - 2
#		line = f.get_line()
#
#	f.seek_end(0)
#	return f.get_position()

#Runs though an entry line by line comparing it to the searchKeyArray
#Returns a bool based on the evaluation of the terms (Are all search terms true)
func search_entry(f:File) -> bool:
	EntryCountOutput.text = str(int(EntryCountOutput.text) + 1)
	
	var nextHeaderFound = false
	
	#Create an array to store whether or not a match has been found
	var storedMatches:Array = []
	for i in operationArray.size():
		if operationArray[i] == "NOT":
			storedMatches.append(true)
		else:
			storedMatches.append(false)
	
#	var line:String
	f.seek(currentHeaderPos)
#	line = f.get_line()
	set_line("Search Start")
	set_line(f.get_line())
	
	#For every line check every term
	while nextHeaderFound == false:
		
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
		
#		line = f.get_line()
		print("Search Loop")
		set_line(f.get_line())
		
		#If the next header, or end of file, is found stop the loop
		if (line.matchn(entryHeaderFormat) and not line.match(currentHeaderText)) or f.eof_reached():
			nextHeaderFound = true
	
	#Depending on if all terms have been met output a boolean
	for i in storedMatches.size():
		if storedMatches[i] != true:
			return false
	return true

#Compares a line of text with a keyword
#Returns bool depending on if term is contained within line
func find_match(lineToCheck:String, term:String) -> bool:
	if not CaseSenseToggle.pressed:
		term = term.to_lower()
		lineToCheck = lineToCheck.to_lower()
	
	if term in lineToCheck:
		return true
	else:
		return false

#Prints out an entry given a start and end header position
func print_to_output(f:File):
	MatchCountOutput.text = str(int(MatchCountOutput.text) + 1)
	
#	TODO: Use this to get the end of a file to add a new line
#	f.seek_end(0)
#	print("END: ", f.get_position())
	
	f.seek(currentHeaderPos)
#	var line:String = ""
	
	while f.get_position() < nextHeaderPos:
		
#		line = f.get_line()
		print("output")
		set_line(f.get_line())
		
		match get_print_option():
			0: #Full
				for i in allTermsArray.size():
					if find_match(line, allTermsArray[i]):
						line = "[color=lime]" + line + "[/color]"
				OutputTextBox.bbcode_text += line + "\n"
			
			1: #Date
				if line.matchn(entryHeaderFormat):
					OutputTextBox.bbcode_text += line + "\n"
					return
				
			2: #Matched Line
				for i in allTermsArray.size():
					if line.matchn(entryHeaderFormat):
						if OutputTextBox.bbcode_text.empty():
							OutputTextBox.bbcode_text += line + "\n"
						else:
							OutputTextBox.bbcode_text += "\n" + line + "\n"
							
					elif find_match(line, allTermsArray[i]):
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


#Finds the number of days since 1/1/2017 and selects a random date
#Then reverse engineer that value into a date:string that is returned
func generate_rand_date() -> String:
	var currentDate:Dictionary = OS.get_date()
	var yearLength:float = 365.25
	var monthLength:float = 30.4375
	
	#Estimating number of days since 1/1/2017
	if estimatedTotalDays == 0: #Determine about how many days have passed since the startingDate
		var tempSum:float = (currentDate.year - startingDate.year) * yearLength #year:days
		tempSum += (currentDate.month - startingDate.month) * monthLength       #month:days
		tempSum += currentDate.day
# warning-ignore:narrowing_conversion
		estimatedTotalDays = floor(tempSum)
	
	#Generating Random Date
	var randomNumber = rng.randi_range(0, estimatedTotalDays)
	var randomDate = {"year": 0, "month": 0, "day":0}
	
	randomDate.year = floor(randomNumber / yearLength)
	randomNumber -= randomDate.year * yearLength
	
	randomDate.month = round(randomNumber / monthLength)
	randomDate.day = round(fmod(randomNumber, monthLength))
	
	#Cleaning Values
	randomDate.year += 17 #Instead of adding 2017 and removing the 20, just add 17
	randomDate.day = max(randomDate.day, 1)
	randomDate.month = max(randomDate.month, 1)
	
	#Returning
	var output = str(randomDate.month) + "/" + str(randomDate.day) + "/" + str(randomDate.year)
	return output

#============================ Getters and Setters

func set_line(value):
	line = value
	print(line)

func get_print_option() -> int:
	return(printOption)

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


	#This checks the input field to see if a directory or txt file is input
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
	SearchKeyInput.text = generate_rand_date()
	parse_search_keys()

#Gets the current date and puts it into the search key input
func _on_TodaysDate_pressed():
	var date = OS.get_date()
	var searchDate = str(date.month) + "/" + str(date.day) + "/"
	SearchKeyInput.text = searchDate
	
	#If shift is held down, add exclusion dates which narrow results and increase seach time
	if Input.is_key_pressed(KEY_SHIFT):
		for i in (date.year - startingDate.year + 1):
			var year = str(startingDate.year + i)
			
			SearchKeyInput.text += ", "
			SearchKeyInput.text += "-" + str(date.month) + "/" + str(date.day) + "/" + year
			
	parse_search_keys()


#Buttons for controlling what to send to output window
func _on_PrintEntry_pressed():
	printOption = printOptions.FULL

func _on_PrintDate_pressed():
	printOption = printOptions.DATE

func _on_PrintLine_pressed():
	printOption = printOptions.MATCHEDLINE


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
	if Input.is_key_pressed(KEY_SHIFT):
		var _err = get_tree().reload_current_scene()
	else:
		reset_statistics()

func _on_Quit_pressed():
	get_tree().quit()
