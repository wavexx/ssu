#!/usr/bin/env perl
# ss - ssu perl client
# Copyright(c) 2005 of wave++ (Yuri D'Elia)
# Distributed under GNU LGPL without ANY warranty.
use strict;
use Cwd qw{cwd};
use File::Basename qw{dirname basename};
use File::Path qw{mkpath rmtree};
use File::Find qw{finddepth};
use Getopt::Std qw{getopts};
use POSIX qw{tmpnam};
use Socket;
require File::Spec;

# local modules
use FindBin;
use lib "$FindBin::Bin/../lib/ss";
use Parse;
use Maps;
use Proto;
use Cksum;


# Some defaults
my $VERSION	= "0.6";
my $RC_PATH	= ".ssrc";
my $D_PATH	= "$ENV{HOME}/.ss.d";
my $EDITOR	= $ENV{VISUAL} || $ENV{EDITOR} || "vi";
my $LEVELS	= 5;
my %PARAMS;

# command to handler maps.
my %CMAP =
(
  "add"			=> ["c:",	\&add],
  "get"			=> ["",		\&get],
  "checkout"		=> ["",		\&checkOut],
  "checkin"		=> ["c:",	\&checkIn],
  "revert"		=> ["r",	\&revert],
  "dir"			=> ["a",	\&dirListing],
  "history"		=> ["m:",	\&history],
  "status"		=> ["",		\&status],
  "diff"		=> ["d:",	\&diff],
  "diff2"		=> ["d:",	\&diff2],
  "delete"		=> ["f",	\&delete],
  "label"		=> ["l:",	\&label],
  "cat"			=> ["h",	\&cat],
  "version"		=> ["",		\&version]
);

# aliases
my %AMAP =
(
  "sync"		=> "get",
  "update"		=> "get",
  "up"			=> "get",
  "ci"			=> "checkin",
  "submit"		=> "checkin",
  "commit"		=> "checkin",
  "co"			=> "checkout",
  "edit"		=> "checkout",
  "undo"		=> "revert",
  "unedit"		=> "revert",
  "undocheckout"	=> "revert",
  "ls"			=> "dir",
  "rm"			=> "delete",
  "del"			=> "delete",
  "filelog"		=> "history",
  "log"			=> "history",
  "properties"		=> "status",
  "print"		=> "cat",
  "tag"			=> "label",
  ""			=> "version"
);


# local failure
sub fail(@)
{
  $_ = join(" ", @_);
  print STDERR (basename($0) . ": $_\n");
  exit(2);
}

# fail by protocol error
sub protoFail()
{
  fail(getErr());
}

# standard message
sub msg(@)
{
  unless($PARAMS{QUIET})
  {
    my $line = join(" ", @_);
    print STDOUT "$line\n";
  }
}

sub getAbsMap($$)
{
  my ($file, $maps) = @_;
  my $rel = rel2abs($file);

  (my $map, my $dir, $rel) = getMap($rel, $maps);
  ($map && $dir && $rel) or fail("\"$file\" not under ss control");

  return File::Spec->catdir($dir, $rel);
}

sub getInvRelMap($$)
{
  my ($file, $maps) = @_;
  my $rel;

  (my $map, my $dir, $file) = getInvMap($file, \@{$PARAMS{MAPS}});
  ($map && $dir && $file) or return undef;

  $file = File::Spec->catdir($dir, $file);

  # this isn't as stable as File::Spec->abs2rel
  my $cwd = cwd();
  $file =~ s/^\Q$cwd\E\///;
  return $file;
}

sub findInVicinity($)
{
  my ($file) = @_;

  for(1 ... $LEVELS)
  {
    return $file if(-r $file);
    $file = File::Spec->catfile(
      File::Spec->catdir(dirname($file), File::Spec->updir()),
      basename($file));
  }

  $file = File::Spec->catfile($ENV{HOME}, basename($file));
  return $file if(-r $file);

  return undef;
}

sub main()
{
  # command line overrides
  my %flags;
  getopts("f:qv", \%flags) or exit(2);
  my $ini = $flags{"f"} || $ENV{"SSCONFIG"} || $RC_PATH;
  $ini = findInVicinity($ini) or fail("cannot find \"$RC_PATH\"");

  # initialize the params
  %PARAMS = init($ini);
  $PARAMS{QUIET} = 1 if(defined($flags{"q"}));
  $PARAMS{QUIET} = 0 if(defined($flags{"v"}));

  # establish the connection
  setup();
  
  # fetch the argument
  my ($command, @args) = @ARGV;
  $command = lc($command);
  $command = $AMAP{$command} if($AMAP{$command});
  my $handler = $CMAP{$command} or
      fail("unknown command \"$command\"");

  # dispatch
  undef %flags;
  @ARGV = @args;
  getopts($handler->[0], \%flags) or exit(2);
  exit(!(&{$handler->[1]}(\%flags, @ARGV)));
}

