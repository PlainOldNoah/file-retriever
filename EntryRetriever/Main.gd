extends PanelContainer

#String formatting for consistancy
const inputFolderFormat = "Logs - *"
const inputFileFormat = "(??) * - *"
const entryHeaderFormat = "*/*/*, *day"
const startingDate = {"year":2017, "month":1, "day":1,}
const defaultFilePath = "/Users/Noah/Library/Entires/"

#Variables for file/entry searching and printing
var currentHeaderText:String = ""
var line:String = "" setget set_line
var currentHeaderPos:int = -1 #f.position of beginning of current header
var nextHeaderPos:int = -1    #f.position of the next header OR f.seek_end(0) position
var endOfFilePos:int = -1     #f.seek_end(0)

#Search key arrays for searching and printing
var searchKeyArray : PoolStringArray = [] #Holds the comma seperated search terms
var operationArray : PoolStringArray = [] #Stores the operation of each search term
var allTermsArray : PoolStringArray = [] #Stores every term, used in printing to output

#Misc variables
var estimatedTotalDays: int = 0
var currentFileSize:int = 0 #Total bytes to scan though
var totalFileSize:int = 0   #Bytes scanned during read

var inputPath:PoolStringArray = [] #Files and directorys stored here for later searching

enum printOptions {FULL, DATE, MATCHEDLINE, NONE}
export (printOptions) var printOption = printOptions.NONE

var rng = RandomNumberGenerator.new()

#---------------------------- NODES
onready var PopupParent =       $PopupParent
onready var HelpPopup =         $PopupParent/HelpPopup
onready var InputFileDialog =   $PopupParent/InputFileDialog
onready var OutputFileConfirm = $PopupParent/OutputFileConfirmation
onready var OutputFileName =    OutputFileConfirm.get_node("LineEdit")
onready var WarningPopup =      $PopupParent/WarningPopup
onready var WarningConfirm =    WarningPopup.get_node("HBoxContainer/WarningConfim")
onready var WarningAbort =      WarningPopup.get_node("HBoxContainer/WarningAbort")

onready var OutputWindow =      $MarginContainer/HBoxContainer/OutputWindow
onready var OutputTextBox =     OutputWindow.get_node("TextBox")

onready var Gui =               $MarginContainer/HBoxContainer/GUI

onready var StatusBar =         Gui.get_node("StatusBar")
onready var SearchKeyInput =    Gui.get_node("SearchKey/SearchKeyInput")
onready var SelectionInput =    Gui.get_node("FileSelection/SelectionInput")
onready var CaseSenseToggle =   Gui.get_node("SearchKey/SearchKeyButtons/CaseSensitive")
onready var AppendButton =      Gui.get_node("TabContainer/Export/ExportModeButton/Append")

onready var Tab_Container =     Gui.get_node("TabContainer")
onready var Statistics =        Tab_Container.get_node("Statistics")
onready var FileCountOutput =   Statistics.get_node("LeftData/TotalFiles/FileCount")
onready var EntryCountOutput =  Statistics.get_node("LeftData/TotalEntries/EntryCount")
onready var ElapsedTimeOutput = Statistics.get_node("LeftData/SearchTime/ElapsedTime")
onready var MatchCountOutput =  Statistics.get_node("RightData/RetrievedEntires/MatchCount")
onready var BytesCountOutput =  Statistics.get_node("RightData/TotalBytes/BytesCount")

onready var KeywordHistory =    Tab_Container.get_node("History/TextEdit")

#============================ Functions
#---------------------------- GODOT FUNCS
func _ready():
	OS.set_window_position(OS.get_screen_size()*0.5 - OS.get_window_size()*0.5)
	rng.randomize()
	inputPath.append(SelectionInput.text)
	set_selection_input()
	reset_statistics()

func _unhandled_input(event):
	#Removes focus from any other control node to allow ui_accept to press the 'run' button
	if event.is_action_pressed("ui_accept") and get_focus_owner() != null:
		get_focus_owner().release_focus()

