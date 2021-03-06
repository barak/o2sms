#!/usr/bin/perl
# $Id: o2sms 350 2008-11-27 13:40:14Z mackers $

=head1 o2sms

o2sms - A perl script to send SMS messages using .ie websites.

=head1 DESCRIPTION

C<o2sms> is a script to send SMS messages via the command line using the websites
of Irish mobile operators. This is done by simulating a web browser's
interaction with those websites. This script requires a valid web account with
O2 Ireland, Vodafone Ireland or Meteor Ireland.
 
The author accepts no responsibility nor liability for your use of this
software.  Please read the terms and conditions of the website of your mobile
provider before using the program.

=cut

use strict;
use warnings;
use vars qw( $VERSION );
#$VERSION = sprintf("3.%02d", q$Revision: 350 $ =~ m/(\d+)/);
$VERSION = '3.35';

# -- modules
use File::stat;
use Getopt::Long 2.33;
use Pod::Usage;
#use Term::ReadLine;
#use POSIX qw(strftime);
#use threads;
#use threads::shared;

$|++;

# -- constants
use constant OUTPUT_AUTOFLUSH_BUFFERED  => 0;
use constant OUTPUT_AUTOFLUSH_UNBUFFERED => 1;
use constant OFF => 0;
use constant ON => 1;
use constant EXIT_SUCCESS => 0; 
use constant EXIT_FAILURE => 1; # shell error status

# -- global vars
my $svnid = '$Id: o2sms 350 2008-11-27 13:40:14Z mackers $';

my $sms_max_length = 500;
my $man_delim = "\\\\\\\\";
my $single_max_length;

my $username;
my $password;
my $message;
my $signature = "";
my $config_file;
my $config_dir;
my $http_proxy;
my $https_proxy;
my $carrier_name;
my $embedded = OFF;
my $split_messages = ON;
my $reuse_cookies = ON;
my $hard_split = OFF;
my $emulate_t9 = OFF;
my $squeeze_text = OFF;
my $write_history = OFF;
my $debug_really_send = ON;
my $debug_level = 0;
my $readline_support = 0;
my $widdley_enabled = 0;

my $term;
my $carrier;
my %recipients;
my @ARGV_recipients;
my @message_parts;
my $message_whole;
my %aliases;
my $RL_OUT = \*STDOUT;

my @widdley_anim = qw"- \ | /";
#my @widdley_anim = qw". o O o";
my $widdley_after = 8;
my $widdley_on : shared = 0;
my $widdley_thread;

my %options = (
	"username|u=s"	=> \$username,
	"password|p=s"	=> \$password,
	"message|m=s"	=> \$message_whole,
	"sig|s=s"	=> \$signature,
	"config-file|c=s" => \$config_file,
	"data-dir=s" => \$config_dir,
	"http-proxy|proxy|P=s"	=> \$http_proxy,
	"https-proxy=s"	=> \$https_proxy,
	"carrier|C=s"	=> \$carrier_name,
	"embedded!"	=> \$embedded,
	"split-messages|split|s!"	=> \$split_messages,
	"reuse-cookies|reuse|r!"	=> \$reuse_cookies,
	"hard-split|k!"	=> \$hard_split,
	"emulate-t9|t9!"	=> \$emulate_t9,
	"squeeze-text|squeeze|z!"	=> \$squeeze_text,
	"history|h|"	=> \$write_history,
	#"version|v"	=> sub { &print_version_and_exit(0) },
	"help|usage|h"	=> sub { &print_usage_and_exit(0) },
	"debug|verbose|d|V+"	=> \$debug_level,
	"send!"	=> \$debug_really_send,
	);

$SIG{INT} = \&fade_away;

# -- migrate v2.x settings to v3
&migrate_settings();

# -- load config (and set up $carrier)
&load_configuration();
&log_debug("$0 version $VERSION");

# -- initialise readline

if (($readline_support) && ($^O ne 'darwin') && ($term = new Term::ReadLine $carrier->full_name()))
{
	$term->ornaments(0);
	$RL_OUT = $term->OUT || \*STDOUT;
	&log_debug("ReadLine support enabled");
}
else
{
	# darwin's readline hooks are very broken
	$RL_OUT = \*STDOUT;
	$readline_support = 0;
	&log_debug("ReadLine support disabled");
}

# -- process recipients

if (!(%recipients = &process_recipients(@ARGV_recipients)))
{
	&print_usage_and_exit(1);
}

