@tool
extends EditorPlugin

const Exporter = preload("res://addons/runtime_assets/export_plugin.gd")
var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = Exporter.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
