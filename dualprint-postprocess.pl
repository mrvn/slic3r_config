#!/usr/bin/perl

# - duplicate all heating commands, once for each heater.
# - duplicate all motionless extrusion and retraction.
# - convert all extrusive motion to small double-extrusion plus movement pairs.

# post-processing scripts get the slic3r gcode file as parameter
# (to be edited in-place) and the slic3r settings in the environment.

# apparently the slic3r environment doesn't work (no variables set).
# However, the slic3r config is available as comments at the end of the gcode file.

use strict;
use warnings;
use POSIX qw(ceil);
use List::Util qw(any);

# minimum E way per extrusion. TODO: maybe this is too high?
my $de = 0.1;

# FIXME: printer stutters. Probably too many commands per second? Or the accelleration logic can't optimize the move/extrude switches? Can we get rid of the tool changes and provide a T parameter in G0/G1?

#my $pos = [0,0,0,0,0];
my $pos = { qw(X 0 Y 0 Z 0 E 0 F 0) };
my $tool = 0;

my $processing = 1;
my $lines = 0;
my $endline = undef;

# FIXME: we assume a lot here: absolute coordinates, millimeters, two extruders, no circles,...

local $^I="";
while (<>) {
  s/;.*//; s/^\s*//;
  next if $_ eq "";
  if ($processing && /^([GMT])(\d+)\s+(.*)/) {
    my ($mode,$code,$args) = ($1,$2,$3);
    if ($mode eq "M") {
      if ($code == 104) {
        $_ = "M104 T0 $args\nM104 T1 $args\n";
      } elsif ($code == 109) {
        $_ = "M104 T0 $args\nM104 T1 $args\nM109 T0 $args\nM109 T1 $args\n";
      }
    } elsif ($mode eq "G") {
      #if ($code == 0 || $code == 1 || $code == 28 || $code == 92) {
      my %xyzef;
      my @axes;
      my $old_pos = $pos;
      while ($args =~ /\b([XYZEF])(\S*)/g) {
        $xyzef{$1} = $2+0;
        push @axes, $1;
      }
      # Don't use a hash slice here! grep and any impose an lvalue
      # context on the slice and thus auto-vivificate the fields.
      my $has_pos = any { exists $xyzef{$_} } qw(X Y Z);
      #die "has_pos = 0" if !$has_pos && ($xyzef{X} || $xyzef{Y} || $xyzef{Z});
      my $has_e = exists $xyzef{E};
#       for (qw(X Y Z E F)) {
#         die "pos{$_} not defined: ".join(",",map "$_$pos->{$_}",keys %$pos) if !defined $pos->{$_};
#         die "old_pos{$_} not defined: ".join(",",map "$_$old_pos->{$_}",keys %$old_pos) if !defined $old_pos->{$_};
#       }
#       for (keys %xyzef) {
#         die "xyzef{$_} not defined: ".join(",",map "$_$xyzef{$_}",keys %xyzef) if !defined $xyzef{$_};
#       }
      if (%xyzef) {
        $old_pos = {%$old_pos};
        $pos->{$_} = $xyzef{$_} for keys %xyzef;
      }
#       for (qw(X Y Z E F)) {
#         die "pos{$_} not defined: ".join(",",map "$_$pos->{$_}",keys %$pos) if !defined $pos->{$_};
#         die "old_pos{$_} not defined: ".join(",",map "$_$old_pos->{$_}",keys %$old_pos) if !defined $old_pos->{$_};
#       }
      if ($code == 1 || $code == 0) {
        if ($has_e) {
          if ($has_pos) {
            # moving with extrusion.
            my $delta_e = $pos->{E}-$old_pos->{E};
            my $count = ceil($delta_e/$de);
            my $way = "";
            my $last_E = $old_pos->{E};
            for my $i (1..$count) {
              my %p = %xyzef;
              $p{$_} += ($old_pos->{$_}-$p{$_})*($count-$i)/$count for keys %p;
              #my %p = %$old_pos;
              #$p{$_} += ($pos->{$_}-$p{$_})*$i/$count for keys %p;
              my $newargs = join(" ",map "$_$p{$_}", @axes);
              $tool = 1-$tool;
              # extrude, change tool, reset E, move-extrude.
              $way .= "G$code E$p{E}\nT$tool\nG92 E$last_E\nG$code $newargs\n";
              $last_E = $p{E};
            }
            #$_ = ";way: ".
            $_ = join(",",@axes)."\n".$way;
          } else {
            # standing still, extruding. -> duplicate
            $tool = 1-$tool;
            #$_ = ";still:\n".
            $_ = "G$code $args\nT$tool\nG92 E$old_pos->{E}\nG$code $args\n";
          }
        } # otherwise just movement. No problem.
          #else {
          #  $_ = ";move:\n".$_;
          #}
      #} elsif ($code == 92) { # nothing to do (anymore)
      }
    } else { #T
      #die "file already uses multiple tools!"
      $processing = 0;
      $endline = $lines;
      # assume we're at the tool deactivation stage. Don't meddle with that.
    }
  }
  $lines++;
  print;
}

if (!$processing && $endline/$lines < 0.2) {
  die "almost nothing processed due to an early tool change!";
}

exit 0;