# -- print welcome message

&log_info("recipient" . (scalar(keys(%recipients))>1?"(s)":"") . " : " . &prettyprint_recipients(%recipients));

# -- read and process the message

if (!defined($message_whole))
{
	#read message
	$message_whole = &read_message();
}

if (!defined($message_whole) || (length($message_whole) == 0))
{
	&fade_away();
}

@message_parts = &process_message($message_whole);

if (scalar(@message_parts) == 0)
{
	&fade_away();
}

# -- login and send the message

if (($reuse_cookies == ON) && $carrier->is_logged_in())
{
	&log_info("reusing last login for $username\@" . $carrier->domain_name() . " ...");
}
else
{
	&log_info("logging in to $username\@" . $carrier->domain_name() . " ...");

	# -- get a password
	if (!defined($password))
	{
		$password = &read_password();
	}

	# -- start a widdley
	&widdley_start();

	my $retval = $carrier->login($username, $password);

	# -- stop the widdley
	&widdley_stop();

	if ($retval)
	{
		&log_info("login successful");
	}
	else
	{
		&log_fatal("login failed; " . $carrier->error());
	}
}

NUMBER: foreach my $number (keys(%recipients))
{
	my $message_part_number = 1;
	my $message_part_count = scalar(@message_parts);
	my $delay;

	MESSAGE: foreach my $message_part (@message_parts)
	{
		RETRY: while (1)
		{
			# -- start a widdley
			&widdley_start();

			# if delay > 0, tell the user
			($delay = $carrier->delay($message_part)) && &log_info("sending message after $delay seconds ...");

			my $retval = $carrier->send($number, $message_part);

			&widdley_stop();

			if ($retval)
			{
				my $sent_msg 	= "message "
						. ($message_part_count>1?"(part $message_part_number of $message_part_count) ":"")
						. "sent to $number, "
						. $carrier->remaining_messages() . " remaining this month";

				&log_info($sent_msg);

				last RETRY;
			}
			else
			{
				&log_error("message sending failed; " . $carrier->error());

				if (!yn_prompt("Retry ?"))
				{
					&log_fatal("okay, I'm outta here");
				}
                                else
                                {
                                    if (!$carrier->is_logged_in())
                                    {
                                        # user has been logged out in the time it took to get a y/n - log in again
                                        &log_info("login timeout; attempting a relogin ...");

                                        my $retval = $carrier->login($username, $password);

                                        if (!$retval)
                                        {
                                            &log_fatal("relogin failed; " . $carrier->error());
                                        }
                                    }
                                }
			}
		}

		$message_part_number++;
	}
}

# -- do exity stuff

&log_debug("will write to message and/or history files");
$carrier->write_message_file($message_whole);
$carrier->write_history_file($message_whole, &prettyprint_recipients(%recipients)) if ($write_history);

&save_aliases();

# -- quit with success
exit(0);

# -- subs

sub guess_carrier_name
{
	if ($0 =~ m/voda(fone)?sms(\.pl)?$/i)
	{
		return "vodafone";
	}
	elsif ($0 =~ m/met(eor)?sms(\.pl)?$/i)
	{
		return "meteor";
	}
	elsif ($0 =~ m/o2sms(\.pl)?$/i)
	{
		return "o2";
	}
	elsif ($0 =~ m/(three|3)sms(\.pl)?$/i)
	{
		return "three";
	}
	elsif ($0 =~ m/aft(sms)?(\.pl)?$/i)
	{
		return "aft";
	}
	else
	{
		return undef;
	}
}

sub get_username
{
	unless (&is_win32())
	{
		return ( getpwuid $< ) [0];
	}

	return "user";
}

sub is_win32
{
	return ($^O eq 'MSWin32');
}

sub print_usage_and_exit
{
	pod2usage(-exitval => $_[0], -verbose => 1);
}

#sub print_version_and_exit
#{
#	print "$0 version $VERSION\n";
#	exit($_[0]);
#}

sub process_command_line_options
{
	Getopt::Long::Configure("bundling_override");
	Getopt::Long::Configure("prefix_pattern=-+");
	Getopt::Long::Configure("auto_version");

	my @ARGV_original = @ARGV;
	$debug_level = 0;

	GetOptions(%options) or &print_usage_and_exit(1);
	
	# recipents are now in $ARGV
	@ARGV_recipients = @ARGV;
	@ARGV = @ARGV_original;

	return 1;
}

