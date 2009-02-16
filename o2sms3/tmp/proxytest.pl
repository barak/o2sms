#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new();

$ua->env_proxy();

#$ua->proxy('http', 'http://proxy.sn.no:8001/');
#$ua->proxy('https', 'http://proxy.sn.no:8001/');

my $response = $ua->get("http://www.rte.ie/");
print Dumper($response);

$response = $ua->get("https://www.365online.com/");
print Dumper($response);

