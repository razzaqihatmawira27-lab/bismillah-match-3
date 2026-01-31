extends Node2D

enum {wait, move}
var state

var total_time: int = 60
var time_left: int = total_time
var minimum_score: int = 100

@onready var game_timer: Timer = $"../GameTimer"
@onready var time_label: Label = $"../GUI/time_label"

var score: int = 0
@onready var score_label: Label = $"../GUI/score_label"


@export var width: int
@export var height: int
@export var offset: int
@export var y_offset: int

@onready var x_start = ((get_window().size.x / 2.0) - ((width/2.0) * offset ) + (offset / 2))
@onready var y_start = ((get_window().size.y / 2.0) + ((height/2.0) * offset ) - (offset / 2))

@export var empty_spaces: PackedVector2Array

@onready var possible_dots = [
	preload("res://Scenes/Dots/blue_dot.tscn"),
	preload("res://Scenes/Dots/green_dot.tscn"),
	preload("res://Scenes/Dots/pink_dot.tscn"),
	preload("res://Scenes/Dots/red_dot.tscn"),
	preload("res://Scenes/Dots/yellow_dot.tscn"),
]

@onready var music_player: AudioStreamPlayer = $"../MusicPlayer"

@onready var destroy_timer: Timer = $DestroyTimer
@onready var collapse_timer: Timer = $CollapseTimer
@onready var refill_timer: Timer = $RefillTimer

#var destroy_timer = Timer.new()
#var collapse_timer = Timer.new()
#var refill_timer = Timer.new()

var all_dots = []

var dot_one = null
var dot_two = null
var last_place = Vector2(0,0)
var last_direction = Vector2(0,0)
var move_checked = false


var first_touch = Vector2(0,0)
var final_touch = Vector2(0,0)
var controlling = false

func _ready():
	state = move
	#setup_timers()
	randomize()
	all_dots = make_2d_array()
	spawn_dots()
	music_player.play()
	music_player.connect("finished", Callable(self, "_on_music_finished"))
	
	# setup timer replacement
	destroy_timer.connect("timeout", Callable(self, "destroy_matches"))
	collapse_timer.connect("timeout", Callable(self, "collapse_columns"))
	refill_timer.connect("timeout", Callable(self, "refill_columns"))
	
	score = 0
	if score_label:
		score_label.text = "SCORE: 0"
	
	#setup game timer
	time_left = total_time
	if time_label:
		time_label.text = "TIME: " + str(time_left)
	game_timer.wait_time = 1.0
	game_timer.connect("timeout", Callable(self, "_on_game_timer_timeout"))
	game_timer.start()

func _on_music_finished():
	music_player.play()

#func setup_timers():
	#destroy_timer.connect("timeout", Callable(self, "destroy_matches"))
	#destroy_timer.set_one_shot(true)
	#destroy_timer.set_wait_time(0.2)
	#add_child(destroy_timer)
	
	#collapse_timer.connect("timeout", Callable(self, "collapse_columns"))
	#collapse_timer.set_one_shot(true)
	#collapse_timer.set_wait_time(0.2)
	#add_child(collapse_timer)

	#refill_timer.connect("timeout", Callable(self, "refill_columns"))
	#refill_timer.set_one_shot(true)
	#refill_timer.set_wait_time(0.2)
	#add_child(refill_timer)
	
func restricted_fill(place):
	if is_in_array(empty_spaces, place):
		return true
	return false
	
func is_in_array(array, item):
	for i in array.size():
		if array[i] == item:
			return true
	return false

func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array

func spawn_dots():
	for i in width:
		for j in height:
			if !restricted_fill(Vector2(i, j)):
				var rand = floor(randf_range(0, possible_dots.size()))
				var dot = possible_dots[rand].instantiate()
				var loops = 0
				while (match_at(i, j, dot.color) && loops < 100):
					rand = floor(randf_range(0,possible_dots.size()))
					loops += 1
					dot = possible_dots[rand].instantiate()
				add_child(dot)
				dot.position = grid_to_pixel(i, j)
				all_dots[i][j] = dot
			