sub setup()
{
  # connect
  my $proto = getprotobyname('tcp');
  socket(SFD, PF_INET, SOCK_STREAM, $proto);
  connect(SFD, sockaddr_in($PARAMS{PORT}, inet_aton($PARAMS{HOST}))) or
      fail("cannot connect to \"$PARAMS{HOST}:$PARAMS{PORT}\"");
  setupFd(*SFD);

  # perform authentication
  my $str = expectC($Proto::LOGIN) or protoFail();
  sendStr($Proto::USRPWD, encArr($PARAMS{USER}, $PARAMS{PASS})) or protoFail();
  $str = expectC($Proto::READY) or protoFail();
}

sub init($)
{
  my ($ini) = @_;

  my %data;
  parse($ini, \%data) or fail("cannot parse \"$ini\"");

  # check for needed data
  foreach my $param("USER", "PASS", "HOST", "HOME", "MAP") {
    defined $data{$param} or
	fail("missing parameter \"$param\"");
  }

  # check for home dir
  my $home = File::Spec->canonpath($data{"HOME"});
  File::Spec->file_name_is_absolute($home) or
      fail("HOME must be absolute");

  # parse mappings
  my $maps = parseMaps($home, $data{"MAP"}) or
      fail("malformed MAP");

  # put data together
  return
  (
    PRUNE => (defined($data{"PRUNE"})? $data{"PRUNE"}: 1),
    QUIET => (defined($data{"QUIET"})? $data{"QUIET"}: 0),
    USER => $data{"USER"},
    PASS => $data{"PASS"},
    HOST => $data{"HOST"},
    PORT => $data{"PORT"} || $Proto::PORT,
    HOME => $home,
    MAPS => $maps
  );
}

# prune a directory until HOME
sub prune($)
{
  my ($dir) = @_;

  if(!$PARAMS{PRUNE} || ($dir eq File::Spec->curdir()) ||
     (rel2abs($dir) eq $PARAMS{HOME})) {
    return 1;
  }

  rmdir($dir) and prune(dirname($dir));
}

sub forceUnlink($)
{
  my $file = shift;
  chmod(0600, $file) and unlink($file) or
      fail("cannot unlink \"$file\"");
}

sub version(\%@)
{
  my $fd = select(STDOUT);
  print "ss version $VERSION\n";
  print "Copyright 2005 of wave++ (Yuri D'Elia) <wavexx\@users.sf.net>\n";
  print "Distributed under GNU LGPL (v2 or above) without ANY warranty.\n";
  select($fd);
}

sub dirListing(\%@)
{
  my ($flags, @files) = @_;

  foreach my $file(@files)
  {
    # map the file
    my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});
    sendStr($Proto::LIST, encArr($remote)) or protoFail();
    my ($void, $size) = expectCV($Proto::XFER, 2);
    $void or protoFail();
    my $buf = recvBuf($size);
    defined($buf) or protoFail();

    # show the listing
    foreach(split("\n", $buf))
    {
      # perform inverse mappings (not perfect for relative/lower paths as ..)
      $_ = getInvRelMap($_, \@{$PARAMS{MAPS}}) if(!defined($flags->{"a"}));
      print STDOUT "$_\n" if($_);
    }
  }

  return 1;
}

sub status(\%@)
{
  my ($flags, @files) = @_;

  foreach my $file(@files)
  {
    # get the status
    my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});
    sendStr($Proto::STATUS, encArr($remote)) or protoFail();
    my ($void, $size) = expectCV($Proto::XFER, 2);
    $void or protoFail();
    my $buf = recvBuf($size);
    defined($buf) or protoFail();

    # output
    print STDOUT $buf;
  }

  return 1;
}

sub history(\%@)
{
  my ($flags, @files) = @_;

  foreach my $file(@files)
  {
    # get the history
    my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});
    my @args = ($remote, ($flags->{"m"} || 0));
    sendStr($Proto::HISTORY, encArr(@args)) or protoFail();
    my ($void, $size) = expectCV($Proto::XFER, 2);
    $void or protoFail();
    my $buf = recvBuf($size);
    defined($buf) or protoFail();

    # output
    print STDOUT $buf;
  }

  return 1;
}

