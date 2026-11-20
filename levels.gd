extends RefCounted
## Level data for Bouncy Bunty REBOUND.
##
## A level is a list of CHUNKS placed left to right. A chunk is drawn as text, top row first.
## The LAST row of every chunk is the ground row: a '#' there is ground that runs to the bottom
## of the world, a space there is a pit. One character is one tile (36 px).
##
##   #  ground / wall        =  thin ledge you can jump up through
##   o  coin                 g  gem spot (each level keeps 3 of them, the rest become coins)
##   h  heart                *  power star
##   M  mushroom cap         J  spring
##   B  crate (claw it)      x  crumbling block
##   >  platform moving right and back      <  moving left and back      |  moving up and back
##   :  fading platform (run of them = one platform)   ;  fading platform, out of step with ':'
##   _  falling platform: drops when you stand on it, comes back later
##   !  speed boost   +  extra jump (stack two for a triple jump)   @  super bounce
##   $  coin magnet   &  bubble shield (blocks one hit)
##   ^  floor spikes         v  ceiling spikes        ~  water / lava (last row only)
##   L  lever                D  door block (opened by the lever in the same chunk)
##   a  bot    f  bat    d  drill (do not stomp)    R  big bot    p  shooter    q  ghost
##   T  thwomp  k  orbiting spark ball  s  saw (side to side)  z  saw (up and down)
##   F  fire jet  E  electric arc  i  icicle
##   S  player start         G  goal portal           X  boss start
##
## Jump numbers, for building new chunks: a jump climbs 2 tiles comfortably (3 is the limit)
## and clears a 4 tile gap (5 is tight). Jump + dash clears 7. A mushroom throws you 6 tiles up,
## a spring 9. Every chunk should start and end with two tiles of ground.

const WORLDS := [
	{"name": "BOUNCY HILLS", "theme": "grass", "music": "level", "pitch": 1.0,
		"boss": "clank", "color": Color(0.45, 0.85, 0.4)},
	{"name": "DUNE DESERT", "theme": "sand", "music": "desert", "pitch": 1.0,
		"boss": "drill", "color": Color(1.0, 0.75, 0.35)},
	{"name": "FROST PEAKS", "theme": "snow", "music": "frost", "pitch": 1.0,
		"boss": "block", "color": Color(0.7, 0.9, 1.0)},
	{"name": "THUNDER HEIGHTS", "theme": "storm", "music": "storm", "pitch": 1.0,
		"boss": "flap", "color": Color(0.6, 0.6, 1.0)},
	{"name": "KING'S CASTLE", "theme": "castle", "music": "castle", "pitch": 1.0,
		"boss": "king", "color": Color(0.95, 0.4, 0.5)},
]

## thin / top: first tile of the 4-tile row [single, left, middle, right] in the tile sheet.
const THEMES := {
	"grass": {"thin": 0, "top": 20, "tint": Color(1, 1, 1),
		"sky": [Color(0.36, 0.7, 0.98), Color(0.74, 0.93, 1.0)], "bg": [6, 7], "bg_tint": Color(1, 1, 1),
		"clouds": Color(1, 1, 1), "weather": "petals", "decor": [124, 125, 124, 128, 126], "ledge": [146, 146, 146]},
	"sand": {"thin": 40, "top": 60, "tint": Color(1, 1, 1),
		"sky": [Color(0.98, 0.62, 0.42), Color(1.0, 0.88, 0.6)], "bg": [4, 5], "bg_tint": Color(1, 1, 1),
		"clouds": Color(1, 0.95, 0.85, 0.8), "weather": "dust", "decor": [127, 127, 124], "ledge": [146, 146, 146]},
	"snow": {"thin": 80, "top": 100, "tint": Color(1, 1, 1),
		"sky": [Color(0.55, 0.75, 0.95), Color(0.88, 0.95, 1.0)], "bg": [0, 1, 2, 3], "bg_tint": Color(1, 1, 1),
		"clouds": Color(1, 1, 1), "weather": "snow", "decor": [126, 145, 126], "ledge": [146, 146, 146], "slippery": true},
	"storm": {"thin": 0, "top": 20, "tint": Color(0.62, 0.72, 0.98),
		"sky": [Color(0.12, 0.13, 0.28), Color(0.36, 0.38, 0.6)], "bg": [6, 7], "bg_tint": Color(0.35, 0.4, 0.7),
		"clouds": Color(0.5, 0.52, 0.72, 0.9), "weather": "rain", "decor": [125, 128, 124], "ledge": [153, 154, 155]},
	"castle": {"thin": 80, "top": 100, "tint": Color(0.6, 0.52, 0.74),
		"sky": [Color(0.1, 0.05, 0.16), Color(0.36, 0.14, 0.24)], "bg": [0, 1, 2, 3], "bg_tint": Color(0.3, 0.2, 0.4),
		"clouds": Color(0.4, 0.3, 0.5, 0.6), "weather": "embers", "decor": [], "ledge": [146, 146, 146], "lava": true},
}

