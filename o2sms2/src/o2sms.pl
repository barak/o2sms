#!/usr/bin/perl

# $Id: o2sms.pl 112 2006-01-26 22:07:33Z mackers $
# 
# o2sms is a grand script to send SMS's (or text messages) via the UNIX command
# line. Despite its name, it supports Vodafone (Ireland) and Meteor as well as
# o2 (Ireland)  users.
#
# The script emulates a browser to send messages via your operator's website.
# By bypassing the usual kludgey, slow web interfaces, you can zip away
# messages to your mates as fast as you can type them.
#
# At the time of writing, o2 give 250 free web texts per month, Vodafone 300
# and Meteor 300. After sending a message, o2sms will tell you how many you have
# remaining.
#
# http://www.mackers.com/projects/o2sms/
#
# This program is free software; you can redistribute it and/or modify it under 
# the same terms as Perl itself.
# 
# The author accepts no responsibility nor liability for your use of this software.
# Please read the terms and conditions of the website of your mobile provider 
# before using the program.
#

# -- perl modules
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use URI::Escape;
use POSIX qw(strftime);
use File::stat;

# -- constants
use constant OUTPUT_AUTOFLUSH_BUFFERED  => 0;
use constant OUTPUT_AUTOFLUSH_UNBUFFERED => 1;

# -- global vars
my $svnid = '$Id: o2sms.pl 112 2006-01-26 22:07:33Z mackers $';
my $version = '2.0.' . (split(/ /,$svnid))[2];
my $showhelp = 0;
my $debug = 0;
my $dontsend = 0;
my $loginbutdontsend = 0;
my $dontfill = 1;
my $dontsplit = 0;
my $dontreuse = 0;
my $hardsplit = 0;
my $emut9 = 0;
my $squeeze = 0;
my $dol_login_url = 'https://apps.o2.ie/NASApp/Portal/Login';
my $dol_smsform_url = 'http://webtext.o2.ie/NASApp/TM/O2/proc/sendMessage.jsp';
my $dol_login_referrer = 'http://www1.o2.ie/home';
my $dol_smsform_referrer = 'https://apps.o2.ie/NASApp/redirects/grouptext/webtext.jsp';
#my $voda_login_url = 'https://www.vodafone.ie/servlet/ie.vodafone.servlets.LoginServlet';
my $voda_login_url = 'https://www.vodafone.ie/myv/services/login/Login.shtml';
my $voda_login_referrer = 'http://www.vodafone.ie/';
my $voda_smsform_referrer = 'http://www.vodafone.ie/myvodafone/textandwap/webtext/index.jsp';
my $voda_smsform_url = 'http://www.vodafone.ie/myvodafone/textandwap/webtext/index.jsp';
my $voda_charpersecond = 4;
my $voda_mindelay = 10;
my $voda_maxdelay = 35;
my $meteor_base_url = 'https://www.mymeteor.ie/mymeteor/';
my $meteor_login_url = 'https://www.mymeteor.ie/mymeteor/do_login.cfm';
my $meteor_login_referer = 'https://www.mymeteor.ie/mymeteor/main/home.cfm';
my $meteor_textLeftReferer = 'https://www.mymeteor.ie/mymeteor/main/home.cfm';
my $meteor_smsform_page = 'https://www.mymeteor.ie/mymeteor/phone_book/send_sms.cfm';
my $meteor_redirect_prefix = 'https://www.mymeteor.ie/mymeteor/phone_book/';

my $single_max_length = 160;
my $sms_max_length = 500;
my $expiresecs = 1800;
my $man_delim = "\\\\\\\\";
my $username = ""; 
my $password = "";
my $sig = "";
my @recips;
my @numbers;
my @message_parts;
my $message;
my $prelength;
my %aliases;
my $ua = LWP::UserAgent->new;
my %useragentstrs = ("Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0)" => "26",
 		     "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" => "68",
		     "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.0.1) Gecko/20020823 Netscape/7.0" => "72",
		     "Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.1)" => "80",
		     "Mozilla/4.0 (compatible; MSIE 6.0; Windows 98)" => "85",
		     "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)" => "93",
		     "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:0.9.4.1) Gecko/20020314 Netscape6/6.2.2" => "95",
		     "Opera/6.05 (Windows 2000; U)  [en]" => "96",
		     "Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 4.0)" => "97",
		     "Opera/7.0 (Windows 2000; U)" => "98",
		     "Mozilla/5.0 (X11; U; SunOS sun4u; en-US; rv:1.1) Gecko/20020827" => "99",
		     "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041107 Firefox/1.0" => "100",
		     "Mozilla/4.0 (compatible; MSIE 5.21; Mac_PowerPC)" => "110",
		     "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/125.5.5 (KHTML, like Gecko) Safari/125.11" => "120",
		     "Mozilla/5.0 (X11; U; NetBSD i386; rv:1.7.3) Gecko/20041104 Firefox/0.10.1" => "121",
		     "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; Q321120)" => "125"
	     );
