extends Node

# Release Management
signal CreateNewProject # might be dupe/dead
signal ProjectRenamed
signal ExportWithInstaller
signal SaveInstallerConfiguration

# Project Management
signal ToggleProjectItemSelection
signal ProjectSaved
signal LoadOpenGodotButtons
signal HidingProjectItem

# Godot Version Management
signal NewGodotVersionAdded
signal GodotVersionItemClicked
signal GodotVersionManagerClosing
signal SaveGodotVersionSettingsFile
signal MoveVersionItemUp

# Settings
signal BackgroundColorChanged
signal BackgroundColorTemporarilyChanged