#---------------------------- CORE FEATURE FUNCS

#First half of runner, initializes 'things' and gets bytes
func run_program_start():
	#Initializing
	reset_statistics()
	parse_search_keys()
	prepare_search_terms()
	set_selection_input() #Even if fileInput is cleared, there are still directorys saved
	
	store_keyword_history()
	
	print("\nStarting...")
	
	set_status_bar("Initializing")
	yield(get_tree(), "idle_frame")
	
	#Get total file size before seaching
	for i in inputPath.size():
		if inputPath[i].match("*.txt"):
			totalFileSize += get_file_size(inputPath[i])
		else:
			dir_contents(inputPath[i], "FileSize")
	
	BytesCountOutput.text = str(totalFileSize)
	
	#WARNING GOES HERE
	if not warning(totalFileSize):
		run_program_continue()

#Compares input bytes to print mode to determine if program is too long
#RETURN: bool of if warning is needed or not
func warning(size:int) -> bool:
	var dangerousSize:int = 0
	
	#Tests show that None and Date remain inexpensive and quick to use
	#Line and full remain shorter on a blank input and get more expensive the more keys are used
	
	match printOption:
		printOptions.FULL:
			if searchKeyArray.size() == 0:
				dangerousSize = 300000
			else:
				dangerousSize = 100000
		printOptions.MATCHEDLINE:
			if searchKeyArray.size() == 0:
				dangerousSize = 30000000
			else:
				dangerousSize = 10000000
		printOptions.DATE:
			dangerousSize = 11000000
		printOptions.NONE:
			dangerousSize = 60000000
	
	if size > dangerousSize:
		WarningPopup.popup_centered()
		set_status_bar("WARNING")
		return true
	return false

#Second half of runner, actually does the search
#Needed because of warning
func run_program_continue():
	set_status_bar("Running")
	yield(get_tree(), "idle_frame")
	
	var startTime = OS.get_ticks_msec()
	
	#Scan through Files
	for i in inputPath.size():
		if inputPath[i].match("*.txt"):
			read_file(inputPath[i])
		else:
			dir_contents(inputPath[i], "FileSearch")
	
	ElapsedTimeOutput.text = str((OS.get_ticks_msec() - startTime) / 1000.0)

	if FileCountOutput.text == "0":
#		reset_statistics()
		set_status_bar("ERROR: Bad File Path")
	else:
		set_status_bar("Finished")

#---------------------------- FILE READ/SEARCH/OUTPUT

#Recursively loops though directories and retrieves files
#Path:File path to directory to search
#Mode:"FileSearch" to scan though files or "FileSize" to get total file sizes
func dir_contents(path:String, mode:String):
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			#Filters out Non-Log Folders
			if dir.current_is_dir() and file_name.match(inputFolderFormat):
				dir_contents(dir.get_current_dir() + "/" + file_name, mode)
			#Filters out files that don't have the right naming scheme
			elif file_name.match(inputFileFormat):
				match mode:
					"FileSize":
						totalFileSize += get_file_size(dir.get_current_dir() + "/" + file_name)
					"FileSearch":
						read_file(dir.get_current_dir() + "/" + file_name) #Read the File
			file_name = dir.get_next()
	else:
		print_debug("ERROR: Bad Path Parameter: ", path)

#Main control func for opening files and reading entires
#Reads line by line and funs various functions to see if entires should be printed
func read_file(file):
	FileCountOutput.text = str(int(FileCountOutput.text) + 1)
	
	var f:File = File.new()
	var _err = f.open(file, File.READ)
	
	initialize_file_scan(f)
	
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
	
	currentFileSize += f.get_len()
	
	f.close()

