#!/usr/bin/perl

use strict;
use warnings;
require TestGen4Web::Runner;

use lib '../lib';

my $runner = new TestGen4Web::Runner;

$runner->debug(1);

$runner->load('forms.action');

if (!$runner->run())
{
print $runner->error() . "\n";
}
