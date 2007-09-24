Hacking SSU
===========

Due to limited resources, SSU has several known issues that will require time
before they will be resolved. For some of them, a solution is already known.
Before starting to hack at random, here are some documented notes:

.. contents::


Better cooperation model
------------------------

Allowing the "multiple checkout" option to co-exist with SSU is a priority, but
unfortunately there are no ways to trap the merge behaviour of "checkin" and
bypass the visual merge tool. Maybe it's possible by using the DLL API, or some
flags. Once some way is found to disable the automatic merge prompt, a simple
3-way merge can be done directly on the client by using base/head revision
numbers.


Store file properties on the client
-----------------------------------

Revision numbers should be transferred when files are checked-out or updated,
along with file properties (line endings, etc). Apparently a separate
"properties" invocation is required, possibly breaking the atomicity of the
call and halving the get/checkout/update performance (which is already
horrible). File properties are needed to:

- Implement binary file transfers.
- Fix all operations that currently assume head versions instead of bases.


Improved filesystem performance
-------------------------------

SSU protocol allows the server to compare files by checksums
directly. Currently ssserv maps SourceSafe paths to filenames using the
"physical" command, and then compares file mtimes while maintaining a local
hash cache to reduces the amount of time taken by "ss.exe".

More commands (besides "get" and "diff") could use/update this cache. Also,
consider a passive and parallel thread to update this cache.

Directory listings (used very often for get commands) could be cached with the
same method, provided that the whole hierarchy is checked.


Fix server-side mappings
------------------------

Fixed by improving "dir" to scan the configured mappings first, make a list of
required databases, list those, and post-process the result according to the
mappings again. This is currently not done due to performance reasons.


Fix possible deadlocks due to user mis-validation
-------------------------------------------------

On login, all databases should be probed before continuing. This is currently
not done due to performance reasons.


Braindead "opened" output
-------------------------

File and directory names in ss.exe's output are truncated if excessively long,
making it impossible to parse them correctly directly in "ssserv".


Improve "help" output
---------------------

Parse README and put help strings directly in a module, to provide a more
user-friendly interface.
