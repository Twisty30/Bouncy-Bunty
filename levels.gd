extends RefCounted
## Level data. Everything is in tiles (36 px). The ground top is row 12.
## Levels are lists of pieces; each piece adds rectangles and objects:
##   plats [x, y, w, h]    mushrooms (bouncy) [x, y, w]    spikes [x, y_floor, w]
##   coins [x, y]          stars [x, y_floor]              checkpoints [x, y_floor]
##   levers [x, y_floor, id, coop]   plates [x, y_floor, id, coop]   doors [x, y_top, h, id, coop]
##   signs [x, y_floor, text]        spawn [x, y_floor]              goal [x, y_floor]

const LEVELS := [
	{"name": "BOUNCY HILLS", "theme": "grass", "pieces": ["start", "flat", "gap", "mushroom_wall", "steps", "goal"]},
	{"name": "MUSHROOM MEADOW", "theme": "grass", "pieces": ["start", "gap", "mushroom_gap", "spikes", "mushroom_wall", "goal"]},
	{"name": "HOP HOP", "theme": "grass", "pieces": ["start", "steps", "mushroom_gap", "coop_door", "hops", "goal"]},
	{"name": "BURROW RUN", "theme": "grass", "pieces": ["start", "spikes", "tunnel", "mushroom_wall", "gap", "goal"]},
	{"name": "LEVER WOODS", "theme": "grass", "pieces": ["start", "lever_door", "mushroom_gap", "star_climb", "dash_gap", "goal"]},
	{"name": "DUNE DASH", "theme": "sand", "pieces": ["start", "dash_gap", "spikes", "mushroom_gap", "gap", "goal"]},
	{"name": "CACTUS CANYON", "theme": "sand", "pieces": ["start", "mushroom_wall", "tunnel", "hops", "coop_door", "spikes", "goal"]},
	{"name": "SANDY STEPS", "theme": "sand", "pieces": ["start", "steps", "star_climb", "lever_door", "dash_gap", "mushroom_gap", "goal"]},
	{"name": "OASIS LEAP", "theme": "sand", "pieces": ["start", "hops", "mushroom_gap", "tunnel", "coop_door", "mushroom_wall", "goal"]},
	{"name": "SCORCHED PATH", "theme": "sand", "pieces": ["start", "mushroom_wall", "spikes", "dash_gap", "mushroom_gap", "lever_door", "steps", "goal"]},
	{"name": "FROSTY FIELDS", "theme": "snow", "pieces": ["start", "mushroom_gap", "dash_gap", "steps", "coop_door", "spikes", "goal"]},
	{"name": "ICICLE RIDGE", "theme": "snow", "pieces": ["start", "star_climb", "spikes", "tunnel", "hops", "mushroom_wall", "goal"]},
	{"name": "BLIZZARD BOUNCE", "theme": "snow", "pieces": ["start", "dash_gap", "mushroom_gap", "lever_door", "hops", "coop_door", "spikes", "goal"]},
	{"name": "CASTLE GATES", "theme": "snow", "pieces": ["start", "mushroom_wall", "hops", "spikes", "mushroom_gap", "dash_gap", "tunnel", "goal"]},
	{"name": "KING BEAR'S THRONE", "theme": "castle", "boss": true},
]

const TUTORIAL := [
	["start", "MOVE: A/D  |  LEFT/RIGHT  |  LEFT STICK"],
	["gap", "JUMP: W  |  UP  |  CROSS/B/A  (HOLD = HIGHER)"],
	["tunnel", "CROUCH: S  |  DOWN  |  HOLD R1/R/RB"],
	["dash_gap", "DASH: Q  |  CTRL  |  SQUARE/Y/X  (JUMP, THEN DASH)"],
	["lever_door", "INTERACT: E  |  RIGHT SHIFT  |  TRIANGLE/X/Y"],
	["mushroom_wall", "MUSHROOMS ARE BOUNCY!"],
	["star_climb", "THE PINK GEM MAKES YOU EXTRA BOUNCY"],
	["goal", "WALK INTO THE DOOR.  ESC = MENU"],
]

const TRIAL_PIECES := ["flat", "gap", "steps", "mushroom_wall", "mushroom_gap", "spikes", "dash_gap", "tunnel", "hops", "star_climb"]

## Pieces that start with ground under them get a checkpoint.
const GROUND_START := ["flat", "mushroom_wall", "spikes", "tunnel", "lever_door", "star_climb", "coop_door"]


