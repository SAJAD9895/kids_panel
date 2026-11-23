# Game inventory

**What this is:** the interactive mechanics Lingokids uses, worked out from activity **names and IDs that Lingokids publishes on its own public web pages** (R1 homepage deep links, R37 English Learning page, R38 LingoCamp page) and the help center (R3, R7, R8, R20).
**What this is not:** no game was played, decompiled or recorded. Descriptions of how a mechanic plays come from Lingokids' own one-line public descriptions [V] or are inferred from the name [A].
**Clean-room rule:** record the *mechanic* (drag, trace, match) and nothing else. The clone must use original names, art, characters, audio and level content.

Legend: **[V Rn]** verified, **[A]** assumption, **[P]** proposal.

## Key finding: games are templates plus content  [A, strong evidence]

Public activity IDs follow a pattern: `game_<mechanic>_<theme>`, e.g.
`game_memory_colors`, `game_memory_pets`, `game_memory_body_parts` ·
`game_runner_ingredients`, `game_runner_vegetables`, `game_runner_disney_spiderman_computer` ·
`game_tangram_foal`, `game_tangram_kitten` · `game_steer_collect_toys`, `..._pets`, `..._rainforest` ·
`game_answer_race_sports`, `..._body` · `game_artist_playground_outerspace`, `..._castles`, `..._disney_frozen_characters` [V R1, R37].

So **one mechanic is re-skinned with many themes and word lists.** For the build this matters more than anything else: write ~12 engines and produce content as data, rather than hand-building 400 games. [P]

Non-game ID prefixes show a content taxonomy too [V R37 IDs; A for the meaning of each]:
`SG_` songs · `lk_song_` songs · `SK_` sketch (drawing) videos · `PH_` photo songs · `YO_` yoga · `DA_` dance time · `CU_` curiosity / "I Know Nothing" videos · `PU_`/`PPT_` puppet series · `lk_video_` videos · `oup_` partner content · `draw_` traceables · `numbers_N` / `words_` handwriting · `coloring_book_` colouring.

---

## Mechanics found