func match_at(i, j, color):
	if i > 1:
		if all_dots[i - 1][j] != null && all_dots[i - 2][j] != null:
			if all_dots[i - 1][j].color == color && all_dots[i - 2][j].color == color:
				return true
	if j > 1:
		if all_dots[i][j - 1] != null && all_dots[i][j - 2] != null:
			if all_dots[i][j - 1].color == color && all_dots[i][j - 2].color == color:
				return true
	pass

func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start + -offset * row
	return Vector2(new_x, new_y)
	
func pixel_to_grid(pixel_x,pixel_y):
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	return Vector2(new_x, new_y)

func is_in_grid(grid_position):
	if grid_position.x >= 0 && grid_position.x < width:
		if grid_position.y >= 0 && grid_position.y < height:
			return true
	return false

func touch_input():
	if Input.is_action_just_pressed("ui_touch"):
		if is_in_grid(pixel_to_grid(get_global_mouse_position().x,get_global_mouse_position().y)):
			first_touch = pixel_to_grid(get_global_mouse_position().x,get_global_mouse_position().y)
			controlling = true
	if Input.is_action_just_released("ui_touch"):
		if is_in_grid(pixel_to_grid(get_global_mouse_position().x,get_global_mouse_position().y)) && controlling:
			controlling = false
			final_touch = pixel_to_grid(get_global_mouse_position().x,get_global_mouse_position().y )
			touch_difference(first_touch, final_touch)
			
func swap_dots(column, row, direction):
	var first_dot = all_dots[column][row]
	var other_dot = all_dots[column + direction.x][row + direction.y]
	if first_dot != null && other_dot != null:
		store_info(first_dot, other_dot, Vector2(column, row), direction)
		state = wait
		all_dots[column][row] = other_dot
		all_dots[column + direction.x][row + direction.y] = first_dot
		first_dot.move(grid_to_pixel(column + direction.x, row + direction.y))
		other_dot.move(grid_to_pixel(column, row))
		if !move_checked:
			find_matches()
		
func store_info(first_dot, other_dot, place, direciton):
	dot_one = first_dot
	dot_two = other_dot
	last_place = place
	last_direction = direciton
	pass
		
func swap_back():
	if dot_one != null && dot_two != null:
		swap_dots(last_place.x, last_place.y, last_direction)
	state = move
	move_checked = false
	
func touch_difference(grid_1, grid_2):
	var difference = grid_2 - grid_1
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			swap_dots(grid_1.x, grid_1.y, Vector2(1, 0))
		elif difference.x < 0:
			swap_dots(grid_1.x, grid_1.y, Vector2(-1, 0))
	elif abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			swap_dots(grid_1.x, grid_1.y, Vector2(0, 1))
		elif difference.y < 0:
			swap_dots(grid_1.x, grid_1.y, Vector2(0, -1))

func _process(_delta):
	if state == move:
		touch_input()
	
func find_matches():
	for i in width:
		for j in height:
			if all_dots[i][j] != null:
				var current_color = all_dots[i][j].color
				if i > 0 && i < width -1:
					if !is_piece_null(i - 1, j) && !is_piece_null(i + 1, j):
						if all_dots[i - 1][j].color == current_color && all_dots[i + 1][j].color == current_color:
							match_and_dim(all_dots[i - 1][j])
							match_and_dim(all_dots[i][j])
							match_and_dim(all_dots[i + 1][j])
				if j > 0 && j < height -1:
					if !is_piece_null(i, j - 1) && !is_piece_null(i, j + 1):
						if all_dots[i][j - 1].color == current_color && all_dots[i][j + 1].color == current_color:
							match_and_dim(all_dots[i][j - 1])
							match_and_dim(all_dots[i][j])
							match_and_dim(all_dots[i][j + 1])
	destroy_timer.start()

func is_piece_null(column, row):
	if all_dots[column][row] == null:
		return true
	return false

func match_and_dim(item):
	item.matched = true
	item.dim()

func destroy_matches():
	var was_matched = false
	var destroyed_count: int = 0
	for i in width:
		for j in height:
			if all_dots[i][j] != null:
				if all_dots[i][j].matched:
					was_matched = true
					destroyed_count += 1
					all_dots[i][j].queue_free()
					all_dots[i][j] = null
	move_checked = true
	if was_matched:
		add_score(destroyed_count)
		collapse_timer.start()
	else:
		swap_back()
					