const CHUNKS := {
	# ------------------------------------------------------------------ shared
	"start": [
		"              ",
		"   S          ",
		"##############"],
	"goal": [
		"                ",
		"                ",
		"         G      ",
		"################"],
	"flat": [
		"   o o o    ",
		"            ",
		"############"],
	"rest": [
		"            ",
		"     h      ",
		"############"],

	# ------------------------------------------------------------------ world 1: bouncy hills
	"bots": [
		"     o o      g     ",
		"                    ",
		"    a         a     ",
		"####################"],
	"gap": [
		"      g      ",
		"     o o     ",
		"             ",
		"#####   #####"],
	"gap_wide": [
		"     o  o      ",
		"    g    o     ",
		"               ",
		"#####    ######"],
	"hops": [
		"             g        ",
		"            ===       ",
		"      oo              ",
		"     ====      ====   ",
		"                      ",
		"###                ###"],
	"shroom_wall": [
		"                    ",
		"           g        ",
		"          ooo       ",
		"         #####      ",
		"         #####      ",
		"         #####      ",
		"         #####      ",
		"         #####      ",
		"   MMM   #####      ",
		"         #####      ",
		"####################"],
	"shroom_gap": [
		"    o        o        ",
		"   o g      o o       ",
		"                      ",
		"                      ",
		"###  MMM     MMM   ###"],
	"shroom_chain": [
		"                    g       ",
		"                            ",
		"          ooo               ",
		"                   ###      ",
		"    ooo            ###      ",
		"            MMM    ###      ",
		"                   ###      ",
		"     MMM           ###      ",
		"                   ###      ",
		"###                #########"],
	"crates": [
		"         g        ",
		"         B        ",
		"    B   BBB    a  ",
		"##################"],
	"spring_tower": [
		"            g     ",
		"                  ",
		"           ooo    ",
		"          #####   ",
		"          #####   ",
		"          #####   ",
		"          #####   ",
		"          #####   ",
		"          #####   ",
		"          #####   ",
		"     J    #####   ",
		"##################"],
	"ledges": [
		"        g         ",
		"                  ",
		"       ===        ",
		"                  ",
		"   ===     ===    ",
		"    o       o     ",
		"       ===        ",
		"              a   ",
		"##################"],
	"lever_gate": [
		"           ###      ",
		"           ###      ",
		"           ###      ",
		"           ###      ",
		"           ###      ",
		"           ###      ",
		"            D       ",
		"     L      D   o o ",
		"####################"],
	"wall_kick": [
		"     ##          ",
		"     ##    ######",
		"     ##  o ######",
		"     ##    ######",
		"     ##  g ######",
		"     ##    ######",
		"     ##  o ######",
		"           ######",
		"           ######",
		"#################"],
	"bat_field": [
		"       f          f     ",
		"                        ",
		"   o        f      g    ",
		"       ooo     ooo      ",
		"                        ",
		"########################"],
	"dash_gap": [
		"       o g o        ",
		"                    ",
		"                    ",
		"#####       ########"],
	"star_run": [
		"                              ",
		"   *     a  a  a   a  a  a    ",
		"##############################"],
	"plank_bridge": [
		"      o    g    o     ",
		"         a            ",
		"####======  ======####"],
	"crate_wall": [
		"         B        ",
		"         B   o g  ",
		"         B        ",
		"##################"],

	# ------------------------------------------------------------------ world 2: dune desert
	"spikes": [
		"      o      g      ",
		"                    ",
		"     ^^     ^^^     ",
		"####################"],
	"spike_hops": [
		"       o     g     o       ",
		"                           ",
		"      ===   ===   ===      ",
		"    ^^^^^^^^^^^^^^^^^^^    ",
		"###########################"],
	"drills": [
		"      o        g      ",
		"                      ",
		"     d        d   B   ",
		"######################"],
	"moving_bridge": [
		"       o      g           ",
		"                          ",
		"####>              <   ###"],
	"crumble_bridge": [
		"     o  o  g  o       ",
		"                      ",
		"####xxxxxxxxxxxxxx####"],
	"shooter_lane": [
		"       o      g        ",
		"                       ",
		"          B       p    ",
		"#######################"],
	"pyramid": [
		"            g             ",
		"           ####           ",
		"         ########         ",
		"       ############       ",
		"     ################  d  ",
		"##########################"],
	"vplat_climb": [
		"               ogo    ",
		"              #####   ",
		"              #####   ",
		"              #####   ",
		"              #####   ",
		"              #####   ",
		"        |     #####   ",
		"######################"],
	"dash_spikes": [
		"         o g o         ",
		"                       ",
		"       ^^^^^^^         ",
		"#######################"],
	"tunnel": [
		"    ##########    ",
		"    ##########    ",
		"    ##########    ",
		"     o  g  o      ",
		"##################"],
	"spike_tunnel": [
		"    ##############     ",
		"    ##############     ",
		"    vvv        vvv     ",
		"                       ",
		"          ^^           ",
		"#######################"],
	"shooter_tower": [
		"             g          ",
		"                   p    ",
		"                  ###   ",
		"      ===   ===   ###   ",
		"                  ###   ",
		"###               ######"],
	"drill_pits": [
		"     o          g        ",
		"                         ",
		"   d       d        d    ",
		"######  ########  #######"],
	"oasis": [
		"      o     g       ",
		"                    ",
		"          h         ",
		"####~~~~####~~~~####"],

	# ------------------------------------------------------------------ world 3: frost peaks
	"icicles": [
		" ################## ",
		"   i   i  i   i  i  ",
		"                    ",
		"                    ",
		"      o       g     ",
		"                    ",
		"####################"],
	"thwomps": [
		"     T      T      T    ",
		"                        ",
		"                        ",
		"                        ",
		"     o      g      o    ",
		"########################"],
	"saw_run": [
		"       o        g       ",
		"                        ",
		"     s           s      ",
		"########################"],
	"ice_steps": [
		"                   ogo  ",
		"              ##  ##### ",
		"         ##       ##### ",
		"    ##            ##### ",
		"                  ##### ",
		"###               ######"],
	"frozen_gap": [
		"  ##################  ",
		"      i    i    i     ",
		"                      ",
		"        o g o         ",
		"                      ",
		"                      ",
		"######       #########"],
	"snow_shrooms": [
		"            f            ",
		"    o              o     ",
		"   o g     f      o o    ",
		"                         ",
		"                         ",
		"###  MMM    MMM    MMM ##"],
	"saw_shaft": [
		"     ##          ",
		"     ## g  ######",
		"     ##    ######",
		"     ##  z ######",
		"     ##    ######",
		"     ##    ######",
		"     ##    ######",
		"           ######",
		"           ######",
		"#################"],
	"bigbot": [
		"                      ",
		"         R       o g  ",
		"######################"],
	"thwomp_gap": [
		"         T              ",
		"                        ",
		"                        ",
		"     o       g          ",
		"                        ",
		"#####   ###    #########"],
	"ice_slide": [
		"                              ",
		"      o   o   o   g           ",
		"                              ",
		"         ^^        ^^    a    ",
		"##############################"],
	"saw_bridge": [
		"      o       g          ",
		"          s              ",
		"####========  ========###"],
	"icicle_plats": [
		"  ####################    ",
		"     i     i     i        ",
		"                          ",
		"                          ",
		"      ===   ===   ===     ",
		"                          ",
		"###                    ###"],

	# ------------------------------------------------------------------ world 4: thunder heights
	"cloud_hops": [
		"       o        g        o      ",
		"                                ",
		"      ===      ===      ===     ",
		"                                ",
		"###        ===      ===      ###"],
	"arc_gate": [
		"        o       o       ",
		"                        ",
		"                        ",
		"      E       E      E  ",
		"########################"],
	"storm_plats": [
		"          f         f         ",
		"       o       g        o     ",
		"                              ",
		"###>               <     >     ###"],
	"spring_sky": [
		"                    ooo        ",
		"                   =====       ",
		"                               ",
		"                               ",
		"           g                   ",
		"         =====                 ",
		"                               ",
		"                               ",
		"                               ",
		"                               ",
		"    J              J           ",
		"#######          #######    ###"],
	"ball_alley": [
		"         o          g       ",
		"                            ",
		"      k        k        k   ",
		"                            ",
		"############################"],
	"arc_hops": [
		"       o       g       o      ",
		"                              ",
		"                              ",
		"      ===     ===     ===     ",
		"          E       E           ",
		"###      ===     ===       ###"],
	"thunder_tower": [
		"                   ooo  ",
		"                 #######",
		"                 #######",
		"            g    #######",
		"                 #######",
		"       ===       #######",
		"                 #######",
		"                 #######",
		"           |     #######",
		"   |             #######",
		"########################"],
	"bat_storm": [
		"     f        f        f    ",
		"                            ",
		"        f          f        ",
		"    o        g        o     ",
		"                            ",
		"####  ====  ====  ====  ####"],
	"dash_clouds": [
		"       o o          o o      ",
		"                             ",
		"                             ",
		"#####      ===      #########"],
	"spark_bridge": [
		"      o       g       o     ",
		"                            ",
		"        k           k       ",
		"                            ",
		"####xxxx====xxxx====xxxx####"],

	# ------------------------------------------------------------------ world 5: king's castle
	"lava_gap": [
		"      o      g      ",
		"                    ",
		"                    ",
		"####~~~~##~~~~######"],
	"fire_hall": [
		"       o     g     o    ",
		"                        ",
		"     F     F     F      ",
		"########################"],
	"lava_crumble": [
		"      o     g     o      ",
		"         f      f        ",
		"                         ",
		"####xxxxxx~~~~xxxxxx#####"],
	"thwomp_lava": [
		"       T          T       ",
		"                          ",
		"                          ",
		"       o     g    o       ",
		"                          ",
		"####~~###~~~~~~~###~~#####"],
	"ghost_hall": [
		"                          ",
		"      q            q      ",
		"                          ",
		"   o     o    g     o     ",
		"                          ",
		"##########################"],
	"saw_gauntlet": [
		"     ##################     ",
		"                            ",
		"       z       z      z     ",
		"                            ",
		"    o      g       o        ",
		"############################"],
	"castle_kick": [
		"     ##          ",
		"     ##    ######",
		"     ##  o ######",
		"     ##    ######",
		"     ##  g ######",
		"     ##    ######",
		"     ##    ######",
		"           ######",
		"       F   ######",
		"#################"],
	"bigbot_guard": [
		"                 g        ",
		"                 B        ",
		"       R        BB    R   ",
		"##########################"],
	"lava_plats": [
		"        o      g       o       ",
		"                               ",
		"                               ",
		"###>~~~~~~~~~~<~~~~~~>~~~~~~###"],
	"fire_steps": [
		"                        ooo ",
		"                       #####",
		"                 ###   #####",
		"           ###         #####",
		"      ###              #####",
		"   F      F     F      #####",
		"####~~~~~~~~~~~~~~~~~~~#####"],
	"gauntlet": [
		"       T                 T      ",
		"                                ",
		"                                ",
		"            o  g  o             ",
		"     F           s        F     ",
		"################################"],
	"lever_lava": [
		"            ###        ",
		"            ###        ",
		"            ###        ",
		"            ###        ",
		"            ###        ",
		"   L        ###        ",
		"  ===        D         ",
		"       d     D    o g  ",
		"#####~~~###############"],

	# ------------------------------------------------------------------ platforms and power-ups
	"lift_meadow": [
		"                  g        ",
		"                           ",
		"                 ===       ",
		"       o o o               ",
		"                           ",
		"                           ",
		"###>        |          ####"],
	"fade_steps": [
		"        o    g    o        ",
		"                           ",
		"     :::  ;;;  :::  ;;;    ",
		"                           ",
		"###                     ###"],
	"fade_high": [
		"             g           ",
		"                         ",
		"          ;;;            ",
		"                         ",
		"     :::        :::      ",
		"                         ",
		"###                   ###"],
	"falling_bridge": [
		"      o    g    o       ",
		"                        ",
		"                        ",
		"###  ___  ___  ___  ####"],
	"lava_fall": [
		"      o    g    o       ",
		"                        ",
		"                        ",
		"###~~___~~___~~___~~####"],
	"speed_run": [
		"         o o o o o o o o    g     ",
		"                                  ",
		"    !       a       a       a     ",
		"##################################"],
	"jump_cliffs": [
		"                 g        ",
		"                          ",
		"               ===        ",
		"                          ",
		"                          ",
		"         ===              ",
		"    +                     ",
		"##########################"],
	"super_springs": [
		"              o g o      ",
		"                         ",
		"             =====       ",
		"                         ",
		"                         ",
		"    @                    ",
		"#########################"],
	"magnet_field": [
		"     o   o   o   o   o   o   o   ",
		"                                 ",
		"       o   o   o   o   o   o     ",
		"                                 ",
		"    $ o o o   o o o   o o o  g   ",
		"     a        a        a         ",
		"#################################"],
	"shield_hall": [
		"          o   g   o       ",
		"                          ",
		"    & ===   ===   ===     ",
		"     ^^^^^^^^^^^^^^^^^    ",
		"##########################"],

	# ------------------------------------------------------------------ boss arenas (34 wide, walled in)
	"arena_clank": [
		"##################################",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#       ====          ====       #",
		"#                                #",
		"#                                #",
		"#    S                    X      #",
		"##################################"],
	"arena_drill": [
		"##################################",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#             ======             #",
		"#                                #",
		"#     ====              ====     #",
		"#                                #",
		"#                                #",
		"#    S                    X      #",
		"##################################"],
	"arena_block": [
		"##################################",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#  MMM                      MMM  #",
		"#        S       X               #",
		"##################################"],
	"arena_flap": [
		"##################################",
		"#                                #",
		"#                                #",
		"#                                #",
		"#          ====    ====          #",
		"#                                #",
		"#                                #",
		"#    ====      ====      ====    #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#  J     S       X            J  #",
		"##################################"],
	"arena_king": [
		"##################################",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#                                #",
		"#       ====          ====       #",
		"#                                #",
		"#  MMM                      MMM  #",
		"#        S              X        #",
		"##################################"],

	# ------------------------------------------------------------------ bootcamp (tutorial)
	"t_move": [
		"                  ",
		"   S       o o o  ",
		"##################"],
	"t_jump": [
		"      o        o      ",
		"     o o      o o     ",
		"                      ",
		"#####   ######   #####"],
	"t_crouch": [
		"    ##########    ",
		"    ##########    ",
		"    ##########    ",
		"     o  o  o      ",
		"##################"],
	"t_dash": [
		"       o o o        ",
		"                    ",
		"                    ",
		"#####       ########"],
	"t_claw": [
		"                    ",
		"                    ",
		"     B   B   BBB    ",
		"####################"],
	"t_stomp": [
		"                    ",
		"                    ",
		"      a       a     ",
		"####################"],
	"t_pound": [
		"                      ",
		"          ooo         ",
		"                      ",
		"         BBBBB        ",
		"######################"],
	"t_wall": [
		"     ##          ",
		"     ##    ######",
		"     ##  o ######",
		"     ##    ######",
		"     ##  o ######",
		"     ##    ######",
		"           ######",
		"           ######",
		"#################"],
	"t_shroom": [
		"          ooo       ",
		"         #####      ",
		"         #####      ",
		"         #####      ",
		"         #####      ",
		"   MMM   #####      ",
		"         #####      ",
		"####################"],
	"t_lever": [
		"           ###      ",
		"           ###      ",
		"           ###      ",
		"           ###      ",
		"           ###      ",
		"           ###      ",
		"            D       ",
		"     L      D       ",
		"####################"],
	"t_fight": [
		"                        ",
		"     h                  ",
		"              R         ",
		"########################"],
}

