# Parse - N=V style parser with line continuations
# Copyright(c) 2005 of wave++ (Yuri D'Elia)
# Distributed under GNU LGPL without ANY warranty.
package Parse;
use strict;

BEGIN
{
  use Exporter;
  use vars qw(@ISA @EXPORT);
  @ISA = qw{Exporter};
  @EXPORT = qw{&parse &parseWith};
}


sub parseWith($$)
{
  my ($line, $ret) = @_;
  my ($name, $value) = ($line =~ /^\s*([^=]+)\s*=\s*(.*)\s*$/);
  $ret->{$name} = $value if($name && defined $value);
  return !(defined $value);
}

sub parse($$)
{
  my ($file, $ret) = @_;
  my $buf = undef;

  open(FD, "<$file") or return undef;
  while(<FD>)
  {
    # remove comments
    s/\s*[#;].*$//;
    my ($text, $f) = /^(.*)(\\)$/;
    $text = $_ if(!$text);

    if($buf || $f)
    {
      $buf .= $text;
      if(!$f)
      {
	parseWith($buf, $ret);
	$buf = undef;
      }
    } else {
      parseWith($text, $ret);
    }
  }

  return 1;
}


1;
