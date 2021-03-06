===================================
SSU - `Textual` SourceSafe for Unix
===================================

.. contents::


Introduction
============

Purpose
-------

Until now, Unix developers which required access to a SourceSafe repository
(formerly Visual SourceSafe) had to use a Windows machine or, in the lucky case
that the architecture was standard enough, pay another time. SSU provides
access to local *and* remote SourceSafe repositories through TCP, to any POSIX
system (Linux, BSDs, OS X, etc), and for *free*, alleviating the pain. SSU also
improves the SourceSafe interface and tries to work around several design bugs.

Requirements
------------

SSU is divided into two components: a command-line Unix client and a
windows-based server which runs on a machine with repository access. A single
windows machine can multiplex any number of repositories and clients.

The Unix client "ss" requires only Perl >= 5.4 and network TCP port 5901 access
to the server. The windows server "ssserv" requires Perl >= 5.6, but has only
been tested with ActivePerl_ 5.8 (5.6 experienced stability problems). The
server runs as a stand-alone process unless you use some service helpers
(configuration as such is not described here). ssserv also requires the
SourceSafe command-line client to be installed locally (usually installed
automatically with the SourceSafe software).

Only SourceSafe 6.0/2005 has been tested.

Since SSU 0.7 the Digest::MD5 >= 2.11 module is now required (available from
CPAN_, already installed on most system including ActivePerl).

.. _ActivePerl: http://www.activestate.com/Products/ActivePerl/
.. _CPAN: http://search.cpan.org/~gaas/Digest-MD5/


Development status
------------------

Stable, but please read Limitations_. SSU supports and uniforms a good subset
of the SourceSafe features and has proven to be stable when used by a team of 6
developers accessing a single server. SSU has been developed since one year now
and employs some regression testing. We're interested in feedback, we'd be glad
to know about any success.

The adoption of Perl was mainly due to its presence in server environments (ss
works with Perl 5.4 which is still largely installed), but may eventually be
replaced with something more readable in the future.


Why SSU requires a Windows box?
-------------------------------

I've often been questioned about this requirement, and why a tool that accesses
the repository directly can't be developed instead: it can't be done due to the
proprietary nature of the repository format.

SourceSafe is a server-less design, there's no difference between the machine
that hosts the repository (the SMB share server) and any other client. For this
reason, all clients are in fact servers (or thick clients), sharing the
repository across an SMB share. There are no direct communications between
clients, the repository is simply locked on access and updated according to a
fixed schema.

This design has a number of vital issues:

1. Accessing the repository requires an SMB access to the machine hosting the
   files. SMB is a NetBIOS service, which is problematic to run across Internet
   and extremely inefficient to access.
2. The repository is stored in a custom undisclosed format, and thus can't be
   accessed directly without a lot of reverse-engineering.
3. Since all clients access the repository without supervision, a client must
   be 100% compliant with SourceSafe semantics to avoid interoperability
   problems, and is responsible for the integrity of the data itself.

Because of "1", most SourceSafe add-ons are sold with the sole purpose of
accelerating (or just "allowing") remote operations. Because of "2" and "3",
all add-ons (no exceptions) require a "server" component, and that component
will use a working SourceSafe installation to access the repository. Because of
"3", using the real windows client under emulation (as suggested elsewhere),
besides having the same network performance problems as "1", is extremely
risky, and can lead to data corruption in case of emulation glitches, network
outages or crashes.

SSU solves these issues by layering a real client with a simple stateful TCP
protocol. Since only relevant commands are sent remotely, network performance
is really good and matches other systems like cvs-pserver. Since the repository
is never exposed directly, repository data is ensured and client stability is
no longer relevant. Since SSU provides better serialization and atomicity
logic, the SSU server performance is often superior than real SourceSafe
performance when multiple clients are involved.

You don't need to install SSU on the server hosting the files (altough doing so
will result in better performance); you can use any windows box with a
SourceSafe installation that has access to the repository as outlined below:

Good I/O and network performance::

  SourceSafe client <-|         +------------+               |-> SSU client
  SourceSafe client <-|         |   SHARE    |               |-> SSU client
  SourceSafe client <-|-- lan --| SourceSafe |--| network |--|-> SSU client
  SourceSafe client <-|         | SSU server |               |-> SSU client
  SourceSafe client <-|         +------------+               |-> SSU client

Poor I/O, good network performance::

  +------------+         |-> SourceSafe client
  |   SHARE    |-- lan --|
  +------------+         |  +------------+               |-> SSU client
                         |->| SourceSafe |               |-> SSU client
     SourceSafe Client <-|  | SSU server |--| network |--|-> SSU client
     SourceSafe Client <-|  +------------+               |-> SSU client

