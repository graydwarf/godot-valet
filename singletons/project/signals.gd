extends Node

# Release Management
signal CreateNewProject # might be dupe/dead
signal ProjectRenamed
signal ExportWithInstaller
signal SaveInstallerConfiguration

# Project Management
signal ProjectItemSelected
signal ProjectSaved

# Godot Version Management
signal GodotVersionsChanged
signal GodotVersionItemClicked
signal GodotVersionManagerClosing

# Settings
signal BackgroundColorChanged
signal BackgroundColorTemporarilyChanged
