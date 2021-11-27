# Static functions mostly for FileLoader to make use of because of deficiancies in load()
extends Node

const ERROR_CODES := [
	'OK', 'FAILED', 'ERR_UNAVAILABLE', 'ERR_UNCONFIGURED', 'ERR_UNAUTHORIZED', 'ERR_PARAMETER_RANGE_ERROR',
	'ERR_OUT_OF_MEMORY', 'ERR_FILE_NOT_FOUND', 'ERR_FILE_BAD_DRIVE', 'ERR_FILE_BAD_PATH','ERR_FILE_NO_PERMISSION',
	'ERR_FILE_ALREADY_IN_USE', 'ERR_FILE_CANT_OPEN', 'ERR_FILE_CANT_WRITE', 'ERR_FILE_CANT_READ', 'ERR_FILE_UNRECOGNIZED',
	'ERR_FILE_CORRUPT', 'ERR_FILE_MISSING_DEPENDENCIES', 'ERR_FILE_EOF', 'ERR_CANT_OPEN', 'ERR_CANT_CREATE', 'ERR_QUERY_FAILED',
	'ERR_ALREADY_IN_USE', 'ERR_LOCKED', 'ERR_TIMEOUT', 'ERR_CANT_CONNECT', 'ERR_CANT_RESOLVE', 'ERR_CONNECTION_ERROR',
	'ERR_CANT_ACQUIRE_RESOURCE', 'ERR_CANT_FORK', 'ERR_INVALID_DATA', 'ERR_INVALID_PARAMETER', 'ERR_ALREADY_EXISTS',
	'ERR_DOES_NOT_EXIST', 'ERR_DATABASE_CANT_READ', 'ERR_DATABASE_CANT_WRITE', 'ERR_COMPILATION_FAILED', 'ERR_METHOD_NOT_FOUND',
	'ERR_LINK_FAILED', 'ERR_SCRIPT_FAILED', 'ERR_CYCLIC_LINK', 'ERR_INVALID_DECLARATION', 'ERR_DUPLICATE_SYMBOL',
	'ERR_PARSE_ERROR', 'ERR_BUSY', 'ERR_SKIP', 'ERR_HELP', 'ERR_BUG'
]

static func load_image(filename: String) -> ImageTexture:
	var tex := ImageTexture.new()
	var img := Image.new()
	img.load(filename)
	tex.create_from_image(img)
	return tex


static func load_ogg(filename: String) -> AudioStreamOGGVorbis:
	# Loads the ogg file with that exact filename
	var audiostream = AudioStreamOGGVorbis.new()
	var oggfile = File.new()
	oggfile.open(filename, File.READ)
	audiostream.set_data(oggfile.get_buffer(oggfile.get_len()))
	oggfile.close()
	return audiostream


static func load_video(filename: String):
	return load(filename)
	# This may need reenabling for some platforms:
	#var videostream = VideoStreamGDNative.new()
	#videostream.set_file(filename)
	#return videostream


static func directory_list(directory: String, hidden: bool, sort:=true) -> Dictionary:
	# Sadly there's no filelist sugar so we make our own
	var output = {folders=[], files=[], err=OK}
	var dir = Directory.new()
	output.err = dir.open(directory)
	if output.err != OK:
		print_debug('Failed to open directory: ' + directory + '(Error code '+output.err+')')
		return output
	output.err = dir.list_dir_begin(true, !hidden)
	if output.err != OK:
		print_debug('Failed to begin listing directory: ' + directory + '(Error code '+output.err+')')
		return output

	var item = dir.get_next()
	while (item != ''):
		if dir.current_is_dir():
			output['folders'].append(item)
		else:
			output['files'].append(item)
		item = dir.get_next()
	dir.list_dir_end()

	if sort:
		output.folders.sort()
		output.files.sort()
	# Maybe convert the Arrays to PoolStringArrays?
	return output


static func init_directory(directory: String):
	var dir = Directory.new()
	var err = dir.make_dir_recursive(directory)
	if err != OK:
		print('An error occurred while trying to create the directory: ', directory, err, ERROR_CODES[err])
	return err
