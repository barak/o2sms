#!/usr/bin/perl

use strict;
use threads;
use threads::shared;

$|++;

my @anim = ('-','\\','|','/');
my $runwiddley : shared = 1;

my $i;

my $thr = threads->new(\&sub1);

open OUT, ">out";

while ($i++ < 5000000)
{
        print OUT "$i\n";
}

close (OUT);

$runwiddley = 0;
$thr->join();

print "\bdone\n";

exit();

sub sub1
{
        while ($runwiddley)
        {
                my $char = shift(@anim);
                push(@anim, $char);

                print "\b$char";

                select(undef, undef, undef, 0.1);
        }
}
