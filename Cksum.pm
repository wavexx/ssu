# Cksym - file checksum
# Copyright(c) 2005 of wave++ (Yuri D'Elia)
# Distributed under GNU LGPL without ANY warranty.
#
# We use unpack() here, which is available everywhere, but we should rather
# switch to MD5 or a better hashing function.
package Cksum;
use strict;

BEGIN
{
  use Exporter;
  use vars qw(@ISA @EXPORT);
  @ISA = qw{Exporter};
  @EXPORT = qw{&cksumFile &cksumBuf};
}


sub cksumBuf($)
{
  return (unpack("%16C*", shift) % 65536);
}

sub cksumFile($)
{
  my ($file) = @_;
  my $cksum = 0;

  open(FD, "<$file") or return undef;
  while(my $line = <FD>) {
    $cksum += unpack("%16C*", $line);
    $cksum %= 65536;
  }
  close(FD);

  return $cksum;
}


1;