my $is_o2 = 0;
my $is_voda = 0;
my $is_meteor = 0;
my $cookiefile;
my $msgfile;
my $conffile;
my $otherconffile;
my $proxy;
my $carrier = "";
my $doreadmessage = 1;
my $embedded_mode = 0; #set if the script is running inside another program, e.g. Mac OS X's Address Book
my $homedir;

if (defined($ENV{HTTPS_PROXY})) {
	$proxy = $ENV{HTTPS_PROXY};
} else {
	$proxy = $ENV{HTTP_PROXY};
}

# -- get command name
if ($0 =~ /voda(fone)?sms(\.pl)?$/i) {
	$carrier = 'Vodafone Ireland';
} elsif ($0 =~ /met(eor)?sms(\.pl)?$/i) {
	$carrier = 'Meteor Ireland';
} elsif ($0 =~ /o2sms(\.pl)?$/i) {
	$carrier = 'O2 Ireland';
} else {
	# assuming included from other script
	return 1;
}

# -- get username
unless ($^O eq 'MSWin32') {
	$username = ( getpwuid $< ) [0];
}

# -- read user conf file
#read_config_file($conffile);

# -- parse command line
while ($_ = shift) {
  if (($_ eq "-message") || ($_ eq "-m")) {
    $message = shift;
    $doreadmessage = 0;
  } elsif ($_ eq "-carrier") {
    $carrier = shift;
  } elsif ($_ eq "-embedded") {
    $embedded_mode = 1;
    $| = OUTPUT_AUTOFLUSH_UNBUFFERED; #this is for piped output.
  } elsif ($_ eq "-u") {
    $username = shift;
    $dontreuse = 1;
  } elsif ($_ eq "-p") {
    $password = shift;
  } elsif ($_ eq "-d") {
    $debug = 1;
  } elsif ($_ eq "-f") {
    $dontfill = 1;
  } elsif ($_ eq "-s") {
    $dontsplit = 1;
  } elsif ($_ eq "-k") {
    $hardsplit = 1;
  } elsif ($_ eq "-z") {
    $squeeze = 1;
  } elsif ($_ eq "-r") {
    $dontreuse = 1;
  } elsif ($_ eq "-C") {
    print STDERR "'-C' is a deprecated option, use '-t9' instead.\n";
    $emut9 = 1;
  } elsif ($_ eq "-t9") {
    $emut9 = 1;
  } elsif ($_ eq "-c") {
    $otherconffile = shift;
    $dontreuse = 1;
  } elsif ($_ eq "-P") {
    $proxy = shift;
  } elsif ($_ eq "-v") {
    print "$0 version $version\n";
    exit(0);
  } elsif ($_ eq "--dont-send") {
    $dontsend = 1;
  } elsif (/^\-\-?\w+/) {
    $showhelp = 1;
  } else {
    push (@recips, $_);
  }
}

if (defined($ENV{HOME}))
{
  $homedir = $ENV{HOME};
}
else
{
  $homedir = ".";
}

# -- Set filenames for this carrier
if ($carrier eq "Vodafone Ireland") {
        $is_voda = 1;
        $cookiefile = $homedir . "/.vodasmscookie";
        $msgfile = $homedir . "/.vodasmsmsg";
        $conffile = $homedir . "/.vodasmsrc";
	$expiresecs = 15 * 60; # vodafone cookies expire quicker
} elsif ($carrier eq "O2 Ireland") {
        $is_o2 = 1;
        $cookiefile = $homedir . "/.o2smscookie";
        $msgfile = $homedir . "/.o2smsmsg";
        $conffile = $homedir . "/.o2smsrc";
} elsif ($carrier eq "Meteor Ireland") {
        $is_meteor = 1;
        $cookiefile = $homedir . "/.meteorsmscookie";
        $msgfile = $homedir . "/.meteorsmsmsg";
        $conffile = $homedir . "/.meteorsmsrc";
} else {
	print STDERR "Unknown or unsupported carrier: $carrier\n";
	exit(1);
}

# -- display help message
if ((scalar(@recips) == 0) || ($showhelp == 1)) {
  print STDERR <<EOF;
Usage: $0 [options] <number|alias|group> [<number|alias|group> ...]

  $0 is a script to send SMSs via the command line. It works by sending
  requests to your phone operator's website (ie. simulating a browser). The
  script requires that you have a valid web account, which is available to o2,
  Vodaphone and Meteor phone owners. At the time of writing, o2 give 250 free
  web texts per month, Vodaphone 300 and Meteor 300.

  Options:
  -u <username>  use this username (defaults to unix username or config file
                 username) (implies -r)
  -p <password>  use this password (defaults to config file password or
                 prompts for password)
  -c <conffile>  use this config file (defaults to $conffile) (implies -r)
  -s             don't split message over multiple SMSs
  -r             don't reuse cookies when logging in
  -k             split message in middle of words
  -t9            emulate t9 behaviour (currently just capitalises first letters)
  -P <proxy>	 use this http(s) proxy
  -v             print version
  -z             squeeze text (mak txt msg as smal as psble)
  -h             prints this help message
  -d             debug mode - prints the entire http dialog
  
  Config File Format:
  username <username>
  password <password>
  alias <name> <number> [number|alias ...]
  sig <text-to-place-at-end-of-every-sms>
  proxy <http(s)://host:port/>
  nosplit
  hardsplit
  nofill
  squeeze
  noreuse
  emulate-t9

EOF
  exit (0);
}