| # | mechanic (neutral name) | public examples (names only) | how it plays | skills | inputs | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| G01 | **Memory cards** | Memory Cards: Colors, Numbers, Pets, Feelings, Weather, Clothing… | flip pairs and match them | memory, vocabulary | tap | [V R8, R37] plays [A] |
| G02 | **Matching** | Toys Matching Game, Pets Matching Game | match item to item or colour | vocabulary, logic | tap / drag | [V R37] [A] |
| G03 | **Sticker scene** | On the Farm, Rainforest, Picnic, Travel, Closet, Face, Body Sticker Game | drag stickers to the right spot or word in a scene | vocabulary | drag | [V R37]; "Recycling Clean Up… sticker game" [V R38] |
| G04 | **Colouring book** | Coloring Book Robot, Flower | fill regions with colour | creativity, fine motor | tap / paint | [V R37] |
| G05 | **Free drawing studio** | Artist Playground (Outer Space, Castles, Explorers…) | "create pictures with backgrounds, colors and stickers" | creativity | draw / drag | [V R1, R8] |
| G06 | **Tracing (objects)** | Trousers, Bulldozer, Sun, Car, Tent Traceable | trace an outline | fine motor, pre-writing | trace | [V R37, R38]; "traceables" [V R4] |
| G07 | **Number handwriting** | 1 … 20 | trace a numeral | numeracy, writing | trace | [V R37] |
| G08 | **Word / letter writing** | Run, Jump, Boat word writing; Three Letter Writing | trace or write letters of a word | literacy, writing | trace | [V R37, R38] |
| G09 | **Quiz race** | 100 Smart Meters: Sports, Body (`answer_race`); Answer Race: Numbers Compare | answer quickly to advance in a race | numeracy, vocabulary | tap | [V R8, R37] [A] |
| G10 | **Catcher** | Wagon Catch (Technology), Bug Catcher | move to catch the right falling items | fine motor, counting | drag / tap | [V R8, R37] [A] |
| G11 | **Steer and collect** | Road Quiz: Toys, Pets, Rainforest (`steer_collect`) | steer a vehicle into the right answers | vocabulary, coordination | drag / tilt [A] | [V R37] [A] |
| G12 | **Runner** | Runner Game: Ingredients, Vegetables; Bugs Runner; Run & Spell | auto-run and collect targets, e.g. "collect letters to spell words" | vocabulary, spelling | tap / swipe | [V R1, R37, R38] |
| G13 | **Spatial puzzle (tangram)** | Spatial Puzzle: Foal, Kitten, Camel | fit shapes into a silhouette | problem solving | drag / rotate | [V R8, R37] |
| G14 | **Jigsaw / assembly puzzle** | Bus Puzzle, Toucan, Summer, Kayak Puzzle | drag pieces to build an object | spatial | drag | [V R37, R38] "Drag and drop the pieces" |
| G15 | **Packing puzzle** | Packing Puzzle; Pack your Bag Puzzle | fit objects into a container | spatial, logic | drag | [V R1, R38] |
| G16 | **Hidden objects** | Hidden Objects: Ingredients; Tent Hidden Objects | find listed objects in a busy scene | vocabulary, attention | tap | [V R8, R37, R38] |
| G17 | **Shape compare** | Catch that Match: Cars, Car Parts (`shapecompare`) | spot the matching shape among options | visual discrimination | tap | [V R37] [A] |
| G18 | **Maze** | Mystery Maze: Farm, Heart | guide a character through a maze | logic, fine motor | drag | [V R37] |
| G19 | **Path / sequence** | Sequence Path: Food; Puzzle Path Explorer; Draw Path | build or draw a path in the right order | sequencing | drag / draw | [V R35 changelog, R37, R38] |
| G20 | **Stacking** | Farm, Safari, Vehicles Stacking (`ptg_stack`) | stack items without toppling | motor, physics | drag | [V R37]; "ptg = PlayTogether" is [A] |
| G21 | **Driving** | Tractor Driving Vegetables, Boat Navigation Fruits (`ptg_driver`) | drive and collect | coordination | drag | [V R37] [A] |
| G22 | **Sort / organise** | Sort the Blocks (Halloween, Explorer); Organize Food; Laundry | sort items into groups | critical thinking, categorising | drag | [V R8, R37, R38] |
| G23 | **Discovery (reveal)** | Discovery Game Clothes; LingoCamp discovery game ("open all the tents") | open containers to reveal and name items | vocabulary | tap | [V R37, R38] |
| G24 | **Role-play kitchen and shop** | Chef Lake ("drag food onto the barbecue"), Pastry Game, Food Truck, Kitchen, Garden Shop, Grocery | prepare or serve items by dragging | vocabulary, counting | drag | [V R37, R38] |
| G25 | **Dress-up / builder** | Dress Up (character) Game, Robot Maker | assemble a character from parts | vocabulary, creativity | drag | [V R37] |
| G26 | **Rhythm / pattern dance** | Dance Contest: Fruits (`pattern_dance`) | repeat a pattern to the beat | patterns, music | tap | [V R37] [A] |
| G27 | **Letter search** | Letter Search – Forest | find letters among distractors ("don't get confused by the numbers") | letter recognition | tap | [V R38] |
| G28 | **Reading: find the word** | Reading Find Seasons, Find Home (`reading_level1_goal1_find_*`) | read a word, tap the matching picture | early reading | tap | [V R37]; the leveled ID implies a reading progression [A] |
| G29 | **Interactive reading book** | Reading Book: Let's Move (`reading_level1_goal5_book_*`) | a leveled reader | reading | tap / page | [V R37] |
| G30 | **Emotions game** | Feelings Game, Billy Emotions | identify or express feelings | SEL | tap | [V R37] |
| G31 | **Factory** | Factory (colours) | assembly line by colour | colours, logic | tap / drag | [V R37] [A] |
| G32 | **Voice echo** | Talking (robot character) | the character repeats what the child says | speaking, pronunciation | **microphone** | [V R8, R20, R38] |
| G33 | **Photo booth** | Photobooth Emotions; Polar Animals Photo Game | take photos with props or prompts | expression, creativity | **camera** | [V R20, R37] |
| G34 | **Mindfulness and breathing** | Mindfulness & Creativity Game | guided breathing, then creative play | SEL, focus | tap / hold | [V R38] |
| G35 | **Wizard game** | Wizard Game: Pets | unknown | vocabulary [A] | ? | [V R37 name only], U14 |
| G37 | **Record-your-voice stories and scenes** | "add audio to stories and scenes" | record narration onto a scene | speaking, creativity | **microphone** | [V R20] |

