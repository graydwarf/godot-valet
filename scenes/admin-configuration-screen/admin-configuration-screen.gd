extends Control

#
# Please ignore. WIP and related to installer work. We 
#

@onready var _confirmationDialog = $ConfirmationDialog
@onready var _encryptCheckbox = $HBoxContainer/EncryptCheckBox

var _projectName
var _operatingSystem
var _version
var _dbName
var _dbPassword
var _blobStorageRoot
var _encryptionPassword
var _configTemplateFileName = "res://godot-fetch-test-template.cfg"

var _adminConfigFileName = "godot-fetch-test-admin.cfg"
var _useEncryption = false

func _ready():
	LoadAdminSettings()
	LoadConfigTemplateSettings()

func LoadAdminSettings():
	var config = ConfigFile.new()
	var err = config.load(_adminConfigFileName)
	if err == OK:
		_useEncryption = config.get_value("AdminSettings", "use_encryption", false)
		
func GenerateConfigFile():
	var config = ConfigFile.new()
	config.set_value("ProjectSettings", "project_name", _projectName)
	config.set_value("ProjectSettings", "operating_system", _operatingSystem)
	config.set_value("ProjectSettings", "version", _version)
	config.set_value("ProjectSettings", "db_name", _dbName)
	config.set_value("ProjectSettings", "db_password", _dbPassword)
	config.set_value("ProjectSettings", "blob_storage_root", _blobStorageRoot)
	
	if _encryptCheckbox.button_pressed:
		config.save_encrypted_pass("res://godot-fetch-test.cfg", _encryptionPassword)
	else:
		config.save("res://godot-fetch-test.cfg")

func LoadConfigTemplateSettings():
	var config = ConfigFile.new()
	var err = config.load(_configTemplateFileName)
	if err == OK:
		_projectName = config.get_value("ProjectSettings", "project_name", "")
		_operatingSystem = config.get_value("ProjectSettings", "operating_system", "")
		_version = config.get_value("ProjectSettings", "version", "")
		_dbName = config.get_value("ProjectSettings", "db_name", "")
		_dbPassword = config.get_value("ProjectSettings", "db_password", "")
		_blobStorageRoot = config.get_value("ProjectSettings", "blob_storage_root", "")
		_encryptionPassword = config.get_value("ProjectSettings", "encryption_password", "")

func BeginConfigTemplateCreationProcess():
	if FileAccess.file_exists(_configTemplateFileName):
		_confirmationDialog.show()
	else:
		CreateConfigTemplateFile()

func CreateConfigTemplateFile():
	var config = ConfigFile.new()
	config.set_value("ProjectSettings", "project_name", "")
	config.set_value("ProjectSettings", "operating_system", "windows")
	config.set_value("ProjectSettings", "version", "v0.0.1")
	config.set_value("ProjectSettings", "db_name", "")
	config.set_value("ProjectSettings", "db_password", "")
	config.set_value("ProjectSettings", "blob_storage_root", "")
	config.set_value("ProjectSettings", "encryption_password", "")
	config.save(_configTemplateFileName)

func CreateAdminTemplateFile():
	var config = ConfigFile.new()
	config.set_value("AdminSettings", "use_encryption", false)
	config.save(_adminConfigFileName)
	
func _on_generate_button_pressed():
	GenerateConfigFile()

func _on_confirmation_dialog_confirmed():
	CreateConfigTemplateFile()

func _on_create_config_template_button_2_pressed():
	BeginConfigTemplateCreationProcess()

func _on_create_admin_template_button_pressed():
	CreateAdminTemplateFile()

func _on_load_config_template_settings_pressed():
	LoadConfigTemplateSettings()