static func empty() -> Dictionary:
	return {"plats": [], "mushrooms": [], "spikes": [], "coins": [], "stars": [], "checkpoints": [],
		"levers": [], "plates": [], "doors": [], "signs": [], "width": 0}


## Adds one piece starting at column x. Returns the column after it.
static func add_piece(d: Dictionary, name: String, x: int, id: int) -> int:
	match name:
		"start":
			d["plats"].append([x, 12, 8, 4])
			d["spawn"] = [x + 2, 12]
			return x + 8
		"flat":
			d["plats"].append([x, 12, 8, 4])
			for i in 3:
				d["coins"].append([x + 2 + i * 2, 11])
			return x + 8
		"gap":
			d["plats"].append([x + 3, 12, 6, 4])
			d["coins"].append([x + 1, 9])
			return x + 9
		"steps":
			d["plats"].append_array([[x + 2, 10, 3, 1], [x + 7, 8, 3, 1], [x + 12, 12, 5, 4]])
			d["coins"].append([x + 8, 7])
			return x + 17
		"hops":
			d["plats"].append_array([[x + 2, 10, 3, 1], [x + 7, 8, 3, 1], [x + 12, 10, 3, 1], [x + 17, 12, 5, 4]])
			return x + 22
		"mushroom_wall":
			d["plats"].append_array([[x, 12, 16, 4], [x + 7, 6, 5, 6]])
			d["mushrooms"].append([x + 3, 11, 3])
			d["coins"].append_array([[x + 8, 5], [x + 10, 5]])
			return x + 16
		"mushroom_gap":
			d["mushrooms"].append_array([[x + 2, 12, 3], [x + 10, 12, 3]])
			d["plats"].append([x + 16, 12, 6, 4])
			d["coins"].append_array([[x + 3, 9], [x + 11, 9]])
			return x + 22
		"spikes":
			d["plats"].append([x, 12, 12, 4])
			d["spikes"].append_array([[x + 4, 12, 2], [x + 8, 12, 2]])
			return x + 12
		"dash_gap":
			d["plats"].append([x + 7, 12, 6, 4])
			d["coins"].append([x + 3, 10])
			return x + 13
		"tunnel":
			d["plats"].append_array([[x, 12, 12, 4], [x + 3, 7, 6, 4]])
			d["coins"].append_array([[x + 4, 11], [x + 6, 11]])
			return x + 12
		"lever_door":
			d["plats"].append([x, 12, 12, 4])
			d["levers"].append([x + 2, 12, id, false])
			d["doors"].append([x + 7, 8, 4, id, false])
			return x + 12
		"star_climb":
			d["plats"].append_array([[x, 12, 14, 4], [x + 10, 3, 4, 1]])
			d["stars"].append([x + 2, 12])
			d["mushrooms"].append([x + 6, 11, 3])
			for i in 3:
				d["coins"].append([x + 10 + i, 2])
			return x + 14
		"coop_door":
			d["plats"].append([x, 12, 14, 4])
			d["plates"].append([x + 2, 12, id, true])
			d["doors"].append([x + 7, 8, 4, id, true])
			d["levers"].append([x + 10, 12, id, true])
			return x + 14
		"goal":
			d["plats"].append([x, 12, 8, 4])
			d["goal"] = [x + 5, 12]
			return x + 8
	push_error("Unknown piece: " + name)
	return x


## Builds a whole level from a list of pieces (or [piece, sign text] pairs).
static func build(pieces: Array) -> Dictionary:
	var d := empty()
	var x := 0
	for i in pieces.size():
		var name: String = pieces[i] if pieces[i] is String else pieces[i][0]
		if pieces[i] is Array:
			d["signs"].append([x + 1, 12, pieces[i][1]])
		elif i > 0 and i % 2 == 0 and name in GROUND_START:
			d["checkpoints"].append([x + 1, 12])
		x = add_piece(d, name, x, i + 1)
	d["width"] = x
	return d


static func boss_arena() -> Dictionary:
	var d := empty()
	d["plats"] = [[0, 12, 32, 4], [-1, -10, 1, 26], [32, -10, 1, 26], [9, 8, 4, 1], [19, 8, 4, 1]]
	d["mushrooms"] = [[3, 11, 3], [26, 11, 3]]
	d["spawn"] = [6, 12]
	d["boss"] = [22, 12]
	d["width"] = 32
	return d
