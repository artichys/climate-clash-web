extends Control

const SCENES_PATH := "res://assets/placeholders/scenes/"

const CUTSCENES := {
	"intro": [
		{
			image = "Act 0 S1.png",
			text = "Tahun 2075. Neo-Archipelago berada di ambang krisis.\nLayar-layar kota menyiarkan peringatan: tiga bencana besar akan datang banjir, gelombang panas, dan kehancuran iklim.\nNamun, sudah terlambat untuk menghindar."
		},
		{
			image = "Act 0 S2.png",
			text = "Air laut naik tanpa ampun, menelan jalanan dan bangunan.\nInfrastruktur runtuh, dan kota mulai tenggelam.\nBencana pertama telah dimulai."
		},
		{
			image = "Act 0 S3.png",
			text = "Di tengah kehancuran, satu harapan tersisa.\nKamu adalah Climate Guardian terakhir, penjaga keseimbangan lingkungan.\nDengan pengetahuan dan kebijakan, kamu bersumpah menyelamatkan kota ini."
		}
	],
	"after_flood": [
		{
			image = "Act 1 S1 Aftermath.png",
			text = "Air mulai surut, meninggalkan kota dalam reruntuhan.\nNamun ancaman belum berakhir, ini hanyalah awal dari krisis yang lebih besar."
		}
	],
	"after_heatwave": [
		{
			image = "Act 2 S1 Aftermath.png",
			text = "Gelombang panas ekstrem melanda.\nTanah retak, listrik padam, dan kota perlahan terbakar oleh suhu yang tak terkendali.\nNeo-Archipelago kini menghadapi kehancuran parah."
		}
	],
	"after_boss": [
		{
			image = "Act 3 S1 Aftermath.png",
			text = "Perlahan, kota mulai pulih.\nAir surut, panas mereda, dan kehidupan pun kembali berjalan."
		}
	]
}

var _current_slide: int = 0
var _is_text_animating: bool = false
var _text_tween: Tween
var audio_node
var _slides: Array = []
var _return_scene: String = ""
var _cutscene_id: String = ""

@onready var slide_texture: TextureRect = $SlideTexture
@onready var overlay: ColorRect = $Overlay
@onready var text_label: RichTextLabel = $Overlay/TextLabel
@onready var prompt_label: Label = $Overlay/PromptLabel
@onready var transition_rect: ColorRect = $TransitionRect


func _ready() -> void:
	var run_state: RunState = get_node("/root/RunStateNode")
	audio_node = get_node_or_null("/root/AudioNode")
	if audio_node != null:
		audio_node.call("play_bgm", "bgm_cutscene")
	_cutscene_id = run_state.consume_pending_cutscene_id() if run_state != null else ""
	if _cutscene_id == "":
		_cutscene_id = "intro"

	_slides = CUTSCENES.get(_cutscene_id, CUTSCENES["intro"])
	_return_scene = run_state.consume_pending_cutscene_return_scene() if run_state != null else ""
	if _return_scene == "":
		if _cutscene_id == "after_boss":
			_return_scene = "res://scenes/Result.tscn"
		else:
			_return_scene = "res://scenes/Map.tscn"

	UIStyle.apply_to_scene(self)
	transition_rect.color = Color.BLACK
	transition_rect.modulate.a = 1.0

	var fade_tween := create_tween()
	fade_tween.tween_property(transition_rect, "modulate:a", 0.0, 0.6)

	if _slides.size() == 0:
		_finish_cutscene()
		return

	_show_slide(0)


func _show_slide(index: int) -> void:
	_current_slide = index
	var slide: Dictionary = _slides[index]

	var img_path := SCENES_PATH.path_join(slide.image)
	if ResourceLoader.exists(img_path):
		slide_texture.texture = load(img_path)

	text_label.text = ""
	prompt_label.modulate.a = 0.0
	_is_text_animating = true

	if _text_tween != null and _text_tween.is_valid():
		_text_tween.kill()

	_text_tween = create_tween()
	_text_tween.set_parallel(false)

	var full_text: String = slide.text
	var char_count := full_text.length()

	_text_tween.tween_method(_update_typewriter.bind(full_text), 0.0, float(char_count), 0.03 * char_count).set_delay(0.3).set_ease(Tween.EASE_IN)
	_text_tween.finished.connect(_on_typewriter_done)


func _update_typewriter(progress: float, full_text: String) -> void:
	var count := clampi(int(progress), 0, full_text.length())
	var display := full_text.left(count)
	text_label.text = "[center]" + display + "[/center]"


func _on_typewriter_done() -> void:
	_is_text_animating = false
	var fade_tween := create_tween().set_parallel(true)
	fade_tween.tween_property(prompt_label, "modulate:a", 0.8, 0.4)
	fade_tween.tween_property(prompt_label, "modulate:a", 0.3, 0.4).set_delay(0.8)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb != null and (mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed):
			return

		if _is_text_animating:
			_skip_typewriter()
		else:
			_advance()


func _skip_typewriter() -> void:
	if _text_tween != null and _text_tween.is_valid():
		_text_tween.kill()
	var full_text: String = _slides[_current_slide].text
	text_label.text = "[center]" + full_text + "[/center]"
	_on_typewriter_done()


func _advance() -> void:
	var next_index := _current_slide + 1

	if next_index >= _slides.size():
		_finish_cutscene()
		return

	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(slide_texture, "modulate:a", 0.0, 0.3)
	fade_out.tween_property(overlay, "modulate:a", 0.0, 0.3)
	fade_out.tween_callback(_show_slide.bind(next_index)).set_delay(0.35)

	var fade_in := create_tween().set_parallel(true)
	fade_in.tween_property(slide_texture, "modulate:a", 1.0, 0.3).set_delay(0.35)
	fade_in.tween_property(overlay, "modulate:a", 1.0, 0.3).set_delay(0.35)


func _finish_cutscene() -> void:
	set_process_input(false)
	var fade := create_tween()
	fade.tween_property(transition_rect, "modulate:a", 1.0, 0.6)
	fade.tween_callback(_go_to_return_scene)


func _go_to_return_scene() -> void:
	get_tree().change_scene_to_file(_return_scene)