# load configuration from the command line and/or conf file
sub load_configuration
{
	# parse arguments
	&process_command_line_options();

	if (defined($config_file))
	{
		# another conf file has been specified, read that...
		if (!&read_config_file($config_file))
		{
			&log_error("can't read the configuration file '$config_file'");
		}

		# ... and load the command line options again to overwrite defaults in config file
		&process_command_line_options();
	}

	if (!defined($carrier_name))
	{
		# carrier not configured, try to guess based on name of program
		if (!($carrier_name = &guess_carrier_name()))
		{
			&log_fatal("don't know what sms service provider to use");
		}
	}

	# set up carrier object 
	$carrier = &get_carrier($carrier_name);

	# if an alternative data directory was specified, use that now.
	if ($embedded == ON)
	{
		$carrier->config_dir("/tmp/"); # won't be used in embedded mode anyway
	}
	elsif (defined($config_dir))
	{
		if ($carrier->config_dir($config_dir))
		{
		}

		&log_debug("using data dir: $config_dir");
	}

	#if (defined($config_file))
	#{
	#	&log_debug("using configuration file '$config_file'");
	#}
	#else
	#{
	#	&log_debug("using default configuration file '" . $carrier->config_file() . "'");
	#}

	if (!defined($config_file))
	{
		# read the default config file ...
		if (!(-f $carrier->config_file()))
		{
			&log_debug("No configuration file at '" . $carrier->config_file() . "'");
		}
		else
		{
			if (!&read_config_file($carrier->config_file()))
			{
				&log_error("can't read the configuration file '" . $carrier->config_file() . "'");
			}

			$config_file = $carrier->config_file();

			# ... and load the command line options again to overwrite defaults in config file
			&process_command_line_options();
		}
	}

	# set embedded options
	if ($embedded == ON)
	{
		$| = OUTPUT_AUTOFLUSH_UNBUFFERED; 
		$carrier->history_file("");
		$carrier->message_file("");
	}

	# adjust the adjusted max length (with sig)
	$single_max_length = $carrier->max_length() - length($signature);

	# check that we have squeeze support, if requested
	if ($squeeze_text == ON)
	{
		eval 'use Lingua::EN::Squeeze';

		if ($@)
		{
			&log_fatal("cannot squeeze this message: $@");
		}
	}

	if (!defined($username))
	{
		$username = &get_username();
	}

	# proxy setting up
	if (defined($http_proxy) && $http_proxy ne "")
	{
		$carrier->user_agent()->proxy('http', $http_proxy);

		# work around bug for LWP::UserAgent HTTPS proxy support
		$carrier->user_agent()->proxy('https', undef);

		if (defined($https_proxy))
		{
			$ENV{'https_proxy'} = $https_proxy;
			#$carrier->user_agent()->proxy('https', $https_proxy);
		}
		else
		{
			$ENV{'https_proxy'} = $http_proxy;
			#$carrier->user_agent()->proxy('https', $http_proxy);
		}
	}
        else
        {
            # user hasn't specified proxy - let user agent decide what proxy to use
            $carrier->user_agent()->env_proxy(1);
        }

	# do any other carrier setting up stuff
	$carrier->debug($debug_level);
	$carrier->dummy_send(!$debug_really_send);
}

sub process_recipients
{
	my @recips2;
	my %recipients;
	my $recip;

	# explode groups
	foreach $recip (@_)
	{
		if (ref($aliases{$recip}) eq 'ARRAY')
		{
			# is a group
			push (@recips2, @{$aliases{$recip}});
	 	}
		else
		{
			# is something else
			push (@recips2, $recip);
		}
	}

	# convert aliases to numbers and numbers to aliases
	for (my $i=0; $i<scalar(@recips2); $i++)
	{
		$recip = $recips2[$i];

		if ($recip =~ m/[^\d\s\-\+]/)
		{
			# has non-numeric character - might be alias
			if (exists($aliases{$recip}))
			{
				my $number = $aliases{$recip};
				$recipients{$number} = $recip;
			}
			else
			{
				&log_fatal("not a valid alias: '$recip'");
			}
		}
		else
		{
			my $recip_name = "";

                        $recip =~ s/[\s\-]//;

			# user provided number -- alias might exist
			while (my ($name, $number) = each(%aliases))
			{
				if ($recip == $number)
				{
					$recip_name = $name;
					last;
				}
			}

			# a regular number
			$recipients{$recip} = $recip_name;
		} 
	}

	# ok -- format numbers how we like 'em
	my %recipients2;

	while (my ($number, $name) = each(%recipients))
	{
		# check number
		my $std_number = $carrier->validate_number($number);

		if ($std_number == -1)
		{
			&log_fatal($carrier->validate_number_error());
		}

		if ($number ne $std_number)
		{
			&log_debug("changed $number to $std_number");
		}

		$recipients2{$std_number} = $name;
	}

	return %recipients2;
}

