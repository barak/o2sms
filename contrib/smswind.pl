#!/usr/bin/perl

# smsWind is a grand script to send wind weather data to Irish mobile phone users.
# It stands on o2sms.pl from mackers.com

#### Start Simple/Default Configuration

my $remTempFls  = 1;
my $wDirName    = 'weather';
my $keepHistory = 1;
my $minimise    = 1;  # change frequent words to letters/abbreviations {South->S, Force->F ... }
my $sendsms		= 1;
my $checkBeaufort=1;
my $minBeaufort = 5;
my $aliasDest   = "";

#### End   Simple/Default Configuration

# Is help required ?
use Getopt::Std;
my %options   = ();
my $optChange = 0;
getopts( "hr:H:m:s:d:c:f:a:", \%options );
if ( defined $options{h} ) {
	doUsage();
	exit 0;
}

# Read the rc config file for options - always from the users home directory
my $conffile = "$ENV{HOME}/.smsWindrc";
my $noRCFile = 0;

open( SMSWCONF, $conffile ) or $noRCFile = 1;

if (! $noRCFile) {

	while (<SMSWCONF>) {
		chomp();
	    next if (/^#/);

		if (/^directory\s*([\w\.\-\_]*)/i) {
        	$wDirName = $1;
      	}
		elsif (/^removeTmp\s*([01])/) {
        	$remTempFls = $1;
      	}
		elsif (/^keepHistory\s*([01])/) {
        	$keepHistory = $1;
      	}

		elsif (/^minimise\s*([01])/) {
        	$minimise = $1;
      	}
		elsif (/^sendsms\s*([01])/) {
        	$sendsms = $1;
      	}
      	elsif (/^checkBeaufort\s*([01])/) {
        	$checkBeaufort = $1;
      	}
      	elsif (/^minBeaufort\s*([0-9])/) {
        	$minBeaufort = $1;
      	}
      	elsif (/^destination\s*([\w\.\-\_]*)/) {
        	$destination = $1;
      	}
	}
	print "Options taken from $conffile\n";
    close SMSCONF;
} else {
	print "No rc file exists. It will be generated to store your options\n";
}



# Read the Command Line Options

if ( defined $options{r} ) {
	print "Cleanup setting $options{c}; ";
	$remTempFls   = $options{r};
	$optChange = 1;
}
if ( defined $options{H} ) {
	print "History setting $options{H}; ";
	$keepHistory = $options{H};
	$optChange   = 1;
}
if ( defined $options{m} ) {
	print "Minimal Words setting $options{m}; ";
	$minimise  = $options{m};
	$optChange = 1;
}
if ( defined $options{s} ) {
	print "SMS Send option $options{s}; ";
	$sendsms = $options{s};
	$optChange = 1;
}
if ( defined $options{d} ) {
	print "Directory to use $options{d}\n";
	$wDirName  = $options{d};
	$optChange = 1;
}
if ( defined $options{c} ) {
	print "Beaufort Force Check setting $options{c}; ";
	$checkBeaufort = $options{c};
	$optChange   = 1;
}
if ( defined $options{f} ) {
	print "Minimum Beaufort Condition $options{f}\n";
	$minBeaufort = $options{f};
	$optChange = 1;
}
if ( defined $options{a} ) {
	print "New destination alias $options{a}\n";
	$destination = $options{a};
	$optChange = 1;
}

print "Saving New Options\n" if $optChange;

my $writeRCFile = 0;

if ($optChange or $noRCFile) {

	open( SMSWCONF, '>'.$conffile ) and $writeRCFile = 1;
	
	if ($writeRCFile) {

		print SMSWCONF "#### Configuration file for the $0 application\n";
		print SMSWCONF "#### to get wind info for the Irish Sea & SMS it to your mobile.\n\n";

		print SMSWCONF "# weather directory\n";
		print SMSWCONF "directory $wDirName \n\n";

		print SMSWCONF "# File cleanup option\n";
		print SMSWCONF "removeTmp $remTempFls \n\n";

		print SMSWCONF "# keepHistory option\n";
		print SMSWCONF "keepHistory $keepHistory \n\n";

		print SMSWCONF "# Word minimise option - 'South'->'S', etc\n";
		print SMSWCONF "minimise $minimise \n\n";

		print SMSWCONF "# Send SMS message (requires working \"<o2|voda|meteor>sms.pl\" from www.mackers.com)\n";
		print SMSWCONF "send $sendsms \n\n";

		print SMSWCONF "# check force condition before sending\n";
		print SMSWCONF "checkBeaufort $checkBeaufort \n\n";
		
		print SMSWCONF "# Minimum Beauforts required before sending\n";
		print SMSWCONF "minBeaufort $minBeaufort \n\n";

		print SMSWCONF "# SMS Destination alias\n";
		print SMSWCONF "destination $destination \n\n";

		close SMSCONF;
	}
}

# exit;   # exit point for checking the arguement processing

require LWP::UserAgent;
my $ua;
my $dateStr;
my $safOk   = 0;
my @dayName = (
	" Sunday",
	" Monday",
	" Tuesday",
	" Wednesday",
	" Thursday",
	" Friday",
	" Saturday"
);

my $weatherDir;
if ( defined( $ENV{HOME} ) ) {
	$weatherDir = "$ENV{HOME}/$wDirName/";
} else {
	$weatherDir = "./$wDirName/";
}

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday);
( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday ) = gmtime(time);
$dateStr = sprintf "%02d:%02d, %s, %02d/%02d/%04d", $hour, $min,
  $dayName[ ($wday) ], $mday, $mon + 1, $year + 1900;

