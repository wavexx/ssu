# Proto - ssu protocol shared definitions
# Copyright(c) 2005 of wave++ (Yuri D'Elia)
# Distributed under GNU LGPL without ANY warranty.
package Proto;
use strict;

BEGIN
{
  no strict "vars";
  use Exporter;
  @ISA = qw{Exporter};
  @EXPORT = qw
  {
    &setupFd &sendStr &recvStr
    &encArr &decArr &expectCV &expectC &getErr
    &sendBuf &sendFile &recvBuf &recvFile
  };

  # general parameters
  $PORT		= 5901;	# default port number

  # server requests
  $LOGIN	= 100;	# login request

  # client requests
  $USRPWD	= 200;	# user/password data
  $GET		= 201;	# get/update a file
  $CHECKOUT	= 202;	# checkout a file
  $CHECKIN	= 203;	# checkin a file
  $REVERT	= 204;	# revert/undoes a checkout
  $DELETE	= 205;	# delete the remote file
  $LIST		= 206;	# remote directory listing
  $HISTORY	= 207;	# file log/history
  $STATUS	= 208;	# file status
  $LABEL	= 209;	# label/tag the head revision
  $TEST		= 210;	# test for existente of a file
  $CKSUM	= 211;	# return the checksum of a file
  $ADD		= 212;	# add a new file

  # shared codes
  $INFO		= 300;	# addictional protocol debugging
  $READY	= 301;	# awaiting commands
  $ERROR	= 302;	# error in request
  $XFER		= 303;	# inbound data transfer request

  # test file types/codes
  $FREE		= 0;	# no file/dir
  $FILE		= 1;	# regular file
  $DIR		= 2;	# directory
}

use FileHandle;
use Text::ParseWords;

my $ERR = undef;


sub setupFd($)
{
  my ($fd) = @_;
  binmode($fd);
  select($fd);
  $fd->autoflush(1);
}

sub setErr($)
{
  $ERR = shift;
  return undef;
}

sub getErr()
{
  return $ERR;
}

sub sendStr(@)
{
  my ($code, $str) = @_;
  printf("%03d %s\n", $code, (defined($str)? $str: 1)) or
      return setErr($!);
}

sub recvStr()
{
  my $line;
  my $code;
  my $str;
  my $fd = select();

  do
  {
    no strict 'refs';
    $line = $fd->getline();
    if(defined($line) && $line =~ /^(\d+) (.*)$/)
    {
      $code = $1;
      $str = $2;
    }
    else
    {
      return setErr((eof($fd)?
		     "remote host closed connection":
		     "protocol error"));
    }
  }
  while($code == $Proto::INFO);

  return ($code, $str);
}

sub encArr(@)
{
  # encode an array of strings
  my (@data) = @_;

  foreach(@data)
  {
    next unless(defined);

    s/\\/\\\\/;
    s/\n/\\n/;
    if(/(^$|[\s"])/)
    {
      s/"/\\"/g;
      $_ = qq{"$_"};
    }
  }
  
  return join(' ', @data);
}

sub decArr($)
{
  # decode an array of strings
  return shellwords(shift);
}

sub expectCV(@)
{
  # fetch the data
  my ($code, $values) = @_;
  my $str = expectC($code) or return undef;
  
  # extract the values
  my @arr = decArr($str);
  (!$values || $#arr == $values - 1) or
      return setErr("unexpected number of arguments");

  return @arr;
}

sub expectC($)
{
  my $code = shift;

  # fetch the data
  my ($c, $str) = recvStr();
  (defined $c) or return undef;

  # check for remote errors
  return setErr("error: $str") if($c == $Proto::ERROR);
  return setErr("unexpected answer") if($c != $code);

  return $str;
}

sub sendBuf($$)
{
  my ($name, $buf) = @_;
  my $size = length($buf);
  sendStr($Proto::XFER, encArr($name, $size)) or return undef;
  print $buf or return setErr($!);
  return expectC($Proto::READY);
}

sub sendFile($$)
{
  my ($name, $path) = @_;
  my $buf = "";
  my $line;

  open(FD, "<$path") or return setErr($!);
  while($line = <FD>) {
    $buf .= $line;
  }
  close(FD);

  return sendBuf($name, $buf);
}

sub recvBuf($)
{
  no strict 'refs';
  my $size = shift;
  my $buf;
  if($size > 0) {
    read(select(), $buf, $size) or return setErr($!);
  } else {
    $buf = "";
  }
  sendStr($Proto::READY) or return undef;
  return $buf;
}

sub recvFile($$)
{
  my ($size, $path) = @_;
  my $buf = recvBuf($size);
  defined($buf) or return undef;
  (open(FD, ">$path") and print(FD $buf) and close(FD)) or return setErr($!);
  return 1;
}


1;
