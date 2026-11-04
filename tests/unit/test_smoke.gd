extends TestCase


func test_project_name_is_set() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Legend of Kitsune")


func test_portrait_viewport() -> void:
	var w: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var h: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_gt(h, w, "game must be portrait")