#Gets the position of the End of the File, The First Header, The Second Header (If it exists)
func initialize_file_scan(f:File):
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
	
	while not f.eof_reached():
		set_line(f.get_line())
		
		if line.matchn(entryHeaderFormat) and currentHeaderText.empty():
			currentHeaderText = line
			currentHeaderPos = f.get_position() - line.length() - 2
			#Scan for the second Header in the File
			return
	
	#If there is no Next Header then set it to the end of the file
	currentHeaderPos = -1
	return

#Runs though an entry line by line comparing it to the searchKeyArray
#RETURN: a bool based on the evaluation of the terms (Are all search terms true)
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
	
	f.seek(currentHeaderPos)
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
		
		if f.eof_reached():
			nextHeaderFound = true
		
		set_line(f.get_line())
		
		#If the next header, or end of file, is found stop the loop
		if (line.matchn(entryHeaderFormat) and not line.match(currentHeaderText)):# or f.eof_reached():
			nextHeaderFound = true
	
	#Depending on if all terms have been met output a boolean
	for i in storedMatches.size():
		if storedMatches[i] != true:
			return false
	return true

#Scan though the rest of the file to find the next header
func continue_to_next_header(f:File):
	while not f.eof_reached():
		#Return the cursors position is the next header is found
		if line.matchn(entryHeaderFormat) and not line.match(currentHeaderText):
			nextHeaderPos = f.get_position() - line.length() - 2
			return
		
		set_line(f.get_line())
	
	#If all else fails just return the end of file position
	nextHeaderPos = endOfFilePos
	return

#Compares a line of text with a keyword
#RETURN: bool depending on if term is contained within line
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
	
	f.seek(currentHeaderPos)
	
	while f.get_position() < nextHeaderPos:
		
		
		set_line(f.get_line())
		
		match get_print_option():
			0: #Full
				for i in allTermsArray.size():
					if find_match(line, allTermsArray[i]):
						#TODO: Depending on operator change color
						line = "[color=lime]" + line + "[/color]"
				OutputTextBox.bbcode_text += line + "\n"
				
				#This adds a blank line between files if there wasn't one
				if f.get_position() >= endOfFilePos and line != "":
					OutputTextBox.bbcode_text += "\n"
			
			1: #Date
				if line.matchn(entryHeaderFormat):
					OutputTextBox.bbcode_text += line + "\n"
					return
				
			2: #Matched Line
				for i in allTermsArray.size():
					if line.matchn(entryHeaderFormat):
						if not OutputTextBox.text.empty():
							line = "\n" + line
						OutputTextBox.bbcode_text += line + "\n"
						break
					elif find_match(line, allTermsArray[i]):
						OutputTextBox.bbcode_text += line + "\n"
						break
				
			3: #None
				return

#---------------------------- SEACH TERM FUNCS

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
		if "-" in searchKeyArray[i]:# or "NOT " in searchKeyArray[i].to_lower():
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

#---------------------------- MISC FUNCS
#Summation of all files that need to be searched though
#RETURN: the size of the file
func get_file_size(file) -> int:
	var f:File = File.new()
	var _err = f.open(file, File.READ)
	var tempFileSize = f.get_len()
	f.close()
	return tempFileSize

#Gets the percent of current files over total files as a percent
#RETURN: percentage of current bytes over total
func progress_update() -> int:
	var progress = int((float(currentFileSize) / totalFileSize) * 100.0)
	return progress

#Makes sure the fileInputBox and fileDialog are in sync
func set_selection_input():
	#Get the number of directories and files from the input buffer
	var txtInCount: int = 0
	var dirInCount: int = 0
	
	for i in inputPath.size():
		if ".txt" in inputPath[i]:
			txtInCount += 1
		else:
			dirInCount += 1
	
	#Set the input bar to show meaningful information based on what is to be searched though
	if inputPath.size() == 1:
		SelectionInput.text = inputPath[0]
	else:
		sort_selection_input()
		SelectionInput.text = str(dirInCount) + " Dirs, " + str(txtInCount) + " Files: "
		
		for i in inputPath.size():
			SelectionInput.text += inputPath[i].right(inputPath[i].rfindn("/", -1) + 1) + ", "
	
	InputFileDialog.current_dir = inputPath[inputPath.size() - 1]
	InputFileDialog.current_path = inputPath[inputPath.size() - 1]

