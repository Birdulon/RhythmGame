#extends Object
extends Node
var FileHelpers := preload('res://scripts/FileHelpers.gd')

var RGT := preload('res://formats/RGT.gd')
var SM := preload('res://formats/SM.gd')
var SRT := preload('res://formats/SRT.gd')

const NOT_FOUND := ''

const default_difficulty_keys = ['Z', 'B', 'A', 'E', 'M', 'R']

var userroot := OS.get_user_data_dir().rstrip('/')+'/' if OS.get_name() != 'Android' else '/storage/emulated/0/RhythmGame/'
var PATHS := PoolStringArray([userroot, '/media/fridge-q/Games/RTG/slow_userdir/'])  # Temporary hardcoded testing
# The following would probably work. One huge caveat is that permission needs to be manually granted by the user in app settings as we can't use OS.request_permission('WRITE_EXTERNAL_STORAGE')
# '/storage/emulated/0/Android/data/au.ufeff.rhythmgame/'
# '/sdcard/Android/data/au.ufeff.rhythmgame/'
func _ready() -> void:
	print('Library paths: ', PATHS)


func find_file(name: String, print_notfound:=false) -> String:
	# Searches through all of the paths to find the file
	var file := File.new()
	for root in PATHS:
		var filename: String = root + name
		if file.file_exists(filename):
			return filename
	if print_notfound:
		print('File not found in any libraries: ', name)
	return NOT_FOUND


var fallback_audiostream = AudioStreamOGGVorbis.new()
var fallback_videostream = VideoStreamWebm.new()
var fallback_texture := ImageTexture.new()

func load_ogg(name: String) -> AudioStreamOGGVorbis:  # Searches through all of the paths to find the file
	match find_file(name):
		NOT_FOUND: return fallback_audiostream
		var filename: return FileHelpers.load_ogg(filename)

func load_video(name: String):  # Searches through all of the paths to find the file
	match find_file(name):
		NOT_FOUND: return fallback_videostream
		var filename: return FileHelpers.load_video(filename)

func load_image(name: String) -> ImageTexture:  # Searches through all of the paths to find the file
	match find_file(name, true):
		NOT_FOUND: return fallback_texture
		var filename: return FileHelpers.load_image(filename)


func find_by_extensions(array, extensions=null) -> Dictionary:
	# Both args can be Array or PoolStringArray
	# If extensions omitted, do all extensions
	var output = {}
	if extensions:
		for ext in extensions:
			output[ext] = []
		for filename in array:
			for ext in extensions:
				if filename.ends_with(ext):
					output[ext].append(filename)
	else:
		for filename in array:
			var ext = filename.rsplit('.', false, 1)[1]
			if ext in output:
				output[ext].append(filename)
			else:
				output[ext] = [filename]
	return output


func scan_library() -> Dictionary:
	print('Scanning library')
	var song_defs = {}
	var collections = {}
	var genres = {}

	for root in PATHS:
		var rootdir = root + 'songs'
		var dir = Directory.new()
		var err = dir.make_dir_recursive(rootdir)
		if err != OK:
			print_debug('An error occurred while trying to create the songs directory: ', err)
			return err

		var songslist = FileHelpers.directory_list(rootdir, false)
		if songslist.err != OK:
			print('An error occurred when trying to access the songs directory: ', songslist.err)
			return songslist.err

		dir.open(rootdir)
		for folder in songslist.folders:
			var full_folder := '%s/%s' % [rootdir, folder]

			if dir.file_exists(folder + '/song.json'):
				# Our format
				song_defs[folder] = FileLoader.load_folder(full_folder)
				print('Loaded song directory: %s' % folder)
				if song_defs[folder]['genre'] in genres:
					genres[song_defs[folder]['genre']].append(folder)
				else:
					genres[song_defs[folder]['genre']] = [folder]
				if typeof(song_defs[folder]['chart_difficulties']) == TYPE_ARRAY:
					var diffs = song_defs[folder]['chart_difficulties']
					var chart_difficulties = {}
					for i in min(len(diffs), len(default_difficulty_keys)):
						chart_difficulties[default_difficulty_keys[i]] = diffs[i]
					song_defs[folder]['chart_difficulties'] = chart_difficulties

			elif dir.file_exists(folder + '/collection.json'):
				var collection = FileLoader.load_folder(full_folder, 'collection')
				collections[folder] = collection
				var base_dict = {'filepath': folder+'/'}  # Top level of the collection dict contains defaults for every song in it
				for key in collection.keys():
					if key != 'songs':
						base_dict[key] = collection[key]
				for song_key in collection['songs'].keys():
					var song_dict = collection['songs'][song_key]
					var song_def = base_dict.duplicate()
					for key in song_dict.keys():
						song_def[key] = song_dict[key]
					Library.add_song(song_key, song_def)
					# Legacy compat stuff
					song_defs[song_key] = song_def
					if song_defs[song_key]['genre'] in genres:
						genres[song_defs[song_key]['genre']].append(song_key)
					else:
						genres[song_defs[song_key]['genre']] = [song_key]

			else:
				var files_by_ext = find_by_extensions(FileHelpers.directory_list(full_folder, false).files)
				if 'sm' in files_by_ext:
					var sm_filename = files_by_ext['sm'][0]
					print(sm_filename)
					var thing = SM.load_file(full_folder + '/' + sm_filename)
					print(thing)
					pass
				else:
					print('Found non-song directory: ' + folder)
		for file in songslist.files:
			print('Found file: ' + file)

	return {song_defs=song_defs, genres=genres}


