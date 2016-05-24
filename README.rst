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

Deployment
==========
If you want to ship this library alongside your own product, you need to ensure that you also ship the file ``impl.so`` which lies in the ``osxtrash/`` directory in your ``site-packages/`` folder. If you are unable to place the file at this location, for instance when deployng a frozen desktop application, then you can call ``osxtrash.initialize(path_to_impl_so)``. For example:

.. code:: python

    import osxtrash
    import sys
    from os.path import join, dirname
    osxtrash.initialize(join(dirname(sys.executable), 'impl.so'))
    osxtrash.move_to_trash(...)

Implementation
==============
The implementation is based on a trimmed down version of `Ali Rantakari's trash script`_. The present library doesn't do much more than providing a nice Python API to it.

.. _`Ali Rantakari's trash script`: https://github.com/ali-rantakari/trash