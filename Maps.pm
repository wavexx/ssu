# Maps - filename/project mapping utilities
# Copyright(c) 2005 of wave++ (Yuri D'Elia)
# Distributed under GNU LGPL without ANY warranty.
package Maps;
use strict;

BEGIN
{
  use Exporter;
  use vars qw(@ISA @EXPORT);
  @ISA = qw{Exporter};
  @EXPORT = qw{&parseMaps &getMap &getInvMap};
}

use Text::ParseWords qw{shellwords};
require File::Spec;


sub localCanon($)
{
  my ($file) = @_;
  $file = File::Spec->canonpath($file);
  if($] < 5.006) {
    $file = lc($file) if($^O eq "MSWin32");
  } else {
    if(File::Spec->case_tolerant()) {
      $file = lc($file);
    }
  }

  return $file;
}

sub parseMaps($$)
{
  my ($home, $line) = @_;
  my @ret;

  my @words = shellwords($line);
  return undef if(!($#words % 2) || ($#words < 1));

  for(my $i = 0; $i < $#words; $i += 2) {
    my $file = localCanon(
      ($home? File::Spec->catdir($home, $words[$i]): $words[$i]));
    push(@ret, [$file, $words[$i + 1]]);
  }
  
  return \@ret;
}

# given a filename, remap the path accorting to the map table
sub getMapReal($$$$)
{
  my ($file, $maps, $a, $b) = @_;
  
  # first cleanup the path
  $file = localCanon($file);

  # search for a common prefix
  foreach my $map(@$maps)
  {
    my $path = $map->[$a];
    
    # check for coincident paths first
    return ($map->[$a], $map->[$b], File::Spec->curdir()) if($path eq $file);

    # proceed as usual
    $path .= ($^O eq "MSWin32"? "\\": "/");
    my $lf = length($file);
    my $lp = length($path);
    next if($lf < $lp);
    
    if(substr($path, 0, $lp) eq substr($file, 0, $lp)) {
      return ($map->[$a], $map->[$b], substr($file, $lp));
    }
  }

  return undef;
}

# given a filename, remap the path to remote syntax
sub getMap($$)
{
  my ($file, $maps) = @_;
  return getMapReal($file, $maps, 0, 1);
}


# given a filename, remap the path to local syntax
sub getInvMap($$)
{
  my ($file, $maps) = @_;
  return getMapReal($file, $maps, 1, 0);
}


1;
