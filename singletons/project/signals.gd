extends Node

# Release Management
signal CreateNewProject # might be dupe/dead
signal ProjectRenamed
signal ExportWithInstaller

# Project Management
signal ProjectItemSelected
signal ProjectSaved

# Godot Version Management
signal GodotVersionsChanged
signal GodotVersionItemClicked
signal GodotVersionManagerClosing
