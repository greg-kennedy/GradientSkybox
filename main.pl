#!/usr/bin/env perl
use strict;
use warnings;

# GradientSkybox.pl

# This is a program to render cube maps with gradient fades.
#  Images are spherically distorted, so that the result appears as a
#  sky "sphere" without visible edges

use Math::Trig qw(deg2rad cartesian_to_spherical pi);

# increase SIZE to take more samples (powers of 2, minus 1)
use constant SIZE => 255;
use constant H_SIZE => SIZE/2;

# DOWNSAMPLE is a division factor to merge multiple pixels
use constant DOWNSAMPLE => 1;

# globals
my %gradient;
my @points;

# Helper function: write a face to disk as a .ppm image
sub dump_face {
  my ($name, $image) = @_;

  my $output_size = (SIZE + 1) / DOWNSAMPLE;

  open my $fp, '>:raw', $name . '.ppm';
  print $fp "P6 $output_size $output_size 255\n";
  for my $y (0 .. $output_size - 1) {
    for my $x (0 .. $output_size - 1) {
      # supersample
      for my $c (0 .. 2) {
        my $color = 0;
        for my $j (0 .. DOWNSAMPLE - 1) {
          for my $i (0 .. DOWNSAMPLE - 1) {
            $color += $image->[$y * DOWNSAMPLE + $j][$x * DOWNSAMPLE + $i][$c] || 0;
          }
        }
        print $fp chr($color / (DOWNSAMPLE ** 2) + 0.5);
      }
    }
  }
}

# given an angle, return a color trio for the angle
sub interpolate {
  my ($angle) = @_;

  # determine the two user-specified points for
  #  the interval, by advancing until our angle lies between
  my $idx = 0;
  while ($idx + 1 < $#points &&
    $points[$idx + 1] < $angle) {
    $idx ++;
  }
  my ($start, $end) = ($points[$idx], $points[$idx + 1]);

  # perform lerp
  my $scale = ($angle - $start) / ($end - $start);
  #print STDERR "Angle = $angle, start = $start, end = $end, scale = $scale\n";

  my @color;
  foreach my $c (0 .. 2) {
    $color[$c] = $gradient{$start}[$c] + ($gradient{$end}[$c] - $gradient{$start}[$c]) * $scale;
  }

  return \@color;
}

##############################################################################
# The end cap angles are assumed to be 0 and 180
#  Cutoff for spherical images onto cubes is between 60 and 120 for
#  solid-colored caps
# please define colors as hex RRGGBB
die "Usage: $0 colorStart [color2:angle2] [color3:angle3] [...] colorEnd" unless @ARGV > 1;

for my $i (0 .. $#ARGV) {
  my ($angle, $color);
  if ($i == 0) {
    $angle = 0;
    $color = $ARGV[$i];
  } elsif ($i == $#ARGV) {
    $angle = pi;
    $color = $ARGV[$i];
  } else {
    ($color, $angle) = split /:/, $ARGV[$i];
    $angle = deg2rad($angle);
  }

  for my $c (0 .. 2) {
    $color .= '00';
    $gradient{$angle}[$c] = hex(substr($color, 0, 2));
    $color = substr($color, 2);
  }
}
@points = sort { $a <=> $b } keys %gradient;

print "Defined gradient stops:\n";
foreach my $idx (0 .. $#points) {
  printf("\t%02d: %f (%x %x %x)\n", $idx, $points[$idx], $gradient{$points[$idx]}[0], $gradient{$points[$idx]}[1], $gradient{$points[$idx]}[2]);
}

my @image;

# there are three images
#  roof first
for my $y (0 .. int(H_SIZE)) {
  my $t = ($y - H_SIZE) / H_SIZE;
  for my $x ($y .. int(H_SIZE)) {
    my $s = ($x - H_SIZE) / H_SIZE;
    # trace a ray from 0, 0, 0 through the unit sphere onto the edge of the box,
    #  and determine which angle it passed through unit sphere
    my (undef, undef, $phi) = cartesian_to_spherical($s, $t, 1);
    my $color = interpolate($phi);

    $image[$y][$x] = $color;
    $image[$y][SIZE - $x] = $color;
    $image[SIZE - $y][$x] = $color;
    $image[SIZE - $y][SIZE - $x] = $color;

    if ($x != $y) {
      $image[$x][$y] = $color;
      $image[$x][SIZE - $y] = $color;
      $image[SIZE - $x][$y] = $color;
      $image[SIZE - $x][SIZE - $y] = $color;
    }
  }
}
dump_face('UP', \@image);

# now in front
for my $z (0 .. SIZE) {
  # z scans from top to bottom though
  my $t = (H_SIZE - $z) / H_SIZE;
  for my $x (0 .. int(H_SIZE)) {
    my $s = ($x - H_SIZE) / H_SIZE;

    #  would usually have to do 4 takes but all 4 sides are identical with this gradient tool
    my (undef, undef, $phi) = cartesian_to_spherical($s, 1, $t);
    my $color = interpolate($phi);

    $image[$z][$x] = $color;
    $image[$z][SIZE - $x] = $color;
  }
}
dump_face('FRONT', \@image);

# finally, looking down
for my $y (0 .. int(H_SIZE)) {
  my $t = ($y - H_SIZE) / H_SIZE;
  for my $x ($y .. int(H_SIZE)) {
    my $s = ($x - H_SIZE) / H_SIZE;

    my (undef, undef, $phi) = cartesian_to_spherical($s, $t, -1);
    my $color = interpolate($phi);

    $image[$y][$x] = $color;
    $image[$y][SIZE - $x] = $color;
    $image[SIZE - $y][$x] = $color;
    $image[SIZE - $y][SIZE - $x] = $color;

    if ($x != $y) {
      $image[$x][$y] = $color;
      $image[$x][SIZE - $y] = $color;
      $image[SIZE - $x][$y] = $color;
      $image[SIZE - $x][SIZE - $y] = $color;
    }
  }
}
dump_face('DOWN', \@image);