# -- read config file again
if (defined($otherconffile)) {
  unless (read_config_file($otherconffile)) {
    print STDERR "Couldn't open $conffile.\n";
    exit(1);
  }
  $conffile = $otherconffile;
} else {
  read_config_file($conffile);
}

# -- explode groups
my @recips2;
foreach my $recip (@recips) {
  if(ref($aliases{$recip}) eq 'ARRAY'){
    # is group
    push (@recips2, @{$aliases{$recip}});
  } else {
    push (@recips2, $recip);
  }
}
@recips = @recips2;

# -- check for aliases
for (my $i=0; $i<scalar(@recips); $i++) {
  my $recip = $recips[$i];
  if ($recip =~ /[^\d\+]/) {
    # has non-numeric character - might be alias
    if (exists($aliases{$recip})) {
      $numbers[$i] = $aliases{$recip};
    } else {
      print STDERR "Not a valid alias: $recip.\n";
      exit (1);
    }
  } else {
    $numbers[$i] = $recip;
  } 
}

foreach my $number (@numbers) {
  # -- check number
  if ($number =~ /^0(8[3567])(\d*)/) {
    # is an irish mobile number - check length
    if (length($number) != 10) {
      print STDERR "Number is the wrong length for an Irish mobile number.\n";
      exit (1);
    }
    # length ok - make international
    $number = "00353$1$2";
  } elsif ($number =~ /^\+(\d*)/) {
    $number = "00$1";
    # is an international number
  } elsif ($number =~ /^00(\d*)/) {
    # is an international number
  } else {
    # ?
    print STDERR "Not a valid number: $number. Please use 08[3567]xxxxxxx or international number.\n";
    exit(1);
  }
  if (($is_voda) && ($number !~ /^00353/)) {
    print STDERR "Vodafone webtexts can only be sent to Irish mobile numbers.\n";
    exit(1);
  }
}

# -- print welcome message
print "[ recipient(s) : ";
for (my $i=0; $i<scalar(@recips); $i++) {
  my $recip = $recips[$i];
  if ($recip =~ /[^\d\+]/) {
    # is alias, print both
    print "$recip (" . $numbers[$i] . ") ";
  } else {
    # just number
    print $numbers[$i] . " ";
  }
}
print "]\n";

# -- set the adjusted max length (with sig)
$single_max_length = $single_max_length - length($sig);

# -- get the text
if ($doreadmessage) {
  while (<STDIN>) {
    last if (/^\.$/);
    $message .= $_;
  }
}

# empty message means exit.
if (!defined($message) || length($message) == 0) {
  print "[ byebye ]\n";
  exit(0);  
}

# -- prepare the message
chomp($message); # kill last new line
#$message =~ s/\n/ /gsm; # make other newlines spaces

# if required use Lingua::EN::Squeeze to squeeze text
if ($squeeze) {

  eval 'use Lingua::EN::Squeeze';
  if ($@) {
    warn "Cannot squeeze message: " . $@;
  } else {
    $prelength = length($message);
    $message = SqueezeText($message);
    print "Squeezed Message (" . int(length($message)/$prelength*100) . "% compression):\n$message\n" if ($debug);
  }

} elsif ($emut9) { 
  # capitalise first letter of every sentence   $message =~ s/(^\w)/uc($1)/gsme;
  # (emut9 is mutually exclusive with squeeze)
  $message =~ s/(^\w)/uc($1)/gsme;
  $message =~ s/([\.\?\!:\\]\s*)(\w)/$1 . uc($2)/gsme;
}
#$message =~ s/^$man_delim//; # remove unneeded splitters
#$message =~ s/$man_delim$//; # remove unneeded splitters

# -- split up the message
if (length($message) > $sms_max_length) {
  print "[ warning : very long message, truncating to $sms_max_length chars ]\n";
  $message = substr($message,0,$sms_max_length);
  print $message;
}
if ((length($message) > $single_max_length) || ($message =~ /$man_delim/)) {
  if ($dontsplit && ($message !~ /$man_delim/)) {
    print "Message is too long (" . length($message) . "/$single_max_length), exitting.\n";
    exit(1);
  }
  my $restmsg = $message;
  my $partmsg;
  while ((length($restmsg) > $single_max_length) || ($restmsg =~ /$man_delim/)) {
    # if manual split, and message part can fit, then add the first bit and loop
    if ($restmsg =~ /^(.*?)$man_delim(.*)/) {
      if (length($1) < $single_max_length) {
        $partmsg = $1;
        $restmsg = $2;
	push (@message_parts, $partmsg) if ($partmsg =~ /\S/);
	next;
      }
    }
    # if we don't want to split..
    if ($dontsplit) {
      print "Message part " . (scalar(@message_parts) + 1) . " is too long (" . length($restmsg) . "/$single_max_length), exitting.\n";
      exit(1);
    }
    # message too long, split at the most natural place
    if ($hardsplit) {
      ($partmsg, $restmsg) = &split_message_hard($single_max_length, $restmsg);
    } else {
      ($partmsg, $restmsg) = &split_message($single_max_length, $restmsg);
    }
    push (@message_parts, $partmsg) if ($partmsg =~ /\S/);
  }
  push (@message_parts, $restmsg . $sig) if ($restmsg =~ /\S/);
  print "[ warning : long or split message, splitting into " . scalar(@message_parts) . " parts ]\n";
} else {
  push (@message_parts, $message . $sig);
}
if (scalar(@message_parts) == 0) {
  print "Nothing to do, exitting.\n";
  exit (2);
}

