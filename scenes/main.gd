extends Control

var _projectConfig = "res://configs/godot-valet.cfg"
var _adminConfig = "res://configs/godot-valet-admin.cfg"
var _useEncryption = true
var _configPass = ""

func _ready():
	InitConfigurationFolders()
	LoadAdminSettings()
	LoadProjectSettings()
	LoadTheme()
	AddProjectManagerScene()
	
	# REMOVE THIS!!!!
	#await get_tree().create_timer(0.2).timeout
	#ObfuscateHelper.Test_ExtractFunctionSymbols()
	
func AddProjectManagerScene():
	var projectManager = load("res://scenes/project-manager/project-manager.tscn").instantiate()
	add_child(projectManager)

func LoadTheme():
	theme = load(App.GetThemePath())
		
func LoadAdminSettings():
	var config = ConfigFile.new()
	var err = config.load(_adminConfig)
	if err == OK:
		_useEncryption = config.get_value("AdminSettings", "use_encryption", false)
	
func LoadProjectSettings():
	var config = ConfigFile.new()
	var err = 0
	if _useEncryption:
		err = config.load_encrypted_pass(_projectConfig, _configPass)
	else:
		err = config.load(_projectConfig)
		
	if err == OK:
		App.SetProjectName(config.get_value("ProjectSettings", "project_name", ""))
		App.SetProjectOperatingSystem(config.get_value("ProjectSettings", "operating_system", ""))
		App.SetProjectVersion(config.get_value("ProjectSettings", "version", ""))
		App.SetDbName(config.get_value("ProjectSettings", "db_name", ""))
		App.SetDbPassword(config.get_value("ProjectSettings", "db_password", ""))
		App.SetBlobStorageRoot(config.get_value("ProjectSettings", "blob_storage_root", ""))

func InitConfigurationFolders():
	DirAccess.make_dir_recursive_absolute("user://" + App.GetProjectItemFolder())
	DirAccess.make_dir_recursive_absolute("user://" + App.GetGodotVersionItemFolder())