$ua = new LWP::UserAgent;
$ua->timeout(15);    # no more than 15 seconds wait

#$ua->proxy('http', 'http://10.7.1.11:80/');
$ua->agent('WeatherBot/CFM3');
$ua->from('colm@lakecommunications.com');

#check for the existance of the weather dir .....

if ( !-e $weatherDir ) {
	print "No Weather Directory, Making one...\n\n";
	mkdir($weatherDir);
}

my ($rqst1, $res);

# get the raw data from http://www.met.ie/forecasts/seaarea.asp or http://www.rte.ie/pda/weather/marine.html
$rqst1 =
  new HTTP::Request( 'GET', 'http://www.meteireann.ie/forecasts/seaarea.asp' );
$res = $ua->request( $rqst1, $weatherDir . 'weather.htm' );
if ( $res->is_success ) {
	print "Received Shipping Forecast @ $dateStr\n";
	$safOk = 1;
} else {
	print "\nUnable to retrieve Sea Area source\n";
	return;
}

open( SEA, '>' . $weatherDir . 'seaArea.txt' )
  or die "can't open seaArea.txt file.";

my $p;
$p = HTML::Parser->new(
	default_h => [ sub { print SEA shift; }, 'dtext' ],
	comment_h => [""]
);

$p->parse_file( $weatherDir . 'weather.htm' );

close SEA;
unlink( $weatherDir . 'weather.htm' ) if $remTempFls;

# extract wind data - line starts with "Wind:" following a line ending with "Irish Sea"

open( SEA, $weatherDir . 'seaArea.txt' ) or die "can't open seaArea.txt file.";

my $line;

while ( $line = <SEA> ) {
	if ( $line =~ /Forecast until/ ) {
		$line    = <SEA>;
		$dateStr = $line;
		last;
	} else {
		next;
	}
}

while ( $line = <SEA> ) {
	if ( $line =~ /Irish Sea\W{0,4}$/ ) {
		$line = <SEA>;
	} else {
		next;
	}

	#            $line =~ s/ hours//ig;
	last;
}
close SEA;
unlink( $weatherDir . 'seaArea.txt' ) if $remTempFls;

print "$dateStr";
print "   Irish Sea $line\n";

# keep a history
if ($keepHistory) {
	open( HIST, '>>' . $weatherDir . 'IrishSea.txt' )
	  or die "can't open IrishSea.txt file.";
	print HIST $dateStr;
	print HIST "    $line\n";
	close HIST;
}

if ($minimise) {
	$line =~ s/^[ \t]*//;               # remove any leading space
	$line =~ s/north/N/gi;
	$line =~ s/south/S/gi;
	$line =~ s/east/E/ig;
	$line =~ s/west/W/ig;
	$line =~ s/force */F/ig;
	$line =~ s/variable */var./ig;
	$line =~ s/hours *//ig;
	$line =~ s/tomorrow/tmrrw/ig;
	$line =~ s/occasionally/occ\./ig;

	#	$line =~ s/^ *//;
	$dateStr =~ s/Issued at //ig;
	$dateStr =~ s/ Monday,| Tuesday,| Wednesday,| Thursday,| Friday,| Saturday,| Sunday,//ig;
}

#create the message
open( SMS, '>' . $weatherDir . 'smsToday.txt' )
  or die "can't open smsToday.txt file.";
chomp $dateStr;
print SMS "$dateStr### $line.\n";
close SMS;

# apply the send criteria (time of day windows, wind strength windows)
if ($checkBeaufort) {
	if  (! ($line =~ /[$minBeaufort-9]/ )) {
		print "Wind Strength not in range of SMS alert.\n";
		exit 0;
	}	
}

# send the message ?
if ($sendsms && ($destination ne "")) {
	
	if ( system ( 'cat ' . $weatherDir . 'smsToday.txt | /home/colm/vodasms.pl '.$destination ) != 0 ) { 
		die "system call to vodasms.pl failed: $?";
	}
}

sub doUsage
{
	 print <<END;

This program is intended to get the sea area forcast from the web, and 
display the wind speeds for the Irish Sea.

Some options are available to control the program:
    getopts( "hr:H:m:s:d:c:f:", \%options );
    -H{0|1}     Keep an (Irish Sea weather) history file in the directory 
    -d<name>    Set the directory for the the temporary files (and history)
                relative to your home dir
    -r{0|1}     remove the temporary files from the directory when done

    -s{0|1}     Send an SMS to the alias(s)
    -a<alias>   Identify the number/alias/list that you are sending the 
                information to (see o2sms.pl for explanation)
	
    -m{0|1}     Reduce the words for SMS message

    -c{0|1}     Check the minimum beaufort wind strength criterion before sending
    -f[0-9]     Set the minimum beaufort criterion required for a transmission (To Be Coded)

This is designed to be run periodically. see "crontab" command.
END
}
