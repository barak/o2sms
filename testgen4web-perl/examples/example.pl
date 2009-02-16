#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use TestGen4Web::Runner;

use Getopt::Long;

use constant OFF => 0;
use constant ON => 1;

my $username;
my $password;
my $message;
my $signature = "";
my $config_file;
my $http_proxy;
my $carrier;
my $embedded = OFF;
my $split_messages = ON;
my $reuse_cookies = ON;
my $hard_split = OFF;
my $emulate_t9 = OFF;
my $squeeze_text = OFF;
my $debug = OFF;

sub version { print "3.0\n"; die; }

my $result = GetOptions (
		"username|u=s"	=> \$username,
		"password|p=s"	=> \$password,
		"message|m=s"	=> \$message,
		"sig|s=s"	=> \$signature,
		"config-file|c=s" => \$config_file,
		"http-proxy|P=s"	=> \$http_proxy,
		"carrier|C=s"	=> \$carrier,
		"embedded!"	=> \$embedded,
		"split-messages|s!"	=> \$split_messages,
		"reuse-cookies|r!"	=> \$reuse_cookies,
		"hard-split|k!"	=> \$hard_split,
		"emulate-t9|t9!"	=> \$emulate_t9,
		"squeeze-text|z!"	=> \$squeeze_text,
		"version|v"	=> \&version,
		"help|usage|h"	=> \&usage,
		"debug|verbose|d!"	=> \$debug,
		);

$message = 'ook' if (!defined($message));

print "message = $message \nhard-split = $hard_split \n";

print Dumper(@ARGV);

exit;

my $tgrun = new TestGen4Web::Runner;

$tgrun->verify_titles(0);
$tgrun->debug(0);
$tgrun->load("recorder_ex/o2_combo.xml");

$tgrun->set_replacement("username", "maackers");
$tgrun->set_replacement("password", "xx");
$tgrun->set_replacement("recipient", "xx");
$tgrun->set_replacement("message", "hurray!");

#o2_login($tgrun)
#&& o2_send($tgrun)
#;
 
print "Result: " . $tgrun->result . "\n";
print "Error: " . $tgrun->error . "\n";
print "Matches: \n" . Dumper($tgrun->matches);

sub o2_login
{
	my $tgrun = $_[0];

	return $tgrun->run(0,7);
}

sub o2_send
{
	my $tgrun = $_[0];

	return $tgrun->run(8);
}