#Converts inputPath PoolStringArray into an array to sort and then convert it back
func sort_selection_input():
	var tempArray:Array = inputPath
	tempArray.sort()
	inputPath = tempArray

#Resets output/search data
func reset_statistics():
	FileCountOutput.text = "0"
	EntryCountOutput.text = "0"
	MatchCountOutput.text = "0"
	ElapsedTimeOutput.text = "0"
	set_status_bar("Idle")
	OutputTextBox.bbcode_text = ""
	currentFileSize = 0
	totalFileSize = 0

#Finds the number of days since 1/1/2017 and selects a random date
#Then reverse engineer that value into a date:string that is returned
#RETURN: A random date
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

func store_keyword_history():
	if KeywordHistory.get_line(0) != SearchKeyInput.text and not SearchKeyInput.text.empty():
		KeywordHistory.cursor_set_line(0)
		KeywordHistory.insert_text_at_cursor(SearchKeyInput.text + "\n")

#============================ Getters and Setters

func set_status_bar(new_text:String):
	StatusBar.text = new_text

func set_line(value):
	line = value
#	print(line)

func get_print_option() -> int:
	return(printOption)

#============================ Buttons and Signals

#Starts the program
func _on_Run_pressed():
	run_program_start()

#File and Input Controls
#Reusing File Dialog Popup
func _on_DirectorySelect_pressed():
	InputFileDialog.mode = FileDialog.MODE_OPEN_DIR
	InputFileDialog.window_title = "Select a Directory"
	InputFileDialog.invalidate()
	InputFileDialog.popup_centered()

func _on_FilesSelect_pressed():
	InputFileDialog.mode = FileDialog.MODE_OPEN_FILES
	InputFileDialog.window_title = "Select File(s)"
	InputFileDialog.invalidate()
	InputFileDialog.popup_centered()

#File Dialog Popup
func _on_InputFileDialog_dir_selected(dir):
	if not Input.is_key_pressed(KEY_SHIFT):
		inputPath.resize(0)
	inputPath.append(dir)
	set_selection_input()

func _on_InputFileDialog_files_selected(paths):
	if not Input.is_key_pressed(KEY_SHIFT):
		inputPath.resize(0)
	inputPath.append_array(paths)
	set_selection_input()


func _on_FromOutput_toggled(button_pressed):
		print("Not Connected")


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

func _on_PrintNone_pressed():
	printOption = printOptions.NONE


#Control for Warning Popup, Stops on abort, continues on continue
func _on_WarningConfim_pressed():
	WarningPopup.hide()
	yield(get_tree(), "idle_frame")
	run_program_continue()
	
func _on_WarningAbort_pressed():
	WarningPopup.hide()
	set_status_bar("Search Aborted")


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
	set_status_bar("File Saved: " + OS.get_user_data_dir())
	file.store_string(OutputTextBox.bbcode_text)
	file2Check.close()
	file.close()

#Exporting Text to File
func _on_ExportBtn_pressed():
	OutputFileConfirm.popup_centered()


#Terminal Buttons that reset or end the program
func _on_Help_pressed():
	HelpPopup.popup_centered()

func _on_Clear_pressed():
	if Input.is_key_pressed(KEY_SHIFT):
		var _err = get_tree().reload_current_scene()
	else:
		reset_statistics()

func _on_Quit_pressed():
	get_tree().quit()

#Universal signal to handle popup background darken effect
func _on_Popup_about_to_show():
	$ScreenEffects/ColorRect.color = Color(0, 0, 0, 0.5)

func _on_Popup_popup_hide():
	$ScreenEffects/ColorRect.color = Color(0, 0, 0, 0)