## The 50 story levels. Levels 10, 20, 30, 40 and 50 are boss fights.
const LEVELS := [
	# ---- world 1: bouncy hills
	{"name": "FIRST BOUNCE", "chunks": ["start", "flat", "gap", "bots", "shroom_wall", "flat", "gap", "goal"]},
	{"name": "MUSHROOM MEADOW", "chunks": ["start", "gap", "shroom_gap", "bots", "hops", "shroom_wall", "crates", "jump_cliffs", "goal"]},
	{"name": "CRATE CRASHER", "chunks": ["start", "crates", "gap_wide", "crate_wall", "lift_meadow", "bots", "ledges", "shroom_gap", "crates", "goal"]},
	{"name": "SPRINGTIME", "chunks": ["start", "bots", "spring_tower", "gap_wide", "hops", "spring_tower", "super_springs", "bat_field", "goal"]},
	{"name": "LEVER WOODS", "chunks": ["start", "plank_bridge", "lever_gate", "shroom_chain", "bots", "lever_gate", "gap_wide", "goal"]},
	{"name": "KICK THE WALLS", "chunks": ["start", "gap", "wall_kick", "bots", "ledges", "wall_kick", "fade_steps", "shroom_gap", "goal"]},
	{"name": "BAT COUNTRY", "chunks": ["start", "bat_field", "hops", "plank_bridge", "bat_field", "shroom_chain", "magnet_field", "crates", "goal"]},
	{"name": "DASH MEADOWS", "chunks": ["start", "dash_gap", "bots", "shroom_gap", "dash_gap", "wall_kick", "star_run", "speed_run", "dash_gap", "goal"]},
	{"name": "HILLTOP GAUNTLET", "chunks": ["start", "hops", "wall_kick", "bat_field", "spring_tower", "dash_gap", "shroom_chain", "lever_gate", "plank_bridge", "falling_bridge", "lift_meadow", "goal"]},
	{"name": "CAPTAIN CLANK", "boss": "clank", "chunks": ["arena_clank"]},
	# ---- world 2: dune desert
	{"name": "HOT SAND", "chunks": ["start", "spikes", "gap_wide", "drills", "spike_hops", "shield_hall", "flat", "goal"]},
	{"name": "DRILL SERGEANTS", "chunks": ["start", "drills", "pyramid", "spikes", "drill_pits", "crates", "shroom_gap", "goal"]},
	{"name": "SHIFTING BRIDGES", "chunks": ["start", "moving_bridge", "spikes", "crumble_bridge", "drills", "moving_bridge", "falling_bridge", "fade_steps", "goal"]},
	{"name": "THE LONG CRAWL", "chunks": ["start", "tunnel", "spikes", "spike_tunnel", "drill_pits", "tunnel", "dash_spikes", "goal"]},
	{"name": "OASIS LEAP", "chunks": ["start", "oasis", "vplat_climb", "shooter_lane", "oasis", "spike_hops", "rest", "moving_bridge", "goal"]},
	{"name": "SNIPER DUNES", "chunks": ["start", "shooter_lane", "dash_spikes", "shooter_tower", "drills", "shooter_lane", "speed_run", "crumble_bridge", "goal"]},
	{"name": "PYRAMID SCHEME", "chunks": ["start", "pyramid", "wall_kick", "spike_hops", "vplat_climb", "pyramid", "drill_pits", "goal"]},
	{"name": "CRUMBLE CANYON", "chunks": ["start", "crumble_bridge", "bat_field", "moving_bridge", "spike_tunnel", "crumble_bridge", "shooter_tower", "falling_bridge", "dash_spikes", "goal"]},
	{"name": "SCORCHED PATH", "chunks": ["start", "dash_spikes", "drill_pits", "vplat_climb", "shooter_tower", "rest", "spike_hops", "moving_bridge", "spike_tunnel", "wall_kick", "goal"]},
	{"name": "THE DRILL SERGEANT", "boss": "drill", "chunks": ["arena_drill"]},
	# ---- world 3: frost peaks
	{"name": "SLIP AND SLIDE", "chunks": ["start", "flat", "ice_slide", "gap", "bots", "lift_meadow", "snow_shrooms", "goal"]},
	{"name": "ICICLE ALLEY", "chunks": ["start", "icicles", "gap_wide", "ice_slide", "icicles", "shroom_wall", "goal"]},
	{"name": "THWOMP TROT", "chunks": ["start", "thwomps", "ice_steps", "bots", "thwomp_gap", "crates", "thwomps", "goal"]},
	{"name": "BUZZ SAW BLUES", "chunks": ["start", "saw_run", "snow_shrooms", "saw_bridge", "ice_slide", "saw_run", "goal"]},
	{"name": "FROZEN LEAP", "chunks": ["start", "frozen_gap", "bigbot", "icicle_plats", "rest", "ice_steps", "frozen_gap", "fade_high", "goal"]},
	{"name": "THE SAW SHAFT", "chunks": ["start", "saw_shaft", "thwomps", "saw_bridge", "saw_shaft", "snow_shrooms", "bigbot", "goal"]},
	{"name": "BLIZZARD BOUNCE", "chunks": ["start", "snow_shrooms", "icicles", "spring_tower", "thwomp_gap", "bat_field", "ice_steps", "super_springs", "icicle_plats", "goal"]},
	{"name": "COLD STEEL", "chunks": ["start", "bigbot", "saw_run", "frozen_gap", "lever_gate", "thwomps", "saw_bridge", "bigbot", "goal"]},
	{"name": "SUMMIT RUSH", "chunks": ["start", "ice_slide", "saw_shaft", "icicle_plats", "thwomp_gap", "rest", "frozen_gap", "saw_bridge", "ice_steps", "thwomps", "falling_bridge", "fade_steps", "goal"]},
	{"name": "BLOCKHEAD THE COLD", "boss": "block", "chunks": ["arena_block"]},
	# ---- world 4: thunder heights
	{"name": "HEAD IN THE CLOUDS", "chunks": ["start", "cloud_hops", "bat_field", "gap_wide", "cloud_hops", "shroom_gap", "jump_cliffs", "fade_high", "goal"]},
	{"name": "ZAP GATES", "chunks": ["start", "arc_gate", "cloud_hops", "bots", "arc_gate", "hops", "arc_hops", "goal"]},
	{"name": "RIDE THE STORM", "chunks": ["start", "storm_plats", "arc_gate", "moving_bridge", "bat_storm", "storm_plats", "goal"]},
	{"name": "SPRING SKY", "chunks": ["start", "spring_sky", "ball_alley", "spring_tower", "cloud_hops", "spring_sky", "super_springs", "goal"]},
	{"name": "SPARK ALLEY", "chunks": ["start", "ball_alley", "spark_bridge", "rest", "arc_hops", "ball_alley", "wall_kick", "goal"]},
	{"name": "THUNDER TOWER", "chunks": ["start", "thunder_tower", "bat_storm", "vplat_climb", "arc_gate", "thunder_tower", "dash_gap", "goal"]},
	{"name": "LEAP OF FAITH", "chunks": ["start", "dash_clouds", "arc_hops", "storm_plats", "dash_clouds", "spark_bridge", "falling_bridge", "fade_steps", "bigbot", "goal"]},
	{"name": "EYE OF THE STORM", "chunks": ["start", "bat_storm", "spark_bridge", "spring_sky", "arc_gate", "star_run", "storm_plats", "magnet_field", "arc_hops", "goal"]},
	{"name": "STORMFRONT", "chunks": ["start", "arc_hops", "thunder_tower", "ball_alley", "dash_clouds", "rest", "spark_bridge", "bat_storm", "saw_shaft", "storm_plats", "goal"]},
	{"name": "BARON VON FLAP", "boss": "flap", "chunks": ["arena_flap"]},
	# ---- world 5: king's castle
	{"name": "THE DRAWBRIDGE", "chunks": ["start", "lava_gap", "bots", "fire_hall", "crates", "lava_gap", "shield_hall", "ghost_hall", "goal"]},
	{"name": "HALL OF FLAMES", "chunks": ["start", "fire_hall", "lava_gap", "fire_steps", "drills", "fire_hall", "goal"]},
	{"name": "HAUNTED KEEP", "chunks": ["start", "ghost_hall", "saw_gauntlet", "lava_crumble", "ghost_hall", "bigbot_guard", "goal"]},
	{"name": "MOLTEN MOAT", "chunks": ["start", "lava_plats", "thwomp_lava", "rest", "lava_crumble", "lava_plats", "lava_fall", "fire_hall", "goal"]},
	{"name": "THE ARMORY", "chunks": ["start", "bigbot_guard", "saw_gauntlet", "lever_lava", "shooter_lane", "bigbot_guard", "castle_kick", "goal"]},
	{"name": "CRUSHER CORRIDOR", "chunks": ["start", "thwomp_lava", "gauntlet", "fire_steps", "thwomps", "rest", "gauntlet", "speed_run", "goal"]},
	{"name": "TOWER OF KICKS", "chunks": ["start", "castle_kick", "fire_hall", "saw_shaft", "lava_plats", "castle_kick", "ghost_hall", "thunder_tower", "goal"]},
	{"name": "NO BEAR'S LAND", "chunks": ["start", "gauntlet", "lava_crumble", "arc_gate", "lever_lava", "star_run", "thwomp_lava", "saw_gauntlet", "lava_plats", "lava_fall", "fade_high", "goal"]},
	{"name": "THE LAST CLIMB", "chunks": ["start", "fire_steps", "castle_kick", "gauntlet", "spike_tunnel", "lava_plats", "rest", "saw_gauntlet", "ghost_hall", "bigbot_guard", "thwomp_lava", "lava_fall", "fire_hall", "goal"]},
	{"name": "KING BEAR", "boss": "king", "chunks": ["arena_king"]},
]

