#!/usr/bin/perl -w

# mail to o2sms gateway
# $Id: o2smsmail.pl 103 2006-01-24 19:14:54Z mackers $
#

use lib '/home/mackers/lib/perl5/site_perl/';
use Mail::Box::Manager;
require '/home/mackers/bin/o2sms';
use strict;

my $reply_from = "MAILER-DAEMON\@fake-o2.ie";

my $fromline = <STDIN>;
my $teh_message = Mail::Message->read(\*STDIN);
my $from = $teh_message->sender->format;
my @tos = $teh_message->to;
my $to = $tos[0]->address;

my $reply;
my $std_prelude = "On " . localtime() . ", $from texted:\n";

# check for a valid subject
my ($username, $password, $masked, $std_subject);
if ($teh_message->subject =~ /^(\S+)(\s+)(\S+)$/) {
        $username = $1;
        $password = $3;
	$masked = 'x' x length($password);
	$std_subject = "Re: $username $masked";
} else {
        $reply = $teh_message->reply
                ( prelude       => "Invalid subject--use 'username password'.\n\n$std_prelude"
                , From          => $reply_from
                );
}

# check for a valid number
my $number;
if ($to =~ /00\d{7,20}/) {
	$number = $&;
} else {
	$reply = $teh_message->reply
                ( prelude       => "Invalid number.\n\n$std_prelude"
		, Subject	=> $std_subject
                , From          => $reply_from
                );
}

# get the first plain text part of multipart messages
my $message = "";
if ($teh_message->body->isMultipart) {
        foreach my $part ($teh_message->parts) {
                if ($part->mimeType eq 'text/plain') {
                        $message = $part->decoded;
                        last;
                } 
        } 
} else {
        $message = $teh_message->decoded;
}
if ($message->string eq "") {
        $reply = $teh_message->reply
                ( prelude       => "No plaintext message found in body of mail.\n\n$std_prelude"
		, Subject	=> $std_subject
                , From          => $reply_from
                );
}
$message = substr($message->string, 0, 160);

# plop the message off to o2sms
exit;
my $cj = &o2_login ($username, $password) unless ($reply);

if ($cj) {
	my $retval = &o2_send_sms($cj,$message,$number);
      # -- check return values
	my ($prelude, $failed);
	my $postlude = "\n";
      if (defined($retval) && ($retval == -1)) {
        # unknown repsonse.
        $prelude = "Message sending failed; unknown response from server.";
        $failed = 1;
      } elsif ($retval == -2) {
        # message sent, but we don't know how many are left
        $prelude = "Message sent to $number. You have ? remaining this month.";
      } elsif ($retval == 0) {
        # 0 messages left - probably failed sending
        $prelude = "Message sending failed; possibly a malformed message.";
        $failed = 1;
      } elsif ($retval > 0) {
        # message send successful
        $prelude = "Message sent to $number. You have $retval remaining this month.";
      } else {
        # unknown negative response
        $prelude = "Message sending failed.";
        $failed = 1;
      }
	$reply = $teh_message->reply
                ( prelude       => "$prelude\n\n$std_prelude"
                , postlude      => "$postlude\n\n"
		, Subject	=> $std_subject
                , From          => $reply_from
                );
} elsif (!$reply) {
	$reply = $teh_message->reply
                ( prelude       => "Login failed; your username or password is incorrect or some other error occured.\n\n$std_prelude"
                , From          => $reply_from
		, Subject	=> $std_subject
                );
}

# send the confirmation reply
$reply->send;