Poor I/O and network performance::

  +---------+         |-> SourceSafe client
  |  SHARE  |-- lan --|
  +---------+         |               +------------+         |-> SSU client
                      |--| network |--| SourceSafe |         |-> SSU client
  SourceSafe Client <-|               | SSU server |-- lan --|-> SSU client
  SourceSafe Client <-|               +------------+         |-> SSU client

Having to use a Windows installation may seem a limiting factor for SSU
deployment, but remember that other alternatives have this implicit limitation
also. Since SSU ensures better data integrity, better performance, network
security and doesn't have any cost or specific requirements, any serious
administrator or project manager interested in your work should consider such a
request without too much trouble.


Installation
============

ssserv (server)
---------------

ssserv should be installed on a windows machine with repository
access. Multiple repositories can be served from the same server.

1) First install ActivePerl_ >= 5.8 and SourceSafe on the machine.

2) Unpack the source distribution in the target directory
   (eg: ``C:\Program Files\SSU``).

3) Create a "ssserv.ini" file in the same directory containing::

     HOME=C:\Program Files\SSU\HOME
     MAP=db C:\\DATA\\SSAFE_DB

   Where HOME is the working directory and MAP_ is an association list of names
   to database paths (note that backslashes should be escaped, the final one is
   *omitted*). ``C:\\DATA\\SSAFE_DB`` should be replaced with the directory
   containing your SourceSafe database. Setting MAP correctly is critical.

4) Create a "ssserv.bat" file in the same directory containing::

     set "PATH=%PATH%;C:\Program Files\Microsoft Visual Studio\Common\VSS\win32"
     perl ssserv

   Setting the PATH is not necessary if the "ss.exe" executable is already
   visible. You may also need to specify a full path to the Perl executable if
   you disabled the relative option in the ActivePerl installer.

5) Execute the file. Logging-out may kill the process depending on your
   operating system (2000/XP), so proceed accordingly.


ss (client)
-----------

Copy "ss" to prefix/bin (where prefix is usually /usr/local), and ``*.pm``
files in prefix/lib/ss (/usr/local/lib/ss/Maps.pm etc). "ss" should be
executable.

For each user create ``~/.ssrc`` (mode 600), containing::

  USER=username
  PASS=password
  HOST=hostname
  HOME=/home/username/projects/
  MAP=dirname db/projectname

Where HOME is an *absolute* path to an existing directory that will contain
your SourceSafe projects, and MAP is an association list of directories to
databases (see the MAP_ configuration reference).

In the above example we assume that ss will have control of all the
/home/username/projects tree, and the directory /home/username/projects/dirname
will actually contain the db/projectname project (where you recall DB was
configured server-side as ``C:\\DATA\\SSAFE_DB``, yielding ``C:\DATA\SSAFE_DB
$/projectname`` in SourceSafe syntax).

Execute ``ss get`` to bootstrap your tree.


Configuration
=============

MAP
---

Developers with experience with Perforce will be delighted to know that MAP
works in the same concept as the "View" field. SSU performs a double path
translation to give a "network transparent filesystem" independent of the
original repository layout. Basically MAP is a list of pairs, each one
containing the source path, and the destination path::

  MAP=source destination

MAP performs a path translation by matching a path prefix against "source" and
replacing it to "destination". Consider the following client example::

  HOME=/home/user
  MAP=project db/project

and this sample path::

  /home/user/project/file.c

First, the HOME prefix is removed, giving "project/file.c"; then the first map
is matched, replacing "project" with "db/project" and yielding the network path
"db/project/file.c". The path is now translated again in the server, but this
time "destination" is used directly as the final repository location::

  MAP=db C:\\SSAFE_DB

"db" is replaced with ``C:\SSAFE_DB``, giving ``C:\SSAFE_DB $/project/file.c``.

As a recommendation for the client, you should point HOME to the directory
containing your shared projects. Each project should have a MAP entry,
consisting of the directory name (that will contain your project) as the left
side, and the "repository name/project name" as the right side. On the server
simply give repository names and paths. This will give good flexibility and
reorganization possibilities on the long term.

Multiple mappings can be specified::

  MAP=source destination source destination

or::

  MAP=source destination \
      source destination

If either source or destination contain a space, you should quote the
definition. You should also escape all backslashes (mostly for windows paths),
eg::

  MAP="a source" desti\\nation

The source path is always relative to the HOME directory. Multiple mappings can
be used to uniform the project workspace regardless of the repository status::

  MAP=project/dir db/oldproject/dir \
      project     db/newproject