sub t9ify
{
	my $message = $_[0];

	$message =~ s/(^\w)/uc($1)/gsme;
	$message =~ s/([\.\?\!:\\]\s*)(\w)/$1 . uc($2)/gsme;

	return $message;
}

sub process_message
{
	my $message = $_[0];
	my @message_parts;

	# kill the last new line
	chomp($message);

	# make other newlines spaces
	# TODO make this configurable?
	#$message =~ s/\n/ /gsm;

	# if wanted, use Lingua::EN::Squeeze to squeeze text
	if ($squeeze_text == ON)
	{
		my $prelength = length($message);
		$message = SqueezeText($message);

		&log_debug("squeezed message (" . int(length($message)/$prelength*100) . "% compression): $message");
	}
	elsif ($emulate_t9 == ON)
	{ 
		# capitalise first letter of every sentence 
		$message = &t9ify($message);
	}

	#$message =~ s/^$man_delim//; # remove unneeded splitters
	#$message =~ s/$man_delim$//; # remove unneeded splitters

	# truncate message to maximum length
	if (length($message) > $sms_max_length)
	{
		&log_warning("very long message, truncating to $sms_max_length chars");
		$message = substr($message,0,$sms_max_length);
	}

	# check do we need to split up the message
	if ((length($message) > $single_max_length) || ($message =~ m/$man_delim/))
	{
		if (($split_messages == OFF) && ($message !~ m/$man_delim/))
		{
			&log_fatal("message is too long (" . length($message) . "/$single_max_length), exitting");
		}

		my $restmsg = $message;
		my $partmsg;

		while ((length($restmsg) > $single_max_length) || ($restmsg =~ m/$man_delim/))
		{
			# if manual split, and message part can fit, then add the first bit and loop
			if ($restmsg =~ m/^(.*?)$man_delim(.*)/sm)
			{
				if (length($1) < $single_max_length)
				{
					$partmsg = $1;
					$restmsg = $2;
					push (@message_parts, $partmsg) if ($partmsg =~ m/\S/);
					next;
				}
			}

			# if we don't want to split..
			if ($split_messages == OFF)
			{
				&log_fatal("message part " . (scalar(@message_parts) + 1) . " is too long (" . length($restmsg) . "/$single_max_length), exitting");
			}

			# message too long, split at the most natural place
			if ($hard_split == ON)
			{
				($partmsg, $restmsg) = &split_message_hard($single_max_length, $restmsg);
			}
			else
			{
				($partmsg, $restmsg) = &split_message($single_max_length, $restmsg);
			}

			push (@message_parts, $partmsg) if ($partmsg =~ m/\S/);
		}

		push (@message_parts, $restmsg . $signature) if ($restmsg =~ m/\S/);

		&log_warning("long or split message, splitting into " . scalar(@message_parts) . " parts");
	}
	else
	{
		push (@message_parts, $message . $signature);
	}

	# fill the end of each message part with white spaces to clear the "free web text" ad
	#foreach my $message_part (@message_parts)
	#{
	#	my $msg_fill = " " x ($single_max_length - length($message_part) + length($signature));
	#	$message_part .= $msg_fill;
	#}

	return @message_parts;
}

# -- save alias
sub save_aliases
{
	return if (&is_win32()); # a few things inexplicibly don't work on win32 in this method

	if (!(&is_interactive))
	{
		return;
	}

	if (!defined($config_file))
	{
		return;
	}

	RECIPIENT: while (my ($number, $name) = each(%recipients))
	{
		ALIAS: foreach my $anumber (values %aliases)
		{
			if ($anumber == $number)
			{
				next RECIPIENT;
			}
		}

		PROMPT: while ($name eq "")
		{
			print $RL_OUT "[ create alias for '$number' with this name : ] ";

			my $name4num = <STDIN>;

			chomp($name4num);

			if ($name4num !~ m/\S/)
			{
				last;
			}
			elsif ($name4num !~ m/[\w\.\-\_]+/)
			{
				&log_error("invalid alias name '$name4num'");
			}
			elsif (exists($aliases{$name4num}))
			{
				&log_error("alias already exists");
			}
			elsif (open(ALIASFILE, ">>" . $config_file))
			{
				print ALIASFILE "\nalias $name4num $number";
				close ALIASFILE;
				last;
			}
			else
			{
				&log_fatal("can't write to configuration file '$config_file'");
			}
		}
	}
}

