# Cksym - file checksum
# Copyright(c) 2005 of wave++ (Yuri D'Elia)
# Distributed under GNU LGPL without ANY warranty.
package Cksum;
use strict;

BEGIN
{
  use Exporter;
  use vars qw(@ISA @EXPORT);
  @ISA = qw{Exporter};
  @EXPORT = qw{&cksumFile &cksumBuf};
}

use Digest::MD5 qw{md5_base64};


sub cksumBuf($)
{
  return md5_base64(shift);
}

sub cksumFile($)
{
  my ($file) = @_;
  my $h = new Digest::MD5;

  open(FD, "<$file") or return undef;
  while(my $line = <FD>) {
    $h->add($line);
  }
  close(FD);

  return $h->b64digest();
}


1;