# -- fill the end of each message part with white spaces to clear the "free web text" ad
if (!$dontfill) {
  foreach my $message_part (@message_parts) {
    my $msg_fill = " " x ($single_max_length - length($message_part) + length($sig));
    $message_part .= $msg_fill;
  }
}

# -- set the useragent to some random browser (to avoid suspicion!)
$ua->agent(&get_weighted_rand_elem_from_hash(%useragentstrs));
print "sms: using user agent: " . $ua->agent . "\n" if ($debug);

# -- set the proxy
if (($proxy) && ($proxy ne "")) {
  # for https proxies, use ENV variable to "force LWP to use
  # Crypt::SSLeay's proxy support"
  if ($proxy =~ m/^https/i) {
    undef $ENV{"HTTP_PROXY"};
    $ENV{"HTTPS_PROXY"} = $proxy;
  } else {
    $ua->proxy('http',$proxy);
    $ua->proxy('https',$proxy);
  }
  print "sms: using proxy: $proxy\n" if ($debug);
}

# -- get a cookie jar from file or login
my $cj;
# check for existing cookie jar and use if hasn't expired
my $fstat = stat($cookiefile);
if (($fstat) && ($debug)) {
  print "sms: found cookiejar in $cookiefile with mtime of " . strftime("%a %b %e %H:%M:%S %Y", gmtime($fstat->mtime)) . "\n";
}
#if (($dontreuse == 0) && (@fstat) && ($fstat[9] + $expiresecs > time())) {
if (($dontreuse == 0) && ($fstat) && ($fstat->mtime + $expiresecs > time())) {
  # reuse the last cookie

  # -- print status
  print "[ reusing last login for $username\@" . &get_sp_domain . " ... ]\n";

  # -- load the cookie file
  $cj = HTTP::Cookies->new(ignore_discard => 1);
  $cj->load($cookiefile);

  # -- touch the cookie jar to keep it up to date
  utime (time, time, $cookiefile);
} else {
  # cookie jar non existant or expired, login instead

  # -- print status
  print "[ logging in to $username\@" . &get_sp_domain . " ... ]\n";

  # -- get the password
  if ($password eq "") {
    system "stty -echo"; # Echo off
    print "Password: "; # Prompt for password
    chomp($password = <STDIN>); # Remove newline
    system "stty echo"; # Echo on
    print "\n";
  }
 
  # -- login
  if ($dontsend > 0) {
    $cj = &test_login ($username, $password);
  } elsif ($is_o2) {
    $cj = &o2_login ($username, $password);
  } elsif ($is_voda) {
    $cj = &voda_login ($username, $password);
  } elsif ($is_meteor) {
    $cj = &meteor_login ($username, $password);
  }
  if (!defined($cj)) {
    print STDERR "[ login failed; your username or password is incorrect ]\n";
    exit(1);
  } else {
    print "[ login successful ]\n";
  }
}

if ($debug) {
  print "sms: current state of cookie jar:\n";
  print $cj->as_string();
}

# -- send off the message
foreach my $number (@numbers) {
  #foreach my $message (@message_parts) {
  for (my $i=0; $i<scalar(@message_parts); $i++) {

    my $retry;

    do {
	    
      my $message = $message_parts[$i];
      my $failed = 0;
      $retry = 0;

      my $retval;
      if (($dontsend > 0) || ($loginbutdontsend > 0)) {
        $retval = &test_send_sms($cj,$message,$number);
      } elsif ($is_o2) {
        $retval  = &o2_send_sms($cj,$message,$number);
      } elsif ($is_voda) {
        $retval  = &voda_send_sms($cj,$message,$number);
      } elsif ($is_meteor) {
        $retval  = &meteor_send_sms($cj,$message,$number);
      }

      # get a nice message
      my $partmsg = "";
      if (scalar(@message_parts) > 1) {
        $partmsg = " (part " . ($i+1) . " of " . scalar(@message_parts) . ")";
      }

      # -- check return values
      if (defined($retval) && ($retval == -1)) {
        # unknown repsonse.
        print STDERR "[ message sending failed; unknown response from server ]\n";
	$failed = 1;
      } elsif ($retval == -2) {
	# message sent, but we don't know how many are left
        print "[ message$partmsg sent to $number, ? remaining this month ]\n";
      } elsif ($retval == 0) {
        # 0 messages left - probably failed sending
        print STDERR "[ message sending failed; malformed message or no messages remaining this month ]\n";
        $failed = 1;
      } elsif ($retval > 0) {
        # message send successful
        print "[ message$partmsg sent to $number, $retval remaining this month ]\n";
      } else {
        # unknown negative response
        print STDERR "[ message sending failed ]\n";
	$failed = 1;
      }

      if (($embedded_mode==0) && (-t STDOUT)) {
        if ($failed == 1) {
          # ask for a retry
	  print "Retry ? y/n [n]: ";
	  my $resp = <STDIN>;
	  if (defined($resp) && ($resp =~ /^y/i)) {
	    $retry = 1;
	  } else {
	    print "[ okay, I'm outta here. ]\n";
	    unlink ($cookiefile) unless ($debug);
	    exit(1);
          }
        }
      }
    } while ($retry == 1);
  }
}

