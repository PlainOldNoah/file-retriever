extends PanelContainer


#---------------------------- NODES
onready var FileCountOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/FileCount
onready var EntryCountOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/EntryCount
onready var MatchCountOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/MatchCount
onready var ElapsedTimeOutput = $MarginContainer/GUI/LowerHalf/MiddleSide/Statistics/HBoxContainer/VBoxContainer2/ElapsedTime
onready var StatusBarOutput = $MarginContainer/GUI/Progress/VBoxContainer/StatusBar

onready var InputFileDialog = $FileDialog

onready var AppendButton = $MarginContainer/GUI/LowerHalf/RightSide/Export/VBoxContainer/HBoxContainer/Append
onready var OverwriteButton = $MarginContainer/GUI/LowerHalf/RightSide/Export/VBoxContainer/HBoxContainer/Overwrite
#============================ Functions

func _ready():
	OS.set_window_position(OS.get_screen_size()*0.5 - OS.get_window_size()*0.5)

#---------------------------- Buttons

func _on_Run_pressed():
	pass # Replace with function body.


func _on_Clear_pressed():
	pass # Replace with function body.


func _on_Quit_pressed():
	get_tree().quit()


func _on_ExportBtn_pressed():
	pass # Replace with function body.


func _on_FileSelect_pressed():
	InputFileDialog.popup_centered_ratio(0.8)


func _on_Append_pressed():
	pass


func _on_Overwrite_pressed():
	pass # Replace with function body.


func _on_WindowToggleBtn_pressed():
	pass # Replace with function body.
