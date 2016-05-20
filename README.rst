osxtrash
========

A Python library for moving files to the trash on OS X, including support for OS X's "Put Back" functionality for restoring files.

Usage
=====
.. code:: python

    from osxtrash import move_to_trash
    move_to_trash('/Users/michael/test.txt', '/Users/michael/Temp/')

Passing multiple files at once has the advantage that Finder may only prompt the user once for all files (instead of once per file). When an error occurs deleting any of the files, an ``OSError`` is raised. Its ``errno`` attribute can be used to distinguish between the following cases:

- ``1``: Invalid path.
- ``2``: Path does not exist.
- ``3``: Could not get file privileges.
- ``4``: Could not move to trash.
- ``5``: Some files were not moved to trash.

Installation
============
.. code:: bash

    pip install osxtrash

Implementation
==============
The implementation is based on a trimmed down version of `Ali Rantakari's trash script`_. The present library doesn't do much more than providing a nice Python API to it.

.. _`Ali Rantakari's trash script`: https://github.com/ali-rantakari/trash