# -- write message to message file
open (SMSMSG, "> $msgfile") || die ("Can't write to message file!");
print SMSMSG "$message\n";
close (SMSMSG);

# -- save alias
for (my $i=0; $i<scalar(@recips); $i++) {
  my $recip = $recips[$i];
  if ($recip !~ /[^\d]/) {
    my $numexists = 0;
    while ( my ($akey, $avalue) = each(%aliases) ) {
      if ($recips[$i] eq $avalue) {
        $numexists = 1;
        last;
      }
    }

    if ($numexists == 0 && (-t STDOUT)) {
      #print "\n";
      print "[ create alias for '$recip' with this name : ] ";
      my $name4num = <STDIN>;
      chomp($name4num);

      if ($name4num eq '') {
      } elsif ($name4num !~ /[\w\.\-\_]+/) {
        print STDERR "Invalid alias name '$name4num'.\n";
        exit(2);
      } elsif (exists($aliases{$name4num})) {
        print STDERR "Alias already exists.\n";
        exit(2);
      } elsif (open(ALIASFILE, ">>$conffile")) {
        print ALIASFILE "\nalias $name4num $recip";
        close ALIASFILE;
      } else {
        print STDERR "Can't write to configuration file '$conffile'\n";
        exit(2);
      }
    }
  }
}

# -- quit with success
exit(0);

sub o2_login {
  my ($username, $password) = @_;
  print "Logging in... \n" if ($debug);

  my $res = $ua->post($dol_login_url,
  	[ referrer => $dol_login_referrer,
  	  username => $username,
  	  password => $password
  	]);
  
  my $lresp = $res->as_string();
  print $lresp if ($debug);

  # check for a broken server
  if ($res->code == 500) {
    print STDERR "[ login failed; server returned error 500 (Internal Server Error) ]\n";
    exit(1);
  }
  
  # check for invalid username
  if ($lresp =~ /error_login\.jsp/) {
    return undef;
  } else {
    my $cookie_jar = HTTP::Cookies->new(ignore_discard => 1);
    $cookie_jar->extract_cookies($res);

    #  go collect some more tasty cookies
    print "sms: picking up cookies from $dol_smsform_referrer\n" if ($debug);
    my $req = HTTP::Request->new();
    $req->uri($dol_smsform_referrer);
    $req->method("GET");
    $req->protocol("HTTP/1.0");
    $cookie_jar->add_cookie_header($req);
    print $req->as_string() if ($debug);
    my $resp = $ua->send_request($req);
    $cookie_jar->extract_cookies($resp);
    print $resp->as_string() if ($debug);
    
    # check we have a redirect
    if (!($resp->header("Refresh")) || (length($resp->header("Refresh")) == 0)) {
      print STDERR "[ login failed; unknown response from server ]\n";
      exit(1);
    }

    # follow the redirect to get cookies from webtext.o2.ie
    $req->uri(substr($resp->header("Refresh"),6));
    print $req->as_string() if ($debug);
    $resp = $ua->send_request($req);
    $cookie_jar->extract_cookies($resp);
    print $resp->as_string() if ($debug);

    # save the cookies so we can reuse them
    if (defined($cookie_jar) && ($dontreuse == 0)) {
	  $cookie_jar->save($cookiefile);
    }
     return $cookie_jar;
  }
}

