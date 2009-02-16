#!/usr/bin/perl

# squeeze test program
# $Id: squeeze-test.pl 103 2006-01-24 19:14:54Z mackers $

use strict;
use lib '/home/mackers/lib/perl5/site_perl/';
use Lingua::EN::Squeeze;

while (my $orig = <STDIN>) {
	print SqueezeText($orig);
}