sub split_message
{
	my ($len, $message) = @_;

	# split the message on a break between words..
	# find the position of the last ' ' in the sentance
	my $pos = index(reverse(substr($message,0, $len-3)), ' ');
	$pos = $len - 3 - $pos;

	# the part the message to send
	my $partmessage = substr($message, 0, $pos-1);
	# the remaining part of the message
	my $restofmessage = substr($message, $pos);

	return ($partmessage, $restofmessage);
}

sub split_message_hard
{
	my ($len, $message) = @_;

	# the part the message to send
	my $partmessage = substr($message, 0, $len);
	# the remaining part of the message
	my $restofmessage = substr($message, $len);

	return ($partmessage, $restofmessage);
}

sub read_config_file
{
	# check file exists
	if (!(-f $_[0]))
	{
		&log_error("not a valid file: " . $_[0]);

		return 0;
	}

	# check config file isn't world readble
	my $config_file_info = stat($_[0]);

	if (($config_file_info->mode & 004) && (!&is_win32()))
	{
		&log_warning($_[0] . " is world readable");
	}

	# read the file
	if (!(open(SMSCONF, $_[0])))
	{
		&log_error("can't open file '" . $_[0] . "'");

		return 0;
	}

	&log_debug("reading config file '" . $_[0] . "'");

	my @conf_args;
	my $line = 1;

	while (<SMSCONF>)
	{
		chomp();
		next if (/^#/);

		if (/^\s*alias\s*([\w\.\-\_]*)\s*(\+?\d*)\s*$/i)
		{
			my $std_number = $2;

			if (defined($carrier))
			{
				# can only validate number if carrier has been defined
				# meaning if won't work when specifying config file on the command line
				$std_number = $carrier->validate_number($2);

				if ($std_number == -1)
				{
					&log_error("not a valid alias number in " . $_);
					next;
				}
			}

			$aliases{$1} = $std_number;
			&log_debug("added alias for $1 = $std_number", 2);
		}
		elsif (/^\s*alias\s*([\w\.\-\_]*)\s*([\w\d\s\+]*)\s*$/i)
		{
			my @group = split(/\s+/,$2);
			@{$aliases{$1}} = @group;
			&log_debug("added group for $1 (" . join(", ",@{$aliases{$1}}) . ")", 2);
		}
		elsif ((/^\s*([\w\-]+)\s*(\S*)\s*$/) ||
			(/^\s*([\w\-]+)\s*"(.*?)"\s*$/))
		{
			my $key = $1;
			my $value = $2;

			&log_debug("added configuration option '$1'" . ($2?" = '$2'":""), 2);

			push(@conf_args, "-$1");
			push(@conf_args, $2) if ($2);
		}
		elsif (/\S/)
		{
			&log_warning("can't parse line $line of configuration file '$_[0]': '$_'");
		}

		$line++;
	}

	# use GetOptions to parse config file options, which are now in @conf_args

	if (@conf_args)
	{
		my @ARGV_original = @ARGV;
		@ARGV = @conf_args;
		GetOptions(%options) or &log_warning("there was an error processing the configuration file");
		@ARGV = @ARGV_original;
	}

	close (SMSCONF);
	return 1;
}

sub get_carrier
{
	# create and return a carrier object based on name in $_[0]
	use WWW::SMS::IE::iesms;

	if ($_[0] eq "meteor")
	{
		use WWW::SMS::IE::meteorsms;
		return WWW::SMS::IE::meteorsms->new;
	}
	elsif ($_[0] eq "vodafone")
	{
		use WWW::SMS::IE::vodasms;
		return WWW::SMS::IE::vodasms->new;
	}
	elsif ($_[0] eq "o2")
	{
		use WWW::SMS::IE::o2sms;
		return WWW::SMS::IE::o2sms->new;
	}
	elsif ($_[0] eq "three")
	{
		use WWW::SMS::IE::threesms;
		return WWW::SMS::IE::threesms->new;
	}
	elsif ($_[0] eq "aft")
	{
		use WWW::SMS::IE::aftsms;
		return WWW::SMS::IE::aftsms->new;
	}
	else
	{
		&log_fatal("Invalid carrier name '" . $_[0] . "'");
	}

}

sub is_interactive
{
	return ((-t STDIN) && (-t STDOUT) && ($embedded != ON));
}

sub prettyprint_recipients
{
	my %recipients = @_;
	my $ret = "";

	while (my ($number, $name) = each(%recipients))
	{
		if ($name ne "")
		{
			# is alias, print both
			$ret .= "$name ($number) ";
		}
		else
		{
			# just number
			$ret .= "$number ";
		}
	}

	chop($ret);

	return $ret;
}

sub migrate_settings
{
	return if (&is_win32());

	return if (!&is_interactive());
	
	return if (!defined $ENV{HOME});

	return if (!(
		(-f $ENV{HOME} . "/.o2smsrc") || 
		(-f $ENV{HOME} . "/.vodasmsrc") ||
		(-f $ENV{HOME} . "/.meteorsmsrc")
		));

	return if (!&yn_prompt("migrate v2 settings to v3 ?"));

	if (-f $ENV{HOME} . "/.o2smsrc")
	{
		mkdir($ENV{HOME} . "/.o2sms", 0700);

		rename($ENV{HOME} . "/.o2smsrc", $ENV{HOME} . "/.o2sms/config") &&
		&log_info("Moved configuration file to '" . $ENV{HOME} . "/.o2sms/config'");
	}

	unlink($ENV{HOME} . "/.o2smsmsg");
	unlink($ENV{HOME} . "/.o2smscookie");

	if (-f $ENV{HOME} . "/.vodasmsrc")
	{
		mkdir($ENV{HOME} . "/.vodasms", 0700);

		rename($ENV{HOME} . "/.vodasmsrc", $ENV{HOME} . "/.vodasms/config") &&
		&log_info("Moved configuration file to '" . $ENV{HOME} . "/.vodasms/config'");
	}

	unlink($ENV{HOME} . "/.vodasmsmsg");
	unlink($ENV{HOME} . "/.vodasmscookie");

	if (-f $ENV{HOME} . "/.meteorsmsrc")
	{
		mkdir($ENV{HOME} . "/.meteorsms", 0700);

		rename($ENV{HOME} . "/.meteorsmsrc", $ENV{HOME} . "/.meteorsms/config") &&
		&log_info("Moved configuration file to '" . $ENV{HOME} . "/.meteorsms/config'");
	}

	unlink($ENV{HOME} . "/.meteorsmsmsg");
	unlink($ENV{HOME} . "/.meteorsmscookie");
}

sub widdley_start
{
	return unless ($widdley_enabled);
	return unless (&is_interactive());

	&log_debug("starting widdley thread...", 2);

	$widdley_thread = threads->new(\&widdley_run) if $widdley_enabled;
	$widdley_on = 1;
}

sub widdley_stop
{
	return unless ($widdley_enabled);
	return unless (&is_interactive());

	&log_debug("stopping widdley thread...", 2);

	$widdley_on = 0;
	return if (!defined($widdley_thread));
	$widdley_thread->join();
	#$widdley_thread->detach();
	undef($widdley_thread);
}

sub widdley_run
{
	for (my $i=0; $i<$widdley_after; $i++)
	{
		sleep(1);

		return if (!$widdley_on);
	}

	print " ";

        while ($widdley_on)
        {
                my $char = shift(@widdley_anim);
                push(@widdley_anim, $char);

                print "\b$char";

		# wait for 100ms
                select(undef, undef, undef, 0.1);
        }

	print "\b";
}

sub read_message
{
	my $message;

	if ($readline_support)
	{
		while (defined($_ = $term->readline('')))
		{
			last if (/^\.$/);
			$message .= $_;
		}

		$term->addhistory($message) if ($message =~ m/\S/);
	}
	else
	{
		while (<STDIN>)
		{
			last if (/^\.$/);
			$message .= $_;
		}
	}

	return $message;
}

sub read_password
{
	if (!(&is_interactive()))
	{
		return "<undefined>";
	}

	my $password;

	system "stty -echo" unless (&is_win32()); # Echo off
	
	print $RL_OUT "[ password : ] "; # Prompt for password
	chomp($password = <STDIN>); # Remove newline

	system "stty echo" unless (&is_win32()); # Echo on
	print "\n";

	return $password;
}

sub yn_prompt
{
	return undef if (!is_interactive());

	my $prompt = $_[0];

	print $RL_OUT "[ $prompt y/n [n] : ] ";

	my $resp = <STDIN>;

	return (defined($resp) && ($resp =~ m/^y/i));
}

sub log_debug
{
	if (!defined($_[1]))
	{
		$_[1] = 1;
	}

	if ($debug_level >= $_[1])
	{
		print "iesms: $_[0]\n";
	}
}

sub log_info
{
	print $RL_OUT "[ $_[0] " unless (!defined($_[0]));
	print $RL_OUT "]\n" unless $_[1];
}

sub log_error
{
	print STDERR "[ $_[0] ]\n";
}

sub log_fatal
{
	print STDERR "[ $_[0] ]\n" if ($_[0]);
        $? = EXIT_FAILURE;
	exit(EXIT_FAILURE);
}

sub log_warning
{
	print STDERR "[ warning : $_[0] ]\n";
}

sub fade_away
{
	&widdley_stop();

	system "stty echo" unless (&is_win32()); # Echo on if cancel during a password read

	&log_info("okay, I'm outta here.");
	exit(EXIT_SUCCESS);  
}

__END__

=head1 SYNOPSIS

  o2sms [options] <number|alias|group> [<number|alias|group> ...]

  The message will be read from standard input; either pipe some text
  or type the message, ending with CTRL-d or the . character on a line
  by itself.

=head1 OPTIONS

=over 8

=item B<-u, --username=STRING>

Use this username (defaults to unix username)

=item B<-p, --password=STRING>

Use this password (it omitted, will prompt for password)

=item B<-c, --config-file=FILE>

Use this configuration file (defaults to ~/.o2sms/config)

=item B<--data-dir=DIR>

Use this dir for cookie files, state files and log files. (defaults to ~/.o2sms/)

=item B<-r, --reuse-cookies>

Reuse cookies if possible (the default)

=item B<-s, --split-messages>

Allow message to be split in multiple SMSs (the default)

=item B<-k, --hard-split>

Allow message to be split in the middle of a word

=item B<-z, --squeeze-text>

Squeezes text (e.g. mak txt msg as smal as psble)

=item B<-t9, --emulate-t9>

Emulate t9 behaviour

=item B<-P, --http-proxy=URL>

Use this HTTP proxy (defaults to the HTTP_PROXY environment variable, if present)

=item B<--https-proxy=URL>

Use this HTTPS proxy (defaults to the HTTP proxy or HTTPS_PROXY environment variable, if present)

=item B<-s, --sig=STRING>

Append this text to every message

=item B<-C, --carrier=NAME>

Force the carrier to be this ("o2", "vodafone", "meteor" or "three" (or "aft"))

=item B<-m, --message=STRING>

Don't wait for STDIN, send this message

=item B<-h, --history>

Keep a history file (in ~/.o2sms/history)

=item B<--embedded>

Embedded mode, don't prompt for anything.

=item B<-h, --help>

Prints this help message and exits

=item B<-d, --debug>

Debug mode (use twice for more verbose output)

=item B<--version>

Print version and exit

=back

=head1 CONFIGURATION FILE

Configuration is in the file C<~/.o2sms/config> (or C<~/.vodasms/config> or
C<~/.meteorsms/config> or C<~/.threesms/config>) (or C<~/.aftsms/config>) or
can be overwritten with the -c / --config-file command line option.

Values in this file are stored as one per line and take the same name and
format as their command line equivalents.

The one exception to this is the 'alias' setting, which defines a named alias
for one number (a straight alias) or more than one number (a group).

Configuration file example:

  username frankc
  password mong0l0id
  nosplit
  alias mammy +353865551234
  alias beerpeople +353865550000 +353865550001 +353865550002
  # a comment

=head1 SEE ALSO

L<WWW::SMS::IE::iesms>,
L<WWW::SMS::IE::o2sms>,
L<WWW::SMS::IE::vodasms>,
L<WWW::SMS::IE::threesms>,
L<WWW::SMS::IE::aftsms>,
L<WWW::SMS::IE::meteorsms> 

L<http://www.mackers.com/projects/o2sms/>

=head1 AUTHOR

David McNamara (me.at.mackers.dot.com) et al

=head1 COPYRIGHT

Copyright 2000-2006 David McNamara

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