sub o2_send_sms {
  my ($cookie_jar, $message, $number) = @_;

  # remove whitespace at beginning of message
  $message =~ s/^\s*//;
  
  # encode the message for sending
  $message = uri_escape($message);

  # get what to send to server
  my $msgsize = length($message);
  my $postmsg = "msisdn=$number&Msg=$message&recipients=1&grpSTR=&ConSTR=&command=send&NumMessages=1";

  # construct the request for sending the message
  my $req = HTTP::Request->new();
  $req->push_header("Referer" => $dol_smsform_url);
  $req->push_header("Referrer" => $dol_smsform_url);
  $req->push_header("Host" => "webtext.o2.ie");
  $req->push_header("Cookie2" => "\$Version=\"1\"");
  $req->push_header("Content-Type" => "application/x-www-form-urlencoded");
  $req->push_header("Content-Length" => length($postmsg));
  $req->uri($dol_smsform_url);
  $req->method("POST");
  $req->protocol("HTTP/1.0");
  
  $cookie_jar->add_cookie_header($req);
  $req->content($postmsg);
  print $req->as_string() if ($debug);
    
  my $resp = $ua->request($req);

  # print if debug
  print $resp->as_string() if ($debug);

  # if we don't get redirected to "sent.jsp" then there's some problem
  if ($resp->header("Location") !~ /sent\.jsp/i) {
    return -1;
  }
  $cookie_jar->extract_cookies($resp);

  # make redirect absolute
  my $redirh = $resp->header("Location");
  $redirh =~ s#\.\.\/#http://webtext.o2.ie/NASApp/TM/O2/#;

  # success - follow the redirect
  $req->method("GET");
  $req->remove_header("Content-Type");
  $req->remove_header("Content-Length");
  $req->content("");
  $req->uri($redirh);
  $cookie_jar->add_cookie_header($req);
  print $req->as_string() if ($debug);
  $resp = $ua->request($req);
  print $resp->as_string() if ($debug);

  # get the html
  my $resp_html = $resp->as_string();

  if (($resp_html =~ /<td class="StoryTitle ">Sent <\/td>/i) &&
    ($resp_html =~ /You now have (\d*) Free Messages remaining this month/i)) {
      return $1;
  } else {
    # the message was sent, but we don't know how many messages are left
    return -2;
  }
    
}

