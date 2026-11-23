-- =============================================================================
-- Content pack 02: 9 games and 5 courses (2026-11-23). Content only: no users, no families.
-- Generated; game configs are validated by web_app/test/unit/engine-session.test.ts
-- ("content packs"), which reads the `-- engine:<slug>` lines below.
-- Apply once, after the migrations and seed content:
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 --single-transaction -f supabase/content/pack-02-courses-and-games.sql
-- =============================================================================
do $$ begin
  if exists (select 1 from activities where slug = 'animal-friends') or exists (select 1 from courses where slug = 'animals-all-around') then
    raise exception 'content pack 02 is already loaded';
  end if;
end $$;

-- Games (learning engine, free to play, placeholder thumbnail)
insert into activities (slug, type, title, description, keywords, subject_id, thumbnail_asset_id,
                        age_min_months, age_max_months, difficulty, players, estimated_seconds, plus_only, free_eligible, status, published_at)
values
  ('animal-friends', 'game', '{"en": "Animal friends"}', '{"en": "Find the animals, hear what they say and match their names"}', 'animals sounds names', (select id from subjects where key = 'nature'),
   (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'), 24, 84, 1, 1, 240, false, true, 'published', now()),
  ('fruit-market', 'game', '{"en": "Fruit market"}', '{"en": "Count the fruit, then add and take away"}', 'counting adding take away fruit', (select id from subjects where key = 'numbers'),
   (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'), 30, 96, 2, 1, 300, false, true, 'published', now()),
  ('colour-sort', 'game', '{"en": "Colour sort"}', '{"en": "Put each thing with its colour"}', 'colours sorting red blue yellow green', (select id from subjects where key = 'art'),
   (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'), 24, 84, 1, 1, 240, false, true, 'published', now()),
  ('big-and-small', 'game', '{"en": "Big and small"}', '{"en": "Find the big ones and the small ones"}', 'big small size compare', (select id from subjects where key = 'thinking'),
   (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'), 24, 72, 1, 1, 180, false, true, 'published', now()),
  ('letter-sounds-safari', 'game', '{"en": "Letter sounds safari"}', '{"en": "Hear the sounds letters make and find the first sound of words"}', 'phonics letter sounds first sound', (select id from subjects where key = 'letters'),
   (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'), 36, 96, 2, 1, 300, false, true, 'published', now()),
  ('shape-detective', 'game', '{"en": "Shape detective"}', '{"en": "Name the shapes, finish them and spot round things"}', 'shapes circle square triangle star', (select id from subjects where key = 'shapes'),
   (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'), 24, 84, 1, 1, 240, false, true, 'published', now()),
  ('spell-it', 'game', '{"en": "Spell it"}', '{"en": "Look at the picture and build its word"}', 'spelling words letters', (select id from subjects where key = 'english'),
   (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'), 48, 108, 2, 1, 240, false, true, 'published', now()),
  ('where-do-they-live', 'game', '{"en": "Where do they live?"}', '{"en": "Help each animal find its home"}', 'animals homes habitats', (select id from subjects where key = 'nature'),
   (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'), 30, 96, 1, 1, 200, false, true, 'published', now()),
  ('trace-and-count', 'game', '{"en": "Trace and count"}', '{"en": "Trace the numbers 1 to 9 and count the stars"}', 'numbers tracing counting writing', (select id from subjects where key = 'numbers'),
   (select id from media_assets where object_path = 'thumbs/placeholder/1/512.webp'), 36, 96, 2, 1, 300, false, true, 'published', now());
insert into games (activity_id, template_id, config)
select a.id, (select id from game_templates where key = 'learning_engine' and version = '1.0.0'), '{}' from activities a where a.slug in ('animal-friends', 'fruit-market', 'colour-sort', 'big-and-small', 'letter-sounds-safari', 'shape-detective', 'spell-it', 'where-do-they-live', 'trace-and-count');
insert into activity_skills (activity_id, skill_id, weight, is_primary)
select a.id, s.id, 1, true from (values
  ('animal-friends', 'vocabulary'),
  ('fruit-market', 'counting'),
  ('colour-sort', 'sorting'),
  ('big-and-small', 'comparing'),
  ('letter-sounds-safari', 'letter_sounds'),
  ('shape-detective', 'shape_names'),
  ('spell-it', 'vocabulary'),
  ('where-do-they-live', 'sorting'),
  ('trace-and-count', 'counting')
) as x(slug, skill) join activities a on a.slug = x.slug join skills s on s.key = x.skill;
update games set config = '{"intro":{"text":"Animal friends","speak":"Let''s meet some animals! Listen, look and tap."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"audio_choice","prompt":{"speak":"Find the cat."},"correct":["cat"],"options":[{"id":"cat","label":"cat","picture":"icon:cat"},{"id":"dog","label":"dog","picture":"icon:dog"},{"id":"duck","label":"duck","picture":"icon:duck"}]},{"kind":"audio_choice","prompt":{"speak":"Find the fish."},"correct":["fish"],"options":[{"id":"fish","label":"fish","picture":"icon:fish"},{"id":"bird","label":"bird","picture":"icon:bird"},{"id":"cow","label":"cow","picture":"icon:cow"}]},{"kind":"image_choice","prompt":{"text":"Which one says moo?","speak":"Which animal says moo?"},"correct":["cow"],"options":[{"id":"cow","label":"cow","picture":"icon:cow"},{"id":"duck","label":"duck","picture":"icon:duck"},{"id":"cat","label":"cat","picture":"icon:cat"}]},{"kind":"image_choice","prompt":{"text":"Which one can swim?","speak":"Which one lives in the water and swims?"},"correct":["fish"],"options":[{"id":"fish","label":"fish","picture":"icon:fish"},{"id":"dog","label":"dog","picture":"icon:dog"},{"id":"cow","label":"cow","picture":"icon:cow"}]}],"options":3},{"id":"medium","label":"Medium","minAgeMonths":48,"items":[{"kind":"fill_blank","sentence":"The duck says ___","picture":"icon:duck","correct":"quack","options":[{"id":"quack","label":"quack"},{"id":"moo","label":"moo"},{"id":"woof","label":"woof"}]},{"kind":"fill_blank","sentence":"The dog says ___","picture":"icon:dog","correct":"woof","options":[{"id":"woof","label":"woof"},{"id":"meow","label":"meow"},{"id":"quack","label":"quack"}]},{"kind":"match_pairs","prompt":{"text":"Match the word to the animal"},"pairs":[{"left":{"label":"cat"},"right":{"label":"cat","picture":"icon:cat"}},{"left":{"label":"dog"},"right":{"label":"dog","picture":"icon:dog"}},{"left":{"label":"duck"},"right":{"label":"duck","picture":"icon:duck"}}]},{"kind":"image_choice","prompt":{"text":"Which one has wings?"},"correct":["bird"],"options":[{"id":"bird","label":"bird","picture":"icon:bird"},{"id":"fish","label":"fish","picture":"icon:fish"},{"id":"cow","label":"cow","picture":"icon:cow"},{"id":"dog","label":"dog","picture":"icon:dog"}]}],"options":3},{"id":"hard","label":"Hard","minAgeMonths":72,"items":[{"kind":"fill_blank","sentence":"The cat says ___","picture":"icon:cat","correct":"meow","options":[{"id":"meow","label":"meow"},{"id":"moo","label":"moo"},{"id":"quack","label":"quack"},{"id":"woof","label":"woof"}]},{"kind":"match_pairs","prompt":{"text":"Match the word to the animal"},"pairs":[{"left":{"label":"cow"},"right":{"label":"cow","picture":"icon:cow"}},{"left":{"label":"fish"},"right":{"label":"fish","picture":"icon:fish"}},{"left":{"label":"bird"},"right":{"label":"bird","picture":"icon:bird"}},{"left":{"label":"duck"},"right":{"label":"duck","picture":"icon:duck"}}]},{"kind":"multiple_choice","prompt":{"text":"Which animal lives in the water?"},"hint":"It has fins and swims.","correct":["fish"],"options":[{"id":"fish","label":"fish"},{"id":"cow","label":"cow"},{"id":"dog","label":"dog"}]},{"kind":"sort","prompt":{"text":"Can it fly?","speak":"Put the animals that can fly on one side, and the ones that can''t on the other."},"bins":[{"id":"fly","label":"Can fly","picture":"icon:bird"},{"id":"walk","label":"Can''t fly","picture":"icon:cow"}],"items":[{"id":"bird","bin":"fly","label":"bird","picture":"icon:bird"},{"id":"duck","bin":"fly","label":"duck","picture":"icon:duck"},{"id":"dog","bin":"walk","label":"dog","picture":"icon:dog"},{"id":"cat","bin":"walk","label":"cat","picture":"icon:cat"}]}],"options":4}]}'::jsonb -- engine:animal-friends
where activity_id = (select id from activities where slug = 'animal-friends');
update games set config = '{"intro":{"text":"Fruit market","speak":"Welcome to the market! Let''s count the fruit."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"number_recognition","count":2,"picture":"icon:apple"},{"kind":"number_recognition","count":3,"picture":"icon:banana"},{"kind":"number_recognition","count":4,"picture":"icon:carrot"},{"kind":"number_recognition","count":1,"picture":"icon:apple"}],"options":3},{"id":"medium","label":"Medium","minAgeMonths":48,"items":[{"kind":"number_recognition","count":5,"picture":"icon:apple"},{"kind":"number_recognition","count":6,"picture":"icon:banana"},{"kind":"arithmetic","a":2,"op":"+","b":1,"picture":"icon:apple"},{"kind":"arithmetic","a":3,"op":"+","b":2,"picture":"icon:banana"}],"options":3},{"id":"hard","label":"Hard","minAgeMonths":72,"items":[{"kind":"arithmetic","a":4,"op":"-","b":2,"picture":"icon:apple"},{"kind":"arithmetic","a":5,"op":"+","b":3,"picture":"icon:carrot"},{"kind":"number_recognition","target":9,"distractors":[6,8,7]},{"kind":"arithmetic","a":6,"op":"-","b":3,"picture":"icon:banana"}],"options":4}]}'::jsonb -- engine:fruit-market
where activity_id = (select id from activities where slug = 'fruit-market');
update games set config = '{"intro":{"text":"Colour sort","speak":"Look at the colours and put each one where it belongs."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"sort","prompt":{"text":"Red or blue?","speak":"Put the red things with the red ball, and the blue things with the blue ball."},"bins":[{"id":"red","label":"Red","picture":"icon:ball?color=red"},{"id":"blue","label":"Blue","picture":"icon:ball?color=blue"}],"items":[{"id":"apple-red","bin":"red","label":"red apple","picture":"icon:apple?color=red"},{"id":"car-blue","bin":"blue","label":"blue car","picture":"icon:car?color=blue"},{"id":"flower-red","bin":"red","label":"red flower","picture":"icon:flower?color=red"},{"id":"sailboat-blue","bin":"blue","label":"blue sailboat","picture":"icon:sailboat?color=blue"}]},{"kind":"image_choice","prompt":{"text":"Which one is red?"},"correct":["apple-red"],"options":[{"id":"apple-red","label":"red apple","picture":"icon:apple?color=red"},{"id":"ball-blue","label":"blue ball","picture":"icon:ball?color=blue"},{"id":"flower-yellow","label":"yellow flower","picture":"icon:flower?color=yellow"}]}],"options":3},{"id":"medium","label":"Medium","minAgeMonths":48,"items":[{"kind":"sort","prompt":{"text":"Red, yellow or green?","speak":"Sort the things by colour."},"bins":[{"id":"red","label":"Red","picture":"icon:ball?color=red"},{"id":"yellow","label":"Yellow","picture":"icon:ball?color=yellow"},{"id":"green","label":"Green","picture":"icon:ball?color=green"}],"items":[{"id":"banana-yellow","bin":"yellow","label":"yellow banana","picture":"icon:banana?color=yellow"},{"id":"apple-red","bin":"red","label":"red apple","picture":"icon:apple?color=red"},{"id":"flower-yellow","bin":"yellow","label":"yellow flower","picture":"icon:flower?color=yellow"},{"id":"ball-green","bin":"green","label":"green ball","picture":"icon:ball?color=green"},{"id":"car-red","bin":"red","label":"red car","picture":"icon:car?color=red"},{"id":"tree-green","bin":"green","label":"green tree","picture":"icon:tree?color=green"}]},{"kind":"image_choice","prompt":{"text":"Which one is yellow?"},"correct":["sun"],"options":[{"id":"sun","label":"sun","picture":"icon:sun"},{"id":"apple-red","label":"red apple","picture":"icon:apple?color=red"},{"id":"ball-blue","label":"blue ball","picture":"icon:ball?color=blue"}]}],"options":3},{"id":"hard","label":"Hard","minAgeMonths":72,"items":[{"kind":"sort","prompt":{"text":"Four colours","speak":"Sort the things into red, blue, yellow and green."},"bins":[{"id":"red","label":"Red","picture":"icon:ball?color=red"},{"id":"blue","label":"Blue","picture":"icon:ball?color=blue"},{"id":"yellow","label":"Yellow","picture":"icon:ball?color=yellow"},{"id":"green","label":"Green","picture":"icon:ball?color=green"}],"items":[{"id":"apple-red","bin":"red","label":"red apple","picture":"icon:apple?color=red"},{"id":"car-blue","bin":"blue","label":"blue car","picture":"icon:car?color=blue"},{"id":"banana-yellow","bin":"yellow","label":"yellow banana","picture":"icon:banana?color=yellow"},{"id":"tree-green","bin":"green","label":"green tree","picture":"icon:tree?color=green"},{"id":"flower-red","bin":"red","label":"red flower","picture":"icon:flower?color=red"},{"id":"sailboat-blue","bin":"blue","label":"blue sailboat","picture":"icon:sailboat?color=blue"},{"id":"ball-yellow","bin":"yellow","label":"yellow ball","picture":"icon:ball?color=yellow"},{"id":"cake-green","bin":"green","label":"green cake","picture":"icon:cake?color=green"}]},{"kind":"image_choice","prompt":{"text":"Find the green one"},"correct":["ball-green"],"options":[{"id":"ball-green","label":"green ball","picture":"icon:ball?color=green"},{"id":"ball-red","label":"red ball","picture":"icon:ball?color=red"},{"id":"ball-blue","label":"blue ball","picture":"icon:ball?color=blue"},{"id":"ball-yellow","label":"yellow ball","picture":"icon:ball?color=yellow"}]}],"options":4}]}'::jsonb -- engine:colour-sort
where activity_id = (select id from activities where slug = 'colour-sort');
update games set config = '{"intro":{"text":"Big and small","speak":"Some things are big and some are small. Can you tell which is which?"},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"image_choice","prompt":{"text":"Which one is big?"},"correct":["apple-big"],"options":[{"id":"apple-big","label":"big apple","picture":"icon:apple?size=big"},{"id":"apple-small","label":"small apple","picture":"icon:apple?size=small"}]},{"kind":"image_choice","prompt":{"text":"Which one is small?"},"correct":["ball-small"],"options":[{"id":"ball-big","label":"big ball","picture":"icon:ball?size=big"},{"id":"ball-small","label":"small ball","picture":"icon:ball?size=small"}]},{"kind":"image_choice","prompt":{"text":"Which one is big?"},"correct":["house-big"],"options":[{"id":"house-small","label":"small house","picture":"icon:house?size=small"},{"id":"house-big","label":"big house","picture":"icon:house?size=big"}]}],"options":2},{"id":"medium","label":"Medium","minAgeMonths":48,"items":[{"kind":"sort","prompt":{"text":"Big or small?","speak":"Put the big things on one side and the small things on the other."},"bins":[{"id":"big","label":"Big","picture":"icon:star?size=big"},{"id":"small","label":"Small","picture":"icon:star?size=small"}],"items":[{"id":"apple-big","bin":"big","label":"big apple","picture":"icon:apple?size=big"},{"id":"ball-small","bin":"small","label":"small ball","picture":"icon:ball?size=small"},{"id":"cake-big","bin":"big","label":"big cake","picture":"icon:cake?size=big"},{"id":"fish-small","bin":"small","label":"small fish","picture":"icon:fish?size=small"}]},{"kind":"image_choice","prompt":{"text":"Which one is small?"},"correct":["duck-small"],"options":[{"id":"duck-big","label":"big duck","picture":"icon:duck?size=big"},{"id":"duck-small","label":"small duck","picture":"icon:duck?size=small"}]}],"options":2},{"id":"hard","label":"Hard","minAgeMonths":72,"items":[{"kind":"image_choice","prompt":{"text":"Which is the smallest?"},"correct":["cake-small"],"options":[{"id":"cake-big","label":"big cake","picture":"icon:cake?size=big"},{"id":"cake-medium","label":"medium cake","picture":"icon:cake?size=medium"},{"id":"cake-small","label":"small cake","picture":"icon:cake?size=small"}]},{"kind":"image_choice","prompt":{"text":"Which is the biggest?"},"correct":["fish-big"],"options":[{"id":"fish-small","label":"small fish","picture":"icon:fish?size=small"},{"id":"fish-big","label":"big fish","picture":"icon:fish?size=big"},{"id":"fish-medium","label":"medium fish","picture":"icon:fish?size=medium"}]},{"kind":"image_choice","prompt":{"text":"Which is in the middle?","speak":"Which one is not the biggest and not the smallest?"},"correct":["tree-medium"],"options":[{"id":"tree-small","label":"small tree","picture":"icon:tree?size=small"},{"id":"tree-medium","label":"medium tree","picture":"icon:tree?size=medium"},{"id":"tree-big","label":"big tree","picture":"icon:tree?size=big"}]}],"options":3}]}'::jsonb -- engine:big-and-small
where activity_id = (select id from activities where slug = 'big-and-small');
update games set config = '{"intro":{"text":"Letter sounds safari","speak":"Every letter makes a sound. Let''s go on a sound safari!"},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"letter_recognition","target":"a"},{"kind":"letter_recognition","target":"s","mode":"sound"},{"kind":"image_choice","prompt":{"text":"Which one starts with b?","speak":"Which one starts with the sound buh?"},"correct":["ball"],"options":[{"id":"ball","label":"ball","picture":"icon:ball"},{"id":"cat","label":"cat","picture":"icon:cat"},{"id":"sun","label":"sun","picture":"icon:sun"}]},{"kind":"letter_recognition","target":"m","mode":"sound"}],"options":3},{"id":"medium","label":"Medium","minAgeMonths":48,"items":[{"kind":"letter_recognition","target":"t","mode":"sound"},{"kind":"image_choice","prompt":{"text":"Which one starts with d?","speak":"Which one starts with the sound duh?"},"correct":["dog"],"options":[{"id":"dog","label":"dog","picture":"icon:dog"},{"id":"fish","label":"fish","picture":"icon:fish"},{"id":"cake","label":"cake","picture":"icon:cake"}]},{"kind":"image_choice","prompt":{"text":"Which one starts with s?","speak":"Which one starts with the sound sss?"},"correct":["sun"],"options":[{"id":"sun","label":"sun","picture":"icon:sun"},{"id":"moon","label":"moon","picture":"icon:moon"},{"id":"car","label":"car","picture":"icon:car"}]},{"kind":"letter_recognition","target":"B","mode":"case"}],"options":3},{"id":"hard","label":"Hard","minAgeMonths":72,"items":[{"kind":"image_choice","prompt":{"text":"Which one starts with f?","speak":"Which one starts with the sound fff?"},"correct":["fish"],"options":[{"id":"fish","label":"fish","picture":"icon:fish"},{"id":"ball","label":"ball","picture":"icon:ball"},{"id":"cow","label":"cow","picture":"icon:cow"},{"id":"tree","label":"tree","picture":"icon:tree"}]},{"kind":"letter_recognition","target":"r","mode":"sound"},{"kind":"word_build","word":"fish","picture":"icon:fish"},{"kind":"word_build","word":"duck","picture":"icon:duck"}],"options":4}]}'::jsonb -- engine:letter-sounds-safari
where activity_id = (select id from activities where slug = 'letter-sounds-safari');
update games set config = '{"intro":{"text":"Shape detective","speak":"Put on your detective hat! Let''s find the shapes."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"image_choice","prompt":{"text":"Find the circle"},"correct":["circle"],"options":[{"id":"circle","label":"circle","picture":"shape:circle"},{"id":"square","label":"square","picture":"shape:square"},{"id":"triangle","label":"triangle","picture":"shape:triangle"}]},{"kind":"image_choice","prompt":{"text":"Find the star"},"correct":["star"],"options":[{"id":"star","label":"star","picture":"shape:star"},{"id":"heart","label":"heart","picture":"shape:heart"},{"id":"circle","label":"circle","picture":"shape:circle"}]},{"kind":"image_choice","prompt":{"text":"Find the triangle"},"correct":["triangle"],"options":[{"id":"square","label":"square","picture":"shape:square"},{"id":"triangle","label":"triangle","picture":"shape:triangle"},{"id":"heart","label":"heart","picture":"shape:heart"}]}],"options":3},{"id":"medium","label":"Medium","minAgeMonths":48,"items":[{"kind":"shape_complete","shape":"circle","missing":"right","distractors":["square","triangle"]},{"kind":"shape_complete","shape":"square","missing":"left","distractors":["circle","star"]},{"kind":"image_choice","prompt":{"text":"Which one is round?"},"correct":["ball"],"options":[{"id":"ball","label":"ball","picture":"icon:ball"},{"id":"house","label":"house","picture":"icon:house"},{"id":"triangle","label":"triangle","picture":"shape:triangle"}]}],"options":3},{"id":"hard","label":"Hard","minAgeMonths":72,"items":[{"kind":"sort","prompt":{"text":"Round or corners?","speak":"Put the round things on one side and the things with corners on the other."},"bins":[{"id":"round","label":"Round","picture":"shape:circle"},{"id":"corners","label":"Corners","picture":"shape:square"}],"items":[{"id":"sun","bin":"round","label":"sun","picture":"icon:sun"},{"id":"apple","bin":"round","label":"apple","picture":"icon:apple"},{"id":"house","bin":"corners","label":"house","picture":"icon:house"},{"id":"triangle","bin":"corners","label":"triangle","picture":"shape:triangle"}]},{"kind":"shape_complete","shape":"heart","missing":"top","distractors":["star","circle"]},{"kind":"shape_complete","shape":"triangle","missing":"bottom","distractors":["square","heart"]}],"options":3}]}'::jsonb -- engine:shape-detective
where activity_id = (select id from activities where slug = 'shape-detective');
update games set config = '{"intro":{"text":"Spell it","speak":"Look at the picture, then tap the letters in order to spell its name."},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"word_build","word":"cow","picture":"icon:cow"},{"kind":"word_build","word":"car","picture":"icon:car"},{"kind":"word_build","word":"sun","picture":"icon:sun"}]},{"id":"medium","label":"Medium","minAgeMonths":60,"items":[{"kind":"word_build","word":"ball","picture":"icon:ball"},{"kind":"word_build","word":"cake","picture":"icon:cake"},{"kind":"word_build","word":"duck","picture":"icon:duck"},{"kind":"word_build","word":"fish","picture":"icon:fish"}]},{"id":"hard","label":"Hard","minAgeMonths":78,"items":[{"kind":"word_build","word":"house","picture":"icon:house"},{"kind":"word_build","word":"apple","picture":"icon:apple"},{"kind":"word_build","word":"flower","picture":"icon:flower"}]}]}'::jsonb -- engine:spell-it
where activity_id = (select id from activities where slug = 'spell-it');
update games set config = '{"intro":{"text":"Where do they live?","speak":"The animals are lost! Can you help them get home?"},"levels":[{"id":"easy","label":"Easy","minAgeMonths":0,"items":[{"kind":"drag_to_target","prompt":{"text":"Who lives where?","speak":"Drag each animal to its home."},"tokens":[{"id":"fish","label":"fish","picture":"icon:fish"},{"id":"bird","label":"bird","picture":"icon:bird"}],"targets":[{"id":"water","label":"water","picture":"icon:water"},{"id":"tree","label":"tree","picture":"icon:tree"}],"solution":{"fish":"water","bird":"tree"}},{"kind":"image_choice","prompt":{"text":"Who lives in the water?"},"correct":["fish"],"options":[{"id":"fish","label":"fish","picture":"icon:fish"},{"id":"cow","label":"cow","picture":"icon:cow"},{"id":"dog","label":"dog","picture":"icon:dog"}]}],"options":3},{"id":"medium","label":"Medium","minAgeMonths":48,"items":[{"kind":"drag_to_target","prompt":{"text":"Who lives where?","speak":"Drag each animal to its home."},"tokens":[{"id":"fish","label":"fish","picture":"icon:fish"},{"id":"bird","label":"bird","picture":"icon:bird"},{"id":"dog","label":"dog","picture":"icon:dog"}],"targets":[{"id":"water","label":"water","picture":"icon:water"},{"id":"tree","label":"tree","picture":"icon:tree"},{"id":"house","label":"house","picture":"icon:house"}],"solution":{"fish":"water","bird":"tree","dog":"house"}},{"kind":"image_choice","prompt":{"text":"Who lives in a tree?"},"correct":["bird"],"options":[{"id":"bird","label":"bird","picture":"icon:bird"},{"id":"cow","label":"cow","picture":"icon:cow"},{"id":"fish","label":"fish","picture":"icon:fish"}]}],"options":3},{"id":"hard","label":"Hard","minAgeMonths":72,"items":[{"kind":"drag_to_target","prompt":{"text":"Who lives where?","speak":"Drag each animal to its home."},"tokens":[{"id":"fish","label":"fish","picture":"icon:fish"},{"id":"bird","label":"bird","picture":"icon:bird"},{"id":"cat","label":"cat","picture":"icon:cat"}],"targets":[{"id":"water","label":"water","picture":"icon:water"},{"id":"tree","label":"tree","picture":"icon:tree"},{"id":"house","label":"house","picture":"icon:house"}],"solution":{"fish":"water","bird":"tree","cat":"house"}},{"kind":"multiple_choice","prompt":{"text":"Where does a duck like to swim?"},"hint":"Ducks paddle with their feet.","correct":["water"],"options":[{"id":"water","label":"water"},{"id":"tree","label":"tree"},{"id":"house","label":"house"}]},{"kind":"sort","prompt":{"text":"Water or land?","speak":"Which animals swim in the water, and which walk on land?"},"bins":[{"id":"water","label":"Water","picture":"icon:water"},{"id":"land","label":"Land","picture":"icon:tree"}],"items":[{"id":"fish","bin":"water","label":"fish","picture":"icon:fish"},{"id":"cow","bin":"land","label":"cow","picture":"icon:cow"},{"id":"dog","bin":"land","label":"dog","picture":"icon:dog"}]}],"options":3}]}'::jsonb -- engine:where-do-they-live
where activity_id = (select id from activities where slug = 'where-do-they-live');
update games set config = '{"intro":{"text":"Trace and count","speak":"Trace each number with your finger, then count the stars."},"levels":[{"id":"easy","label":"1 to 3","minAgeMonths":0,"items":[{"kind":"trace","glyph":"1"},{"kind":"trace","glyph":"2"},{"kind":"trace","glyph":"3"},{"kind":"number_recognition","count":3,"picture":"icon:star"}],"options":3},{"id":"medium","label":"4 to 6","minAgeMonths":48,"items":[{"kind":"trace","glyph":"4"},{"kind":"trace","glyph":"5"},{"kind":"trace","glyph":"6"},{"kind":"number_recognition","count":6,"picture":"icon:star"}],"options":3},{"id":"hard","label":"7 to 9","minAgeMonths":72,"items":[{"kind":"trace","glyph":"7"},{"kind":"trace","glyph":"8"},{"kind":"trace","glyph":"9"},{"kind":"number_recognition","count":8,"picture":"icon:star"}],"options":4}]}'::jsonb -- engine:trace-and-count
where activity_id = (select id from activities where slug = 'trace-and-count');

-- A home row for the new games
insert into collections (slug, surface, kind, title, sort, status) values ('new-games', 'home', 'row', '{"en":"New games"}', 3, 'published');
insert into collection_items (collection_id, activity_id, position)
select (select id from collections where slug = 'new-games'), a.id, x.p from (values
  ('animal-friends', 0),
  ('fruit-market', 1),
  ('colour-sort', 2),
  ('big-and-small', 3),
  ('letter-sounds-safari', 4),
  ('shape-detective', 5),
  ('spell-it', 6),
  ('where-do-they-live', 7),
  ('trace-and-count', 8)
) as x(slug, p) join activities a on a.slug = x.slug;

-- Courses: one workbook each, lessons (islands) and their steps
insert into courses (slug, kind, title, description, subject_id, primary_skill_id, stage, difficulty, plus_only, sort, status, published_at)
values ('animals-all-around', 'solo', '{"en": "Animals all around"}', '{"en": "Meet the animals, hear their sounds and find their homes"}', (select id from subjects where key = 'nature'), (select id from skills where key = 'vocabulary'),
        'preschool', 1, false, 10, 'published', now());
insert into course_modules (course_id, position, title) values ((select id from courses where slug = 'animals-all-around'), 0, '{"en":"Workbook 1"}');
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 0, '{"en": "Island 1: Meet the animals"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'animals-all-around' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'intro', 'pip-meets-a-snail'), (1, 'practice', 'animal-friends')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 0 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'animals-all-around';
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 1, '{"en": "Island 2: Animal homes"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'animals-all-around' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'practice', 'where-do-they-live'), (1, 'review', 'animal-friends')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 1 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'animals-all-around';
insert into courses (slug, kind, title, description, subject_id, primary_skill_id, stage, difficulty, plus_only, sort, status, published_at)
values ('colours-and-sizes', 'solo', '{"en": "Colours and sizes"}', '{"en": "Sort by colour and tell big from small"}', (select id from subjects where key = 'art'), (select id from skills where key = 'sorting'),
        'toddler', 1, false, 11, 'published', now());
insert into course_modules (course_id, position, title) values ((select id from courses where slug = 'colours-and-sizes'), 0, '{"en":"Workbook 1"}');
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 0, '{"en": "Island 1: Rainbow colours"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'colours-and-sizes' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'intro', 'rainbow-colours'), (1, 'practice', 'colour-sort')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 0 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'colours-and-sizes';
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 1, '{"en": "Island 2: Big and small"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'colours-and-sizes' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'practice', 'big-and-small'), (1, 'review', 'colour-sort')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 1 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'colours-and-sizes';
insert into courses (slug, kind, title, description, subject_id, primary_skill_id, stage, difficulty, plus_only, sort, status, published_at)
values ('letter-sounds', 'solo', '{"en": "Letter sounds"}', '{"en": "Hear what letters say and build your first words"}', (select id from subjects where key = 'letters'), (select id from skills where key = 'letter_sounds'),
        'kindergarten', 2, false, 12, 'published', now());
insert into course_modules (course_id, position, title) values ((select id from courses where slug = 'letter-sounds'), 0, '{"en":"Workbook 1"}');
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 0, '{"en": "Island 1: First sounds"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'letter-sounds' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'practice', 'letter-sounds-safari'), (1, 'trace', 'trace-a-to-h')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 0 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'letter-sounds';
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 1, '{"en": "Island 2: Build words"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'letter-sounds' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'practice', 'spell-it'), (1, 'review', 'word-builder')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 1 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'letter-sounds';
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 2, '{"en": "Island 3: Sound check"}', 4 from course_modules m join courses c on c.id = m.course_id where c.slug = 'letter-sounds' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'knowledge_check', 'letter-sounds-safari')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 2 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'letter-sounds';
insert into courses (slug, kind, title, description, subject_id, primary_skill_id, stage, difficulty, plus_only, sort, status, published_at)
values ('count-add-take-away', 'solo', '{"en": "Count, add and take away"}', '{"en": "Trace numbers, count things, then add and take away"}', (select id from subjects where key = 'numbers'), (select id from skills where key = 'counting'),
        'kindergarten', 2, false, 13, 'published', now());
insert into course_modules (course_id, position, title) values ((select id from courses where slug = 'count-add-take-away'), 0, '{"en":"Workbook 1"}');
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 0, '{"en": "Island 1: Count and trace"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'count-add-take-away' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'trace', 'trace-and-count'), (1, 'song', 'counting-train')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 0 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'count-add-take-away';
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 1, '{"en": "Island 2: Market maths"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'count-add-take-away' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'practice', 'fruit-market'), (1, 'review', 'number-fun')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 1 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'count-add-take-away';
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 2, '{"en": "Island 3: Story time"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'count-add-take-away' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'story', 'nova-counts-the-stars'), (1, 'knowledge_check', 'fruit-market')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 2 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'count-add-take-away';
insert into courses (slug, kind, title, description, subject_id, primary_skill_id, stage, difficulty, plus_only, sort, status, published_at)
values ('shape-detectives', 'solo', '{"en": "Shape detectives"}', '{"en": "Find, finish and sort shapes"}', (select id from subjects where key = 'shapes'), (select id from skills where key = 'shape_names'),
        'preschool', 1, false, 14, 'published', now());
insert into course_modules (course_id, position, title) values ((select id from courses where slug = 'shape-detectives'), 0, '{"en":"Workbook 1"}');
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 0, '{"en": "Island 1: Spot the shapes"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'shape-detectives' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'intro', 'shapes-all-around'), (1, 'practice', 'shape-detective')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 0 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'shape-detectives';
insert into lessons (module_id, position, title, estimated_minutes)
select m.id, 1, '{"en": "Island 2: Shape puzzles"}', 8 from course_modules m join courses c on c.id = m.course_id where c.slug = 'shape-detectives' and m.position = 0;
insert into lesson_steps (lesson_id, position, step_type, activity_id)
select l.id, x.pos, x.st, a.id from (values (0, 'practice', 'puzzle-time'), (1, 'review', 'shape-detective')) as x(pos, st, act)
join activities a on a.slug = x.act
join lessons l on l.position = 1 join course_modules m on m.id = l.module_id and m.position = 0 join courses c on c.id = m.course_id and c.slug = 'shape-detectives';

-- Learning paths
insert into learning_paths (slug, title, description, stage, age_min_months, age_max_months, status)
values ('school-ready', '{"en":"Ready for school"}', '{"en":"Letter sounds, words and numbers for big kids"}', 'kindergarten', 60, 96, 'published');
insert into learning_path_courses (path_id, course_id, position)
select p.id, c.id, (select coalesce(max(position) + 1, 0) from learning_path_courses where path_id = p.id) + x.n
from (values ('colours-and-sizes', 0), ('animals-all-around', 1)) as x(slug, n)
join courses c on c.slug = x.slug join learning_paths p on p.slug = 'little-steps';
insert into learning_path_courses (path_id, course_id, position)
select p.id, c.id, (select coalesce(max(position) + 1, 0) from learning_path_courses where path_id = p.id) + x.n
from (values ('shape-detectives', 0)) as x(slug, n)
join courses c on c.slug = x.slug join learning_paths p on p.slug = 'preschool-start';
insert into learning_path_courses (path_id, course_id, position)
select p.id, c.id, (select coalesce(max(position) + 1, 0) from learning_path_courses where path_id = p.id) + x.n
from (values ('letter-sounds', 0), ('count-add-take-away', 1)) as x(slug, n)
join courses c on c.slug = x.slug join learning_paths p on p.slug = 'school-ready';

do $$ declare n int; begin
  select count(*) into n from lesson_steps st join lessons l on l.id = st.lesson_id join course_modules m on m.id = l.module_id join courses c on c.id = m.course_id
  where c.slug in ('animals-all-around', 'colours-and-sizes', 'letter-sounds', 'count-add-take-away', 'shape-detectives');
  if n <> 23 then raise exception 'pack 02: expected 23 lesson steps, got %', n; end if;
end $$;
