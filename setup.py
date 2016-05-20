"""Send files to the Trash on OS X (incl. "Put Back" support).

See:
https://github.com/mherrmann/osxtrash"""

from setuptools import setup, Extension

impl = Extension(
	'osxtrash.impl',
	sources=['src/objc/trash.m'],
	extra_compile_args=['-mmacosx-version-min=10.5'],
	extra_link_args=[
		'-framework', 'AppKit',
		'-framework', 'ScriptingBridge'
	]
)

setup(
	name='osxtrash',
	version='1.2',
	description='Send files to the Trash on OS X (incl. "Put Back" support).',
	long_description=
		'Send files to the Trash on OS X (incl. "Put Back" support).' + 
		'\n\nHome page: https://github.com/mherrmann/osxtrash',
	url='https://github.com/mherrmann/osxtrash',

	author='Michael Herrmann',
	author_email='[my first name]@[my last name].io',
	license='MIT',
	platforms=['MacOS'],
	classifiers=[
		'Development Status :: 4 - Beta',
		'Intended Audience :: Developers',
		'License :: OSI Approved :: MIT License',
		'Operating System :: MacOS :: MacOS X',
		'Programming Language :: Python',
		'Programming Language :: Python :: 2',
		'Programming Language :: Python :: 2.7',
		'Programming Language :: Python :: 3',
		'Programming Language :: Python :: 3.2',
		'Programming Language :: Python :: 3.3',
		'Programming Language :: Python :: 3.4',
		'Programming Language :: Python :: 3.5',
		'Topic :: Software Development :: Libraries'
	],
	keywords='osx os x trash move recycle put back',
	package_dir={'': 'src/python'},
	packages=['osxtrash'],
	ext_modules = [impl]
)