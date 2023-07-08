extends Node

# Release Management
signal CreateNewProject # might be dupe/dead
signal ProjectRenamed
signal ExportWithInstaller
signal SaveInstallerConfiguration

# Project Management
signal ProjectItemSelected
signal ProjectSaved
signal LoadOpenGodotButtons

# Godot Version Management
signal NewGodotVersionAdded
signal GodotVersionItemClicked
signal GodotVersionManagerClosing
signal SaveGodotVersionSettingsFile
signal MoveVersionItemUp

# Settings
signal BackgroundColorChanged
signal BackgroundColorTemporarilyChanged