sub getFile($$)
{
  my ($remote, $file) = @_;

  # request the file
  sendStr($Proto::GET, encArr($remote, cksumFile($file)));
  my ($c, $str) = recvStr();
  (defined $c) or protoFail();
  forceUnlink($file) if(-r $file && $c != $Proto::READY);
  return 0 if($c == $Proto::READY || $c == $Proto::ERROR);
  
  # the file exists and was modified
  ($remote, my $size) = decArr($str);
  $remote or protoFail();
  
  # write as readonly
  mkpath(dirname($file));
  my $old = umask(0222);
  recvFile($size, $file) or protoFail();
  umask($old);
}

# same as finddepth, but without cwd madness and without requiring perl 5.5
sub finddepth2(&@)
{
  use Cwd qw{chdir};

  my ($code, @files) = @_;
  my $initial = cwd();

  finddepth(
    sub
    {
      my $tmp = $_;
      my $oldcwd = cwd();
      $_ = "$File::Find::dir/$_";
      chdir($initial);
      &$code();
      chdir($oldcwd);
      $_ = $tmp;
    },
    @files);

  chdir($initial);
}

sub rel2abs($)
{
  my ($file) = @_;

  return File::Spec->canonpath(File::Spec->file_name_is_absolute($file)?
			       $file: File::Spec->catfile(cwd(), $file));
}

sub getDir($$)
{
  my ($remote, $file) = @_;

  # fetch remote listings
  sendStr($Proto::LIST, encArr($remote)) or protoFail();
  my ($void, $size) = expectCV($Proto::XFER, 2);
  $void or protoFail();
  my $buf = recvBuf($size);
  defined($buf) or protoFail();

  # check each entry in the listing
  my %files;

  foreach $remote(split("\n", $buf))
  {
    my $file = getInvRelMap($remote, \@{$PARAMS{MAPS}}) or next;
    $files{rel2abs($file)} = 1;

    if(-w $file) {
      msg("O $file");
    } else {
      getFile($remote, $file) and msg("U $file");
    }
  }

  # At that point we should purge local files with no remote equivalents
  finddepth2(
    sub
    {
      if(-f $_ && !-w $_ && !defined($files{rel2abs($_)}))
      {
	forceUnlink($_);
	prune(dirname($_));
	msg("D $_");
      }
    },
    $file);
}

sub get(\%@)
{
  my ($flags, @files) = @_;

  # no files specified, perform a full sync
  unless(@files)
  {
    foreach my $x(@{$PARAMS{MAPS}}) {
      push(@files, $x->[0]);
    }
  }

  foreach my $file(@files)
  {
    # map and fetch the file
    my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});

    if(-f $file && -w $file) {
      msg("O $file");
    } else
    {
      if(-f $file && -r $file)
      {
	# the file already exists, perform a normal update
	getFile($remote, $file) and msg("U $file");
	unless(-r $file)
	{
	  prune(dirname($file));
	  msg("D $file");
	}
      }
      else
      {
	# dir or unexistent local file
	getDir($remote, $file);
      }
    }
  }

  return 1;
}

sub checkOutFile($)
{
  my ($file) = @_;

  # file should be readonly (not checked-out) or non-existent
  (!-w $file) or fail("\"$file\" is already writable");
  my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});

  # request the file
  sendStr($Proto::CHECKOUT, encArr($remote, cksumFile($file)));
  my ($c, $str) = expectC($Proto::READY, $Proto::XFER);
  defined($str) or protoFail();

  if($c == $Proto::READY)
  {
    # just fix the permissions
    chmod(0644, $file);
  }
  else
  {
    # receive the file
    ($remote, my $size) = decArr($str);
    $remote or protoFail();
    forceUnlink($file) if(-r $file);

    # write as r/w
    mkpath(dirname($file));
    my $old = umask(0022);
    recvFile($size, $file) or protoFail();
    umask($old);
  }
}

# launch different commands depending on the argument filetype
# (used to be more verbose when following directories)
sub filedirExec(&&@)
{
  my ($cfile, $cdir, @files) = @_;

  foreach my $file(@files)
  {
    if(-d $file) {
      finddepth2(sub{&$cdir($_)}, @files);
    } else {
      $_ = $file and &$cfile($file);
    }
  }
}

sub checkOut(\%@)
{
  my ($flags, @files) = @_;

  filedirExec(
    \&checkOutFile,
    sub
    {
      if(-f $_ && !-w $_)
      {
	msg("checking-out $_");
	checkOutFile($_);
      }
    },
    @files);

  return 1;
}

sub checkInShared($$)
{
  my ($remote, $file) = @_;
  sendFile($remote, $file) or protoFail();

  # reset file permissions
  chmod(0444, $file);
  expectC($Proto::READY) or protoFail();
}