func load_folder(folder, filename='song'):
	var file = File.new()
	var err = file.open('%s/%s.json' % [folder, filename], File.READ)
	if err != OK:
		print(err)
		return err
	var result_json = JSON.parse(file.get_as_text())
	file.close()
	if result_json.error != OK:
		print('Error: ', result_json.error)
		print('Error Line: ', result_json.error_line)
		print('Error String: ', result_json.error_string)
		return result_json.error
	var result = result_json.result
	result.directory = folder
	return result


func load_filelist(filelist: Array, directory=''):
	var charts = {}
	var key := 0
	for name in filelist:
		var extension: String = name.rsplit('.', true, 1)[-1]
		name = directory.rstrip('/') + '/' + name
		var filename = find_file(name)
		if filename != NOT_FOUND:
			match extension:
				'rgtm':  # multiple charts
					var res = RGT.load_file(filename)
					for k in res:
						charts[Library.difficulty_translations.get(k, k)] = res[k]
				'rgts', 'rgtx':  # single chart - The keys for this should be translated afterwards
					charts[key] = RGT.load_file(filename)
					key += 1
				'srt':  # maimai, single chart
					var metadata_and_notes = SRT.load_file(filename)
					Note.process_note_list(metadata_and_notes[1])  # SRT doesn't handle doubles
					charts[key] = metadata_and_notes
					key += 1
				'sm':  # Stepmania, multiple charts
					var res = SM.load_file(filename)
					for chart in res[1]:
						var diff = chart.difficulty_str
						charts[diff] = chart.notes
				_:
					pass
	return charts


func save_json(filename: String, data: Dictionary):
	filename = userroot + filename
	var dir = filename.rsplit('/', true, 1)[0]
	match FileHelpers.init_directory(dir):
		OK:
			pass
		var err:
			print_debug('Error making directory for JSON file: ', err, FileHelpers.ERROR_CODES[err])
			return err
	var json = JSON.print(data)
	var file = File.new()
	match file.open(filename, File.WRITE):
		OK:
			file.store_string(json)
			file.close()
			return OK
		var err:
			print_debug('Error saving JSON file: ', err, FileHelpers.ERROR_CODES[err])
			return err


func load_json(filename: String):
	var file = File.new()
	var err
	for root in PATHS:
		var filename1 = root + filename
		if file.file_exists(filename1):
			err = file.open(filename1, File.READ)
			if err != OK:
				print('An error occurred while trying to open file: ', filename1, err, FileHelpers.ERROR_CODES[err])
				continue  # return err
			var result_json = JSON.parse(file.get_as_text())
			file.close()
			if result_json.error != OK:
				print('Error: ', result_json.error)
				print('Error Line: ', result_json.error_line)
				print('Error String: ', result_json.error_string)
				return result_json.error
			return result_json.result
	print('File not found in any libraries: ', filename)
	return ERR_FILE_NOT_FOUND
