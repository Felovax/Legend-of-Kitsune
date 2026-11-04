class_name ShopScreen
extends Control
## Placeholder until the simulated shop arrives in milestone M4.


func _ready() -> void:
	var column := UiKit.vbox([
		UiKit.label(tr("Shop"), "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER),
		UiKit.panel(UiKit.wrap_label(tr("The shop opens in the next update. Everything in the adventure can be earned by playing."), "", HORIZONTAL_ALIGNMENT_CENTER), "CardPanel"),
	], 24)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