## Bootcamp: [chunk, coach line]. {jump} and friends are swapped for the player's real buttons.
const TUTORIAL := [
	["t_move", "WELCOME TO BOOTCAMP, BUNTY! MOVE WITH {move}."],
	["t_jump", "{jump} TO JUMP. HOLD IT TO GO HIGHER!"],
	["t_crouch", "HOLD {crouch} TO DUCK UNDER LOW ROCKS."],
	["t_dash", "TOO WIDE TO JUMP? JUMP, THEN {dash} TO DASH!"],
	["t_claw", "{attack} SWINGS YOUR CLAWS. TAP 3 TIMES FOR A COMBO!"],
	["t_stomp", "BOP BOTS ON THE HEAD, OR CLAW THEM."],
	["t_pound", "IN THE AIR, PRESS {crouch} TO GROUND POUND!"],
	["t_wall", "JUMP AT A WALL, THEN {jump} AGAIN TO KICK OFF IT!"],
	["t_shroom", "MUSHROOMS ARE EXTRA BOUNCY. LAND ON TOP!"],
	["t_lever", "{interact} PULLS LEVERS. LEVERS OPEN DOORS."],
	["t_fight", "FINAL TEST! BEAT THE BIG BOT. POUNDS HIT HARDEST!"],
	["goal", "YOU ARE READY. HOP INTO THE PORTAL!"],
]

