SSU 0.10: Mon Sep 24 CEST 2007

	* Improved "update" and "diff" performance with the introduction of a
          local ssserv hash cache. The cache allows ssserv to avoid using
          SourceSafe in safe circumstances, providing a mean speedup of 610%
          while accessing the cache, and a 2% time increase for the first time
          update of uncached files.
	* Implemented "help" and "monitor" commands.


SSU 0.9: Sun Sep 16 CET 2007

	* Fixed handling of symlinks inside the project root (incorrect symlink
          removal on update, incorrect mode change of pointed-to files,
          unmarked conflicts during updates).
	* Fixed incomplete updates in presence of namespace clashes.
	* Implemented "opened".
	* Certain commands (status, history, opened) no longer stop at the first
	  file error when multiple files are specified.
	* .ssrc search extended to 8 levels.


SSU 0.8: Sat Dec 23 CET 2006

	* Fixed case conversion issues leading to occasional path case changes
	  when updating recursively inside a project sub-directory. Incomplete
	  removal of phantom files (as created by such updates) was also fixed.
	* Fixed path canonalization, resolving known relative path issues:
          incomplete client updates and server database escalation when using
	  relative paths either directly or through the command line.
	* Changed verb "reverting" to "reverted" in the "revert" command to
          match the actual status of the action.
	* ss now avoids pruning below the current working directory in any
	  circumstance, fixing traversal errors with compound commands.
	* Removing permanently a project in SourceSafe (by using the windows
          client) would previously cause subsequent versioned operations on the
          database to fail randomly with "No such file or directory" errors
          thanks to a totally flawed/unrelated SourceSafe prompt. Fixed by
          ignoring the prompt.


SSU 0.7: Fri Dec 16 CET 2005

	* Internal hash function changed to MD5 (there were known problems with
	  the old implementation).
	* 0.7 declared stable.


SSU 0.6: Sun Mar 20 CET 2005

	* Revision syntax now supports date/times.
	* Exit status is now compatible with diff(1).
	* checkout speed improvements.
	* Implemented revert -a flag.
	* Implemented recover.
	* Improved ssserv "add" to work around SourceSafe limitations.
	* Minor cleanups.


SSU 0.5: Sat Mar 05 CET 2005

	* Fixed several long-standing command-line escaping issues on ssserv
	  (almost all operations affected, upgrade highly recommended).
	* checkin/add now spawn an editor when no comments are specified on the
          command line.
	* -r (reopen) flag implemented for revert.
	* cat, label and diff can now refer to old file versions.
	* Implemented diff2.
	* Minor cleanups.


SSU 0.4: Sat Feb 26 CET 2005

	* Manual get of a single new file would fail with an error.
	* Recursive diff would stop on the first writable file with no error.
	* "checkin" no longer adds new files to the repository: the
          functionality has been moved to the "add" command.
	* Addition of a new file was not an atomic operation (the resulting
          file could end-up in a different project under heavy server usage).
	* delete can be forced in some circumstances.
	* ssserv stability improvements.
	* Minor cleanups.

	SSU 0.3 clients can communicate with 0.4 as long the new
	functionalities are not involved (add/delete).


SSU 0.3: Fri Feb 18 CET 2005

	* Implemented "label" and "cat".
	* Fixed the .ssrc search mechanism (extended to 5 levels).
	* Addition of files in new sub-projects would fail with an error.
	* Removed extra redundant checks in the protocol for latency
          improvements. **WARNING**: this is a protocol-incompatible
          release. Both the client and the server needs to be upgraded.
	* Minor cleanups.