sub checkInFile($$)
{
  my ($file, $comment) = @_;

  # file should be writable
  (-w $file) or fail("checkout \"$file\" first");
  my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});

  # request checkin
  sendStr($Proto::CHECKIN, encArr($remote, $comment));
  my $code = expectC($Proto::READY) or protoFail();
  checkInShared($remote, $file);
}

sub checkInExt($$)
{
  my ($file, $comment) = @_;

  # like checkInFile, but verbose
  my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});
  sendStr($Proto::CHECKIN, encArr($remote, $comment));
  my ($c, $str) = recvStr();
  defined($c) and ($c == $Proto::ERROR || $c == $Proto::READY) or protoFail();

  if($c == $Proto::ERROR) {
    msg("? $file");
  } else
  {
    msg("checking-in $file");
    checkInShared($remote, $file);
  }
}

sub checkIn(\%@)
{
  my ($flags, @files) = @_;
  my $comment = readComment("checkin", $flags->{"c"});

  filedirExec(
    sub
    {
      checkInFile($_, $comment);
    },
    sub
    {
      if(-f $_ && -w $_)
      {
	checkInExt($_, $comment);
      }
    },
    @files);

  return 1;
}

sub addFile($$)
{
  my ($file, $comment) = @_;

  # file should be writable
  (-w $file) or fail("\"$file\" already present");
  my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});

  # request add
  sendStr($Proto::ADD, encArr($remote, $comment));
  my $code = expectC($Proto::READY) or protoFail();
  sendFile($remote, $file) or protoFail();

  # reset file permissions
  chmod(0444, $file);
  expectC($Proto::READY) or protoFail();
}

sub add(\%@)
{
  my ($flags, @files) = @_;
  my $comment = readComment("add", $flags->{"c"});

  filedirExec(
    sub
    {
      addFile($_, $comment);
    },
    sub
    {
      if(-f $_ && -w $_)
      {
	msg("adding $_");
	addFile($_, $comment);
      }
    },
    @files);

  return 1;
}

sub revertFile($$)
{
  my ($flags, $file) = @_;
  my $reopen = defined($flags->{"r"});

  # file should be writable
  (-w $file) or fail("checkout \"$file\" first");
  my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});

  # request the old file
  sendStr(($reopen? $Proto::GET: $Proto::REVERT), encArr($remote));
  ($remote, my $size) = expectCV($Proto::XFER, 2);
  $remote or protoFail();

  # get the file
  recvFile($size, $file) or protoFail();
  chmod(0444, $file) unless($reopen);
}

sub revert(\%@)
{
  my ($flags, @files) = @_;
  my $reopen = defined($flags->{"r"});

  filedirExec(
    sub
    {
      revertFile($flags, $_);
    },
    sub
    {
      if(-f $_ && -w $_)
      {
	msg("reverting $_");
	revertFile($flags, $_);
      }
    },
    @files);

  return 1;
}

sub diffFile($$$)
{
  my ($flags, $file, $version) = @_;
  $version = $version || "";
  my $cksum = cksumFile($file);
  my $arg = ((defined($cksum)? $cksum: "") . $version);
  $arg = undef if($arg eq "");

  # request the head file
  my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});
  sendStr($Proto::GET, encArr($remote, $arg));
  my ($c, $str) = recvStr();
  defined($c) or protoFail();
  return ($c == $Proto::READY) if($c != $Proto::XFER);
  
  # the file exists and was modified
  ($remote, my $size) = decArr($str);
  $remote or protoFail();
  
  # write in a temporary file
  my $temp = tmpnam() or fail($!);
  recvFile($size, $temp) or protoFail();

  # diff the output
  print STDOUT "==== $remote$version - $file ====\n";
  STDOUT->flush();

  my @args = ("diff");
  push(@args, "-$flags->{'d'}") if($flags->{"d"});
  my $ret = system(@args, "--", $temp, $file);
  unlink($temp);
  return !$ret;
}

sub diff(\%@)
{
  my ($flags, @files) = @_;
  my $ret = 1;

  foreach my $file(@files)
  {
    ($file, my $version) = fileVersion($file);

    filedirExec(
      sub
      {
	diffFile($flags, $_, $version) or $ret = 0;
      },
      sub
      {
	diffFile($flags, $_, $version) or $ret = 0 if(-f $_);
      },
      $file);
  }

  return $ret;
}

sub deleteFile($$)
{
  my ($file, $force) = @_;

  # remove the file remotely first
  my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});
  sendStr($Proto::DELETE, encArr($remote, $force));
  my $code = expectC($Proto::READY) or protoFail();

  # remove the file locally
  forceUnlink($file);
  return prune(dirname($file));
}