func collapse_columns():
	for i in width:
		for j in height:
			if all_dots[i][j] == null && !restricted_fill(Vector2(i,j)):
				for k in range(j + 1, height):
					if all_dots[i][k] != null:
						all_dots[i][k].move(grid_to_pixel(i, j))
						all_dots[i][j] = all_dots[i][k]
						all_dots[i][k] = null
						break
	refill_timer.start()

func refill_columns():
	for i in width:
		for j in height:
			if all_dots[i][j] == null && !restricted_fill(Vector2(i,j)):
				var rand = floor(randf_range(0, possible_dots.size()))
				var dot = possible_dots[rand].instantiate()
				var loops = 0
				while (match_at(i, j, dot.color) && loops < 100):
					rand = floor(randf_range(0,possible_dots.size()))
					loops += 1
					dot = possible_dots[rand].instantiate()
				add_child(dot)
				dot.position = grid_to_pixel(i, j - y_offset)
				dot.move(grid_to_pixel(i,j))
				all_dots[i][j] = dot
	after_refill()
				
func has_possible_moves() -> bool:
	for i in width:
		for j in height:
			if all_dots[i][j] == null:
				continue
			var current_color = all_dots[i][j].color
			# Check right neighbor
			if i < width - 1 and all_dots[i + 1][j] != null:
				swap_colors(i, j, i + 1, j)
				if find_matches_preview():
					swap_colors(i, j, i + 1, j) # swap back
					return true
				swap_colors(i, j, i + 1, j) # swap back
			# Check down neighbor
			if j < height - 1 and all_dots[i][j + 1] != null:
				swap_colors(i, j, i, j + 1)
				if find_matches_preview():
					swap_colors(i, j, i, j + 1) # swap back
					return true
				swap_colors(i, j, i, j + 1) # swap back
	return false

func swap_colors(x1: int, y1: int, x2: int, y2: int) -> void:
	if all_dots[x1][y1] == null or all_dots[x2][y2] == null:
		return
	var temp_type = all_dots[x1][y1].color
	all_dots[x1][y1].color = all_dots[x2][y2].color
	all_dots[x2][y2].color = temp_type

func find_matches_preview() -> bool:
	for i in width:
		for j in height:
			if all_dots[i][j] == null:
				continue
			var current_color = all_dots[i][j].color
			# Horizontal check
			if i > 0 and i < width - 1:
				if all_dots[i - 1][j] != null and all_dots[i + 1][j] != null:
					if all_dots[i - 1][j].color == current_color and all_dots[i + 1][j].color == current_color:
						return true
			# Vertical check
			if j > 0 and j < height - 1:
				if all_dots[i][j - 1] != null and all_dots[i][j + 1] != null:
					if all_dots[i][j - 1].color == current_color and all_dots[i][j + 1].color == current_color:
						return true
	return false

func shuffle_board():
	var flat_list: Array = []
	# Collect all current dots
	for i in width:
		for j in height:
			if all_dots[i][j] != null:
				flat_list.append(all_dots[i][j])
	
	# Shuffle the list
	flat_list.shuffle()
	
	# Reassign positions
	var index = 0
	for i in width:
		for j in height:
			if all_dots[i][j] != null:
				var dot = flat_list[index]
				all_dots[i][j] = dot
				dot.move(grid_to_pixel(i, j))
				index += 1

func after_refill():
	for i in width:
		for j in height:
			if all_dots[i][j] != null:
				if match_at(i, j, all_dots[i][j].color):
					find_matches()
					destroy_timer.start()
					return
	if not has_possible_moves():
		shuffle_board()
	state = move
	move_checked = false
				
func add_score(points: int) -> void:
	score += points
	if score_label:
		score_label.text = "SCORE: " + str(score)
	if score >= minimum_score and time_left > 0:
		check_win_condition()
		
func _on_game_timer_timeout() -> void:
	if time_left > 0:
		time_left -= 1
		if time_label:
			time_label.text = "TIME: " + str(time_left)
	else:
		check_win_condition()

func check_win_condition() -> void:
	game_timer.stop()
	state = wait   # stop player input
	music_player.stop()

	if score >= minimum_score:
		get_tree().change_scene_to_file("res://Scenes/Win_match_3.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/Game_over_match_3.tscn")