Unfortunately MAP is not as powerful as Perforce's. You can have overlapping
patterns, but the first one that matches will be used. You can also only map
directories, and there's no wildcards.

Under ssserv (on windows) `destination` is limited to a fully qualified
database path. Yet you can still alter the environment server-side::

  MAP=db/old C:\\DB1\\SSAFE_DB \
      db     C:\\DB2\\SSAFE_DB \
      db2    C:\\DB3\\SSAFE_DB


ssserv.ini reference
--------------------

HOME:
	Working directory (mandatory). Should not be shared or modified during
	execution. When missing it's created automatically.

MAP:
	Mappings (See MAP_, mandatory). You can specify any amount of
	databases, but they must *all* share the same users, with the *same*
	passwords and access rights. This doesn't mean you can't have multiple
	users: only that if user X with password Y is present in the first
	database, all the other mapped ones should have the same user X
	configured with the same password Y too. As ssserv provides access to
	multiple databases in an uniform way, this makes sense. Failure in
	doing so will result in deadlocks (thanks to the crappy "ss.exe"
	interface). If you need to clearly separate two databases you can
	always run two ssserv instances on different ports.

PORT:
	Listening port (defaults to 5901). Multiple servers can be run on the
	same machine by specifying different ports for each one.

PRUNE:
	Automatic hierarchy pruning. Defaults to 0 (disabled). As SSU does not
	care about "projects", new projects will be created automatically upon
	addition of new files. If pruning is enabled, when all files in a
	directory are removed the project is removed as well. Consider however
	that empty directories are ignored by the client, and removing the same
	directory twice will destroy the history in SourceSafe. Should be
	enabled only when "project pollution" is an issue for Visual SourceSafe
	(the windows client). The default (disabled) is recommended.

AUTOREC:
	Automatic file recovery upon addition. Defaults to 1 (enabled). When a
	new file is added, ssserv tries to recover any lost entry and submit
	the change as a "checkin" instead of an "add". This will prevent the
	file to be deleted "twice", preserving the whole history. There are
	still situations where automatic recovery is not possible (like
	addition over an old directory with the same name). In that case delete
	should be forced to discard the history of the old directory. AUTOREC
	considerably slows down "add" times, you may want to turn it off
	temporarily for large project imports.


.ssrc reference
---------------

USER:
	Username (mandatory).

PASS:
	Password (mandatory).

HOST:
	Hostname or IP address of the machine running ssserv (mandatory).

HOME:
	ss home directory (all mappings are under this directory, mandatory).
	Must be *absolute*.

MAP:
	Mappings (mandatory, see MAP_).

PORT:
	Server port. Defaults to 5901.

QUIET:
	Silent mode. Defaults to 0 (disabled).

PRUNE:
	Automatic hierarchy pruning. Defaults to 1 (enabled). When pruning is
	enabled, and all files in a directory are removed, the directory is
	removed as well; up to (but not including) HOME.


Playground
==========

The basics
----------

Upon correct configuration, each client can extract a read-only copy of the
required files by using the ``ss get`` command::

  $ ss get dir
  U dir/test.txt

Without arguments, get updates all the mappings you have configured. ``ss get``
is also used to update the source tree with the latest version available in the
repository. ``ss get`` will *never* modify writable files (unlike cvs, merge is
never attempted for now).

To modify a file you use the ``checkout`` command::

  $ ss checkout dir/test.txt

