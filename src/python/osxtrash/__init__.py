from ctypes import cdll, c_char_p, create_string_buffer, addressof, c_int, \
	POINTER
from os.path import dirname, join

def move_to_trash(*file_paths):
	global _IMPL_SO
	if _IMPL_SO is None:
		initialize(so_path=join(dirname(__file__), 'impl.so'))
	strings = \
		[create_string_buffer(path.encode('utf-8')) for path in file_paths]
	num = len(file_paths)
	pointers = (c_char_p * num)(*map(addressof, strings))
	error =_IMPL_SO.moveFilesToTrash(num, pointers)
	if error:
		reason = _ERROR_REASONS[error]
		raise OSError(
			error,
			'One or more files could not be moved to trash: %s (error %d).' %
			(reason, error)
		)

def initialize(so_path):
	global _IMPL_SO
	_IMPL_SO = cdll.LoadLibrary(so_path)
	_IMPL_SO.moveFilesToTrash.argtypes = [c_int, POINTER(c_char_p)]

_IMPL_SO = None

_ERROR_REASONS = {
	1: 'invalid path', 2: 'path does not exist',
	3: 'could not get file privileges', 4: 'could not move to trash',
	5: 'some files were not moved to trash'
}