## Rush mode (time trial): chunk pools that get harder as the run goes on.
const TRIAL_TIERS := [
	["flat", "gap", "bots", "shroom_gap", "crates", "hops", "gap_wide", "plank_bridge", "speed_run", "magnet_field", "jump_cliffs", "lift_meadow"],
	["spikes", "drills", "dash_gap", "shroom_wall", "spike_hops", "bat_field", "drill_pits", "crumble_bridge", "fade_steps", "falling_bridge", "shield_hall"],
	["ice_slide", "saw_run", "thwomps", "snow_shrooms", "dash_spikes", "moving_bridge", "saw_bridge", "bigbot", "super_springs", "fade_high"],
	["cloud_hops", "arc_gate", "ball_alley", "bat_storm", "arc_hops", "spark_bridge", "thwomp_gap", "frozen_gap", "fade_high", "falling_bridge"],
	["lava_gap", "fire_hall", "lava_crumble", "ghost_hall", "gauntlet", "thwomp_lava", "lava_plats", "bigbot_guard", "lava_fall"],
]
const TRIAL_THEMES := ["grass", "sand", "snow", "storm", "castle"]
const TRIAL_ZONES := ["BOUNCY HILLS", "DUNE DESERT", "FROST PEAKS", "THUNDER HEIGHTS", "KING'S CASTLE"]


static func world_of(level: int) -> int:
	return clampi(level / 10, 0, WORLDS.size() - 1)


static func is_boss(level: int) -> bool:
	return LEVELS[level].has("boss")


## "3-7" style label.
static func label(level: int) -> String:
	return "%d-%d" % [level / 10 + 1, level % 10 + 1]


static func chunk_width(name: String) -> int:
	var w := 0
	for row: String in CHUNKS[name]:
		w = maxi(w, row.length())
	return w
