extends SceneTree
## Renders a scene and saves a PNG (needs a display; use xvfb-run on Linux CI).
##   xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 \
##     --resolution 540x960 --script res://tools/screenshot.gd -- --scene=res://src/ui/boot/boot.tscn --out=/tmp/shot.png
## Optional: --frames=N (default 10) to let animations settle.


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts := arg.substr(2).split("=", true, 1)
			args[parts[0]] = parts[1]
	var scene_path: String = args.get("scene", ProjectSettings.get_setting("application/run/main_scene"))
	var out: String = args.get("out", "user://screenshot.png")
	var frames := int(args.get("frames", "10"))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("cannot load scene " + scene_path)
		quit(1)
		return
	root.add_child(packed.instantiate())
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var err := image.save_png(out)
	print("saved %s (%dx%d) err=%d" % [out, image.get_width(), image.get_height(), err])
	quit(0 if err == OK else 1)