``ss checkout`` will update the specified file/files to the latest revision,
make them writable and lock the repository. Under SourceSafe only a single user
at a time can have a file checked-out/locked. The "multiple-checkouts" option
in SourceSafe is avoided at all costs, and isn't used by SSU (See `Future
developments`_).

When done with editing, you can ``checkin`` the file::

  $ ss checkin dir/test.txt

All-in-all:

* ``get`` updates your read-only files

* ``checkout`` makes them writable, locking the repository.

* ``checkin`` will commit your changes, and return the file to read-only
  state.

* All commands support one or more files.

* You should try to avoid keeping unused files locked (checked-out).


Limitations
-----------

ss does a great job in uniforming SourceSafe interaction, but still it's
limited (due to SourceSafe limitations or development status) in some ways:

* Security is actually just an option. Due to command-line madness and
  inconsistencies of the "ss.exe" interface, the access is verified only on the
  first mapped database, and used all along. The server process needs total
  access rights to the directory containing the repository to be able to use
  the "ss.exe" command for all users.

* Only text files are supported. Line-endings are correctly converted, but
  binary files will get corrupted.

* No atomic commits. The ability of specifying multiple files in the command
  line is purely syntactic sugar. Atomicity is guaranteed only on a
  per-operation basis.

* Multiple check-outs of a single file are a serious problem in the "ss.exe"
  interface. Basically, there's not enough consistency to perform unattended
  commits later. Also, the merge logic of SourceSafe simply stinks. Read
  `Future developments`_. For now, ``chmod +w`` manually and then *remove the
  file* if you need random edits.

* The case of the filename is preserved (eg: ``File.txt``), but the command
  line client doesn't try to be smart and doesn't prevent you from getting
  ``FiLe.TxT`` at the same time, although the latter will be removed when
  updating recursively.

* On filesystems with case sensivity, SourceSafe case (stored on the first file
  submission) wins. For this reason, beware about colliding namespaces inside
  HOME. If you need a different case you can use symlinks safely.

* Recursive updates may have problems when multiple server-side mappings for
  the same database are specified. This should be fixed.

* SSU only implements a subset of the entire SourceSafe features, focusing on
  inter-operation.


Future developments
-------------------

The big mayor step in the SSU 1 development should be a new (and possibly
better) cooperation model for SourceSafe that removes the current "multiple
checkout" limitation. Read HACKING for more details.

Note that SSU is not meant to be a fully fledged revision control system for
Unix, just an *aid* where SourceSafe access is required. Consider switching to
a better revision control system instead.


Securing the transport
----------------------

You can layer your connections through SSL, for example using OpenSSH:

  $ ssh -N proxy -L 5901:server:5901

and modify ``~/.ssrc`` to connect to localhost instead of connecting to the
server directly. By using the ssh's -C flag you can also get compression for
free.

Again, note that this gives you a secure *transport* (for example for working
off-site), *not* a secure server.


Revision syntax
---------------

Some commands permit to work on older versions of files, by using either a
revision number, a label or a date. The revision/label/date is simply appended
to the local file name, using the appropriate symbol, forming the revision
syntax:

``file#revision``:
	Use the numerical "revision".

``file@label``:
	Use the named "label".

``file@yyyy/mm/dd``, ``file@yyyy/mm/dd:hh:mm:ss``:
	Use the specified date. If no time is specified, 00:00:00 is assumed.

For example::

  ss cat file@milestone

prints on the standard-output the contents of file labeled at "milestone",
while::

  ss label -ltest file#1

labels file at revision 1 as "test".

A file without revision syntax, or with the special "#head" spec, always refers
to the latest available revision.


Test suite
----------

Although aimed at regression testing, you can use the "check" script shipped
within the distribution to perform some very basic tests on the "ss" interface.

"ss" should be installed and configured to access a virgin repository. The
first argument of "check" should be a mapped inexistent directory.


Command line reference
======================

ssserv
------

-f file:
	Specify a different configuration file. If this option is not
	specified, the environment variable `SSCONFIG` is first consulted for
	an alternate path. If not set, "ssserv.ini" is used.


ss
--

Global options
~~~~~~~~~~~~~~

-q:
	Quiet

-v:
	Verbose

-f file:
	Specify a different configuration file. If this option is not
	specified, the environment variable `SSCONFIG` is first consulted for
	an alternate path. If not set, ".ssrc" is searched in the current
	directory, and up to 8 levels.

Commands
~~~~~~~~

get files:
	Get an updated read-only version of the specified files, or of the
	entire tree if no files are specified. Unlike SourceSafe, files are
	automatically removed locally when they're deleted on the repository.
	All read-only files under HOME should be considered property of ss and
	*removable at any time*. Create read-write files to avoid files being
	removed when updating.

cat [-h] files:
	Print in the standard-output the latest repository version of the
	specified files (cat only accepts files and isn't recursive).
	-h can be used to add an header if multiple files are specified.
	Older file versions can be retrieved using the `revision syntax`_.

checkout files:
	Get an updated read/write version of the specified files,
	locking the repository.

add [-c] files:
	Adds the specified files to the repository, and make them read-only.
	A comment can be added with the -c flag.

checkin [-c] files:
	Checkins the specified files, making them read-only again and
	unlocking the repository. A comment can be added with the -c flag.

revert [-ra] files:
	Revert changes made to the specified files, unlocking the repository
	without changes. -r reopens the file after restoring the content,
	without actually releasing the lock. -a only reverts unchanged files.

dir [-a] files:
	Remote directory listing. With -a, does not translate the output in
	local syntax.

history [-m] files:
	Shows the history for the selected files. -m specifies a maximal number
	of entries to be displayed.

status files:
	Shows file status (head revision number, modification dates, etc).

opened [-aC] files:
	Shows a list of opened (checked-out) files in the specified tree for
	the current user. With '-C user', checked-out files for the specified
	user (all users with '-a') are shown instead.

diff [-d] files:
	Diffs repository files (head version or older using revision syntax)
	against local files. -d can be used to pass local options to the diff
	executable (``ss diff -du`` gets you unified diffs).

diff2 [-d] file1 file2:
	Like diff, but compares two repository files directly instead
	(eg: ``ss diff2 file@date1 file@date2``).

delete [-f] files:
	Deletes the specified files in the repository and locally. -f forces
	the delete for writable files, discarding any local changes. -f also
	forces the delete when the same file was already deleted in SourceSafe
	(*discarding previous history*).

recover files:
	Recovers and gets deleted files or directories.

label -l <label> files:
	Tag/label the specified *repository* files (using revision syntax or
	the head version otherwise) using the specified label. You can rename a
	label by specifying a labeled revision syntax. Labeling an
	already-labeled revision through a numerical revision or date is not
	allowed.

help:
	Show a list of available commands and their aliases.

monitor:
	Show ssserv internal statistics and debugging informations. This output
	is for debugging purposes only, and subject to change.

version:
	Show SSU client/server version information.


Aliases
~~~~~~~

Some aliases are provided for users coming from different revision systems:

get:
	sync update up

cat:
	print

checkin:
	ci submit commit

checkout:
	co edit

revert:
	undo unedit undocheckout

dir:
	ls

delete:
	rm del

history:
	filelog log

status:
	properties

label:
	tag

These are just mere aliases however: flags/syntax doesn't change.


Verbose output
~~~~~~~~~~~~~~

get/checkin/checkout use one-letter messages to inform you about state changes
of your tree when operating:

:?:	File skipped (no remote file).
:O:	File opened locally/no remote changes.
:U:	File updated.
:D:	File deleted.
:M:	File merged.
:C:	Conflict.


Exit status
~~~~~~~~~~~

:0:	Command completed successfully. Only in diff/diff2: no differences.
:1:	Only in diff/diff2: some differences.
:2:	Error or incomplete execution.


Download
========

SSU is located at http://www.thregr.org/~wavexx/software/ssu/ and distributed
under the terms of the `GNU LGPL`_ license without *any* warranty. SSU is
copyright(c) 2005-2007 of Yuri D'Elia <wavexx@thregr.org>.


SourceSafe tips
===============

If you're used to CVS, SubVersion or other serious revision control systems and
started to work with SSU recently, here's some useful tips to circumvent
SourceSafe limitations (and more):

* When doing the same operations on several files (like get), recursive modes
  are generally faster on slow links: for example it's faster to do ``ss get
  .`` than ``ss get *``.

* A file revision cannot be labeled twice in SourceSafe; SSU inherits the same
  limitation and prevents you from removing the old label. However SourceSafe
  permits to label directories, directories have a version number assigned at
  each file change and child entries inherits the label. Thus always label
  directories when possible.

* Deleting the same file/project twice in SourceSafe irreversibly destroys
  history. For this reason "ssserv" intentionally avoids destructive
  operations: "projects" are never really deleted and "add" tries to recover
  files instead of creating new ones. As a result (by default) SSU users
  *cannot* perform destructive operations. However as empty repository
  directories are not shown nor deleted, adding a file over an empty directory
  with the same name will trigger a "file already exists" error to user's
  surprise.

* To revert a file to an old version first checkout the file, retrieve the old
  version into the new one, and then checkin again::

    ss co file
    ss cat file#oldversion > file
    ss ci -c 'reverting new changes' file

* To move a file across directories simply copy/add/remove it. There's really
  no better way. SourceSafe somewhat supports renaming a file and/or moving a
  directory into another, but there's no track of the change and the operation
  could result in another history loss.

* A file was just deleted from the repository, you wanted to know why but now
  "history" tells nothing more than what you already know. Check the history of
  the parent directory for some more clue.

* When importing for the first time many new source files into the repository,
  you can consider switching off "AUTOREC" for greater performance.


Support/Mailing list
====================

Subscribe to `ssu-users` by either sending an empty email to
<ssu-users+subscribe@thregr.org>, using GMane_ (group
"gmane.comp.version-control.ssu.user") or by contacting the author at
<wavexx@thregr.org>. The list is about discussing bugs, usage issues and
release announcements. The archives are accessible via web through
http://news.gmane.org/gmane.comp.version-control.ssu.user or via news directly.


.. _GNU LGPL: http://www.gnu.org/licenses/lgpl.html
.. _GMane: http://www.gmane.org/