sub delete(\%@)
{
  my ($flags, @files) = @_;
  my $force = defined($flags->{"f"});

  filedirExec(
    sub
    {
      deleteFile($_, $force);
    },
    sub
    {
      if(-f $_)
      {
	msg("deleting $_");
	deleteFile($_, $force);
      }
    },
    @files);

  return 1;
}

sub fileVersion($)
{
  my $file = shift;
  my ($path, $ver) = ($file =~ /^([^@#]*)([@#].*)?$/);

  # verify the version a bit before proceeding foolishly
  if(defined($ver))
  {
    unless($ver =~
	     m[^
               (?:
                 # numerical/head versions
                 \#(?:head|\d+)
               |
                 # labels/dates
                 \@(?:
                     # date/time
                     \d{4}/\d{2}/\d{2}(?:(?::\d{2}){3})?
                   |
                     # labels
                     [a-zA-Z].*
                   )
               )
             $]x) {
      fail("unrecognized version $ver");
    }

    # #head is actually the same as nothing
    $ver = undef if($ver eq "#head");
  }

  return ($path, $ver);
}

sub label(\%@)
{
  my ($flags, @files) = @_;
  my $label = $flags->{"l"} or fail("need a label name");

  foreach my $file(@files)
  {
    # label the file/dir
    ($file, my $version) = fileVersion($file);
    my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});
    sendStr($Proto::LABEL, encArr($remote, $label, $version));
    my $code = expectC($Proto::READY) or protoFail();
  }

  return 1;
}

sub getFVBuf($$)
{
  my ($file, $version) = @_;

  # request the file
  my $remote = getAbsMap($file, \@{$PARAMS{MAPS}});
  sendStr($Proto::GET, encArr($remote, $version));
  my ($void, $size) = expectCV($Proto::XFER, 2);
  $void or protoFail();

  # receive the data
  my $buf = recvBuf($size);
  defined($buf) or protoFail();

  return $buf;
}

sub catFile($$)
{
  my ($file, $version) = @_;
  print STDOUT getFVBuf($file, $version);
}

sub cat(\%@)
{
  my ($flags, @files) = @_;
  my $header = $flags->{"h"} || 0;

  foreach my $file(@files)
  {
    print STDOUT "==== $file ====\n" if($header);
    ($file, my $version) = fileVersion($file);
    catFile($file, $version);
  }

  return 1;
}

sub getFTmp($)
{
  my ($file, $version) = fileVersion(shift);
  my $buf = getFVBuf($file, $version);
  $file = tmpnam() or fail($!);

  open(FD, ">$file") or fail($!);
  print FD $buf;
  close(FD);

  return $file;
}

sub diff2(\%@)
{
  my ($flags, @files) = @_;
  my ($fileA, $fileB) = @files;
  ($fileA && $fileB) or fail("missing file arguments");

  # fetch the two files
  my $tmpA = getFTmp($fileA);
  my $tmpB = getFTmp($fileB);

  # diff
  print STDOUT "==== $fileA - $fileB ====\n";
  STDOUT->flush();
  my @args = ("diff");
  push(@args, "-$flags->{'d'}") if($flags->{"d"});
  my $ret = system(@args, "--", $tmpA, $tmpB);

  # remove temporals
  unlink($tmpA);
  unlink($tmpB);

  return !$ret;
}

sub genTemplate($)
{
  my $action = shift;
  my $file = tmpnam() or return undef;

  open(FD, ">$file") or return undef;
  print FD
      qq{# Enter a comment for $action. } .
      qq{Formatting is NOT preserved.\n};
  close(FD);

  return $file;
}

sub readTemplate($)
{
  my $file = shift;
  my $text = "";

  open(FD, "<$file") or return undef;
  while(<FD>)
  {
    next if(/^\s*$/ or /^\s*\#/);
    $text .= $_;
  }
  close(FD);
  chomp($text);
  
  # uniform spaces
  $text =~ s/[\s\n]+/ /mg;

  return $text;
}

sub mTime($)
{
  return (stat(shift))[9];
}

sub readComment($$)
{
  # try with the command line first
  my ($action, $comment) = @_;
  return $comment if(defined($comment));

  # generate a template
  my $file = genTemplate($action) or fail($!);
  my $itime = mTime($file);

  # invoke the editor
  system("$EDITOR -- '$file'");
  my $ntime = mTime($file);
  $comment = readTemplate($file);
  unlink($file) or fail($!);

  # check for changes
  fail("$action: file not changed, giving up") if($itime == $ntime);
  fail($!) unless(defined($comment));

  return $comment;
}


main();