### Added from the owner's screenshots (`screenshot-analysis.md`)
| # | mechanic | what the screenshot shows | evidence |
| --- | --- | --- | --- |
| G20 (update) | **Stacking**: controls | **portrait** layout; a piece falls from the top; **3 big buttons: rotate left, drop, rotate right**; next-piece preview + counter bubble top-right | [SS-12] |
| G38 | **Race (lanes)** | swimming race with 4 lanes; the player's lane is marked by an arrow; crowd background; preceded by a **character pick** (S45) | [SS-13, SS-09]; input (tap/rapid tap) [A] |
| G39 | **Daily-routine scene** | a hygiene routine (tooth-brushing): drag the tool onto the character, with a **picture-in-picture close-up inset** showing the action; a story scene before it | [SS-05, SS-03]; it may be a G24 variant [A] |
| — | **HUD convention** | in all games: **close (X) top-left only**; no score, timer or pause HUD | [SS-03, 05, 12, 13, 18] |

Engine impact [P]: E12 (stacking) needs on-screen rotate and drop controls and portrait support. G38 fits E7 (lane-based arcade) with a character-pick pre-screen. G39 fits E1 (drag-to-target) with an inset-camera effect. **Every engine must declare its orientation** (landscape or portrait).

### Activity-like non-games (from the same public lists)
| type | public examples | interaction | evidence |
| --- | --- | --- | --- |
| Song / chant (video) | Hello Song, Old MacDonald, Freeze Dance, ABC Chant | watch, sing, move | [V R37, R38] |
| Photo song | Family, Wheels on the Bus, Pat-a-cake | song over photos [A] | [V R37] |
| Sketch video | Counting 1-5, Getting Dressed | draw-along video [A] | [V R37] |
| Yoga / dance time | Cat Yoga, Bear Yoga, Weather dance | follow along | [V R6, R37] |
| Curiosity / "I know nothing" | Seasons, Potato, Flavors | explainer episode | [V R8, R37] |
| Puppet series | (series about a child and puppet) | episode | [V R6, R37] |
| Audiobook | (tap-the-words story) | read or listen | [V R38] |
| Podcast | Storytime, LingoListen | listen | [V R8] |

---

## Shared engine requirements (for architecture)  [A, from the list above]

- **Input:** tap, drag-and-drop with snap targets, trace (with path tolerance), free draw, swipe/steer, hold. Mic and camera for G32, G33 and G37.
- **Physics:** light physics for stacking (G20), runner and catcher (G10, G12), driving (G21).
- **Audio:** voice-over prompts per word; correct/try-again sounds; music beat sync (G26).
- **Content model:** each game = engine ID + theme (art pack) + item list (word, image, audio) + difficulty params.
- **Completion signal:** the "main learning bit" done, then the celebration, which records a completion and awards a star [V R7].
- **Difficulty:** age band (3 levels) [V R15] and nudge-up logic [V R15].

## Proposed v1 engine set  [P]

12 engines cover most of the list, re-skinned with original content:

| v1 engine | covers |
| --- | --- |
| E1 Drag-to-target (stickers, sort, kitchen, dress-up, jigsaw) | G03, G14, G15, G22, G24, G25 |
| E2 Memory and match | G01, G02, G17 |
| E3 Trace and write | G06, G07, G08 |
| E4 Colour and draw studio | G04, G05 |
| E5 Hidden objects / find / letter search | G16, G23, G27, G28 |
| E6 Quiz (choose the answer, timed or untimed) | G09, G30, check-ins (S19) |
| E7 Runner / catcher (lane-based arcade) | G10, G11, G12, G21 |
| E8 Tangram / shape fit | G13 |
| E9 Maze and path | G18, G19 |
| E10 Interactive book reader | G29, audiobooks |
| E11 Rhythm / pattern | G26 |
| E12 Stacking (physics) | G20 |

Later: voice echo (G32), photo booth (G33), record-your-voice (G37). They need mic and camera permission work and extra child-privacy review, since they record a child's voice or face.
