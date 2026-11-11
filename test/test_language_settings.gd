extends GutTest

const PATH := "user://test_language_settings_isolated.cfg"
var old_path: String
var old_code: String
var old_forced: String
var had_forced: bool

func before_each() -> void:
	old_path=Lang.settings_path;old_code=Lang.code
	had_forced=OS.has_environment("LANG_CODE");old_forced=OS.get_environment("LANG_CODE")
	OS.unset_environment("LANG_CODE")
	Lang.settings_path=PATH
	_clean()

func after_each() -> void:
	_clean()
	Lang.settings_path=old_path;Lang.set_code(old_code,false)
	if had_forced:OS.set_environment("LANG_CODE",old_forced)
	else:OS.unset_environment("LANG_CODE")

func _clean() -> void:
	if FileAccess.file_exists(PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func test_existing_manual_language_survives_without_old_default_tag() -> void:
	var config:=ConfigFile.new()
	config.set_value("lang","code","en")
	config.set_value("view","size",2)
	config.save(PATH)
	Lang.load_saved()
	assert_eq(Lang.code,"en","A saved choice must not be replaced by an old default migration")
	var loaded:=ConfigFile.new();loaded.load(PATH)
	assert_eq(loaded.get_value("lang","code"),"en")
	assert_eq(loaded.get_value("view","size"),2)

func test_first_run_uses_korean_device_language_and_regional_variants() -> void:
	for locale in ["ko","ko_KR","ko-KR","KO_kr","ko_KR.UTF-8"]:
		Lang.load_saved(locale)
		assert_eq(Lang.code,"ko",locale)
	assert_false(FileAccess.file_exists(PATH),"Automatic detection does not save a manual preference")

func test_english_and_unsupported_device_languages_fall_back_to_english() -> void:
	for locale in ["en","en_US","en-GB","ja_JP","fr_CA","zh_Hant_TW","unknown"]:
		Lang.load_saved(locale)
		assert_eq(Lang.code,"en",locale)
	assert_eq(Lang.language_for_locale(""),"en","Missing device language has a supported fallback")

func test_automatic_language_follows_device_changes_without_overwriting_other_settings() -> void:
	var config:=ConfigFile.new();config.set_value("view","size",2);config.save(PATH)
	var before:=FileAccess.get_file_as_string(PATH)
	Lang.load_saved("ko_KR");assert_eq(Lang.code,"ko")
	Lang.load_saved("en_GB");assert_eq(Lang.code,"en")
	assert_eq(FileAccess.get_file_as_string(PATH),before,"A device default is not a manual setting")

func test_manual_language_overrides_device_and_survives_restart() -> void:
	Lang.load_saved("ko_KR")
	Lang.set_code("en")
	Lang.code="ko" # A fresh session must read the saved choice.
	Lang.load_saved("ko_KR")
	assert_eq(Lang.code,"en")
	Lang.set_code("ko")
	Lang.code="en"
	Lang.load_saved("en_US")
	assert_eq(Lang.code,"ko")
	var config:=ConfigFile.new();config.load(PATH)
	assert_eq(config.get_value("lang","code"),"ko")

func test_old_saved_language_is_respected_even_when_default_tag_is_stale() -> void:
	var config:=ConfigFile.new();config.set_value("lang","code","en")
	config.set_value("lang","default_tag","old-default");config.save(PATH)
	var before:=FileAccess.get_file_as_string(PATH)
	Lang.load_saved("ko_KR")
	assert_eq(Lang.code,"en")
	assert_eq(FileAccess.get_file_as_string(PATH),before)

func test_invalid_saved_language_uses_device_without_rewriting_the_file() -> void:
	var config:=ConfigFile.new();config.set_value("lang","code","fr");config.save(PATH)
	var before:=FileAccess.get_file_as_string(PATH)
	Lang.load_saved("ko_KR");assert_eq(Lang.code,"ko")
	Lang.load_saved("en_US");assert_eq(Lang.code,"en")
	assert_eq(FileAccess.get_file_as_string(PATH),before)

func test_forced_test_language_has_priority_without_changing_saved_preference() -> void:
	Lang.set_code("ko")
	var before:=FileAccess.get_file_as_string(PATH)
	OS.set_environment("LANG_CODE","en")
	Lang.load_saved("ko_KR")
	assert_eq(Lang.code,"en")
	assert_eq(FileAccess.get_file_as_string(PATH),before)
	OS.set_environment("LANG_CODE","invalid")
	Lang.load_saved("en_US")
	assert_eq(Lang.code,"ko","An unsupported override must not hide a valid manual preference")

func test_manual_toggle_persists_but_nonpersistent_switch_does_not() -> void:
	Lang.load_saved("ko_KR")
	Lang.toggle()
	assert_eq(Lang.code,"en")
	Lang.load_saved("ko_KR");assert_eq(Lang.code,"en")
	var before:=FileAccess.get_file_as_string(PATH)
	Lang.set_code("ko",false)
	assert_eq(FileAccess.get_file_as_string(PATH),before)
	Lang.load_saved("ko_KR");assert_eq(Lang.code,"en")

func test_missing_override_reads_the_real_device_language() -> void:
	Lang.load_saved()
	match OS.get_locale_language():
		"ko":assert_eq(Lang.code,"ko")
		_:assert_eq(Lang.code,"en")
	assert_false(FileAccess.file_exists(PATH))