sub voda_login {
  my ($username, $password) = @_;
  print "Logging in... \n" if ($debug);
  
  my $res = $ua->post($voda_login_url,
  	[ referrer => $voda_login_referrer,
  	  username => $username,
  	  password => $password
  	]);
  
  my $lresp = $res->as_string();
  print $lresp if ($debug);

  # check for a broken server
  if ($res->code == 500) {
    print STDERR "[ login failed; server returned error 500 (Internal Server Error) ]\n";
    exit(1);
  }
  
  # check for invalid username
  if (($res->is_redirect) && ($res->header("Location") =~ m#myvodafone/services/logon_failed.jsp#i)) {
    return undef;
  } elsif ($lresp =~ m/logon services are currently unavailable/ism) {
    return undef;
  } else {
    my $cookie_jar = HTTP::Cookies->new(ignore_discard => 1);
    $cookie_jar->extract_cookies($res);

    # save the cookies so we can reuse them
    if (defined($cookie_jar) && ($dontreuse == 0)) {
	  $cookie_jar->save($cookiefile);
    }
     return $cookie_jar;
  }
}

sub voda_send_sms {
  my ($cookie_jar, $message, $number) = @_;

  # remove whitespace at beginning of message
  $message =~ s/^\s*//;
  
  # encode the message for sending
  $message = uri_escape($message);

  # make number national
  $number =~ s/^00353/0/;

  # go get the page id for the form
  my $voda_formname = "";
  my $voda_randid = 0;
  my $voda_formid = 0;
  my $voda_numbx  = 0;
  my $voda_hidd1  = 0;
  my $voda_hidd2  = 0;
  my $voda_pageid = 0;

  my $req0 = HTTP::Request->new();
  $req0->uri($voda_smsform_url);
  $req0->method("GET");
  $req0->protocol("HTTP/1.0");
  $cookie_jar->add_cookie_header($req0);
  my $resp0 = $ua->request($req0);
  print $resp0->as_string() if ($debug);

  if ($resp0->as_string() =~ /<form(\s*)name="(\w*)/i) {
      $voda_formid = $2;
  }

  if ($resp0->as_string() =~ /<form name="$voda_formid".*?pageid=(\d*)/i) {
          $voda_pageid = $1;
  }

  #if ($resp0->as_string() =~ /document.$voda_formid.(\w*)/i) {
  if ($resp0->as_string() =~ /textarea.*?name="([\w\d]+)"/sm) {
          $voda_randid = $1;
  }

  if ($resp0->as_string() =~ /input type="text" name=.(\w*). tab/i) {
            $voda_numbx = $1;
  }

  if ($resp0->as_string() =~ /<\/table>(\s*)<input(\s*)name=.(\w*). (\s*)value=.(\w*)/is) {
           $voda_hidd1 = $3;
           $voda_hidd2 = $5;
  }

  print "Text: $voda_randid\r\n" if ($debug);
  print "Form: $voda_formid\r\n" if ($debug);
  print "Number field: $voda_numbx\r\n" if ($debug);
  print "Hidden 1: $voda_hidd1, Hidden 2: $voda_hidd2\r\n" if ($debug);

  # get what to send to server
  my $msgsize = length($message);
  my $charleft = $single_max_length - length($message);

  my $vodapadding = "&c0004060c0f010e002=&c0004060c0f010e003=&c0004060c0f010e004=&c0004060c0f010e005=&x=17&y=8";
  my $postmsg = "$voda_randid=$message&num=$charleft&$voda_numbx=$number&$vodapadding&FutureDate=false&FutureTime=false&$voda_hidd1=$voda_hidd2";

  # construct the request for sending the message
  my $req = HTTP::Request->new();
  $req->push_header("Referer" => $voda_smsform_referrer . "?pageid=$voda_pageid");
  $req->push_header("Host" => "www.vodafone.ie");
  $req->push_header("Cookie2" => "\$Version=\"1\"");
  $req->push_header("Content-Type" => "application/x-www-form-urlencoded");
  $req->push_header("Content-Length" => length($postmsg));
  $req->uri($voda_smsform_url . "?pageid=$voda_pageid");
  $req->method("POST");
  $req->protocol("HTTP/1.0");
 
  $cookie_jar->add_cookie_header($req);
  $req->content($postmsg);
  print $req->as_string() if ($debug);

  # it seems that the server won't accept messages unless there's a delay...
  # calculate suitable delay
  my $delay = POSIX::ceil ( $msgsize / $voda_charpersecond );
  $delay = $voda_maxdelay if ($delay > $voda_maxdelay);
  $delay = $voda_mindelay if ($delay < $voda_mindelay);

  print STDERR "[ sending message after $delay seconds... ]\n";
  sleep $delay;
  #print STDERR "[ Ok, sending message now ]\n";
   
  my $resp = $ua->request($req);

  # get the html
  my $resp_html = $resp->as_string();

  # print if debug
  print $resp_html if ($debug);

  # this text means successful send
  if (!defined($resp->header("Location")) || ($resp->header("Location") !~ /message_sent/i) ) {
    return -1;
  }

  # go get the page again to see how many messages are left this month
  my $req2 = HTTP::Request->new();
  $req2->uri($voda_smsform_url);
  $req2->method("GET");
  $req2->protocol("HTTP/1.0");
  $cookie_jar->add_cookie_header($req2);
  $resp = $ua->request($req2);

  $resp_html = $resp->as_string();

  print $resp_html if ($debug);

  if ($resp_html =~ /<td height="16" width="200"><b>(\d{1,3})<\/b><\/td>/i) {
    return $1;
  } else {
    return -2;
  }
}

sub meteor_login {
    my ($username, $password) = @_;
    print "Logging in... \n" if ($debug);

    my $postmsg = "&msisdn=$username&pin=$password&x=0&y=0";

    my $req = &prepareStandardPostRequest($meteor_login_url, $meteor_login_referer, $postmsg);
    print $req->as_string() if ($debug);
    $req->content($postmsg);
    my $res = $ua->request($req);

    my $lresp = $res->as_string();
    print $lresp if ($debug);

    # check for a broken server
    if ($res->code == 500) {
        print STDERR "[ login failed; server returned error 500 (Internal Server Error) ]\n";
        exit(1);
    }

    # check for invalid username
    if (($res->is_redirect) && ($res->header("Location") =~ m#logout#ism)){
        return undef;
    } else {
        my $cookie_jar = HTTP::Cookies->new(ignore_discard => 1);
        $cookie_jar->extract_cookies($res);

        # save the cookies so we can reuse them
        if (defined($cookie_jar) && ($dontreuse == 0)) {
            $cookie_jar->save($cookiefile);
        }

        # now ask for the second page
        $meteor_textLeftReferer = $meteor_base_url . $res->header("Location");
        
        $res = $ua->get($meteor_textLeftReferer,
                        [ referrer => $meteor_login_referer ]);

        # this has to be ok too
        unless ($res->code == 200) {
            return undef;
        } else {
            return $cookie_jar;
        }
    }
}

sub meteor_send_sms {
      my ($cookie_jar, $mesg, $number) = @_;
      my $res;
      my $req;
       
      #get the number of texts left.
      $req = &prepareStandardGetRequest($meteor_smsform_page);
      $cookie_jar->add_cookie_header($req);
      $req->push_header("referer" =>  $meteor_textLeftReferer);
      $res = $ua->send_request($req);
      
      $res ->as_string() =~ /You have <b>(\d+)<\/b> Free Web Texts/gi;
           
      my $numTextsLeft = $1;
      $mesg = uri_escape($mesg);
      
      
      my $numLeft = $single_max_length - length($mesg);
        
      my $numberDenom;
      my $numberPrefix;
      if($number =~ /\d(8[3567])(.*)/)
      {
         $numberPrefix = "0" . $1;
         $numberDenom = $2;
      }
    
      my $content1 = "num_free_sms=$numTextsLeft&send_sms=Y&sms_text=$mesg&num_left=$numLeft&msisdn1=$numberPrefix$numberDenom";
       
      $req = &prepareStandardPostRequest($meteor_smsform_page, $meteor_textLeftReferer, $content1);  
      $cookie_jar->add_cookie_header($req);
      
      $req->push_header("referer" => $meteor_textLeftReferer);
      my $resp = $ua->send_request($req);
      
      return ($numTextsLeft - 1);
      
}

sub test_login {
  my ($username, $password) = @_;
  print "sms: logging in with username $username\n";
  return '';
}

sub test_send_sms {
  my ($cookie_jar, $message, $number) = @_;
  $message =~ s/^\s*//;
  $message = uri_escape($message);
  print "sms: message = $message\n";
  print "sms: number = $number\n";
  return 666;
}

sub split_message {
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

sub split_message_hard {
    my ($len, $message) = @_;

    # the part the message to send
    my $partmessage = substr($message, 0, $len);
    # the remaining part of the message
    my $restofmessage = substr($message, $len);

    return ($partmessage, $restofmessage);
}

sub read_config_file {
  # check config file isn't world readble
  if (-f $_[0]) {
	  my $config_file_info = stat($_[0]);
	  if ($config_file_info->mode & 004) {
  		print "[ warning : " . $_[0] . " is world readable ]\n";
	  }
  } else {
	  print "Not a valid file: " . $_[0] . "\n";
  }
  open (SMSCONF, $_[0]) && do {
    print "sms: reading config file " . $_[0] . "\n" if ($debug);
    while (<SMSCONF>) {
      chomp();
      next if (/^#/);
      if (/^alias\s*([\w\.\-\_]*)\s*(\+?\d*)$/i) {
        $aliases{$1} = $2;
        print "sms: added alias for $1\n" if ($debug);
      } elsif (/^alias\s*([\w\.\-\_]*)\s*([\w\d\s]*)/i) {
	my @group = split(/\s+/,$2);
	@{$aliases{$1}} = @group;
	print "sms: added group for $1 (" . join(", ",@{$aliases{$1}}) . ")\n" if ($debug);
      } elsif (/^username\s*(.*)/i) {
        $username = $1;
      } elsif (/^password\s*(.*)/i) {
        $password = $1;
      } elsif (/^sig\s*(.*)/i) {
        $sig = " $1";
	chomp($sig);
      } elsif (/^proxy\s*(.*)/i) {
        $proxy = $1;
	chomp($proxy);
      } elsif (/^nofill/i) {
	$dontfill = 1;
      } elsif (/^squeeze/i) {
        $squeeze = 1;
      } elsif (/^noreuse/i) {
	$dontreuse = 1;
      } elsif (/^nosplit/i) {
        $dontsplit = 1;
      } elsif (/^hardsplit/i) {
        $hardsplit = 1;
      } elsif (/^capitali[sz]e/i) {
	print STDERR "'$&' is a deprecated option, use 'emulate-t9' instead.\n";
	$emut9 = 1;
      } elsif (/^emulate[-_]?t9/i) {
	$emut9 = 1;
      } elsif (/^debug\s*on/i) {
        $debug = 1;
      }
    }
    close (SMSCONF);
    return 1;
  };
  return 0;
}

sub get_rand_elem_from_array {
	my $elem = int(rand(scalar(@_)));
	return $_[$elem];
}

sub get_weighted_rand_elem_from_hash {
	my %thehash = @_;
	my @uas = sort { $thehash{$b} <=> $thehash{$a} } keys %thehash;
	my $rand = int(rand(125)) + 1;
	foreach my $uastr (@uas) {
		return $uastr if ($rand > $thehash{$uastr});
	}
	return $_[0];
}

sub get_sp_domain {
	return "o2.ie" if ($is_o2);
	return "vodafone.ie" if ($is_voda);
	return "meteor.ie" if ($is_meteor);
}

sub prepareStandardPostRequest
{   

    my ($url, $referer, $content) = @_;
    my $req = HTTP::Request->new();    
    my $userAgent = &get_weighted_rand_elem_from_hash(%useragentstrs);
    $req->uri($url);
    $req->method("POST");
    $req->protocol("HTTP/1.1");
    $req->push_header("Accept" => "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*");
    $req->push_header("Accept-Language" =>"en-ie");
    $req->push_header("Content-Type" => "application/x-www-form-urlencoded");
    $req->push_header("Accept-Encoding" => "gzip, deflate");
    $req->push_header("User-Agent" => $userAgent);
    $req->push_header("Host" => "www.mymeteor.ie");
    $req->push_header("Content-Length" => length($content));
    $req->push_header("Connection" =>  "Keep-Alive");
    $req->push_header("Cache-Control" => "no-cache");
    $req->push_header("Referer" =>  $referer);
    $req->content($content);

    return $req;
}

sub prepareStandardGetRequest                                         
{
    my ($url, $referer) = @_;
    my $userAgent = &get_weighted_rand_elem_from_hash(%useragentstrs);
    my $req = HTTP::Request->new();
    $req->uri($url);
    $req->method("GET");
    $req->protocol("HTTP/1.1");    $req->push_header("Accept" => "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/x-shockwave-flash, */*");    $req->push_header("Accept-Language" =>"en-ie");
    $req->push_header("Accept-Encoding" => "gzip, deflate");
    $req->push_header("User-Agent" => $userAgent);
    $req->push_header("Host" => "www.mymeteor.ie");
    $req->push_header("Connection" =>  "Keep-Alive");
    $req->push_header("Referer" =>  $referer);
    return $req;
}
