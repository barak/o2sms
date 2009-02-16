#!/usr/bin/perl
# $Id: o2smsd.pl 299 2006-08-10 23:27:15Z mackers $

=head1 o2smsd

o2smsd - A HTTP daemon providing a human and API interface to o2sms.

=head1 DESCRIPTION

C<o2sms> is a script to send SMS messages via the command line using the websites
of Irish mobile operators. 

This daemon uses C<o2sms> to communicate via HTTP with human or machine clients, 
providing a simple API for sending messages via o2sms, where installation is not 
practical.

THIS PROGRAM IS PROOF-OF-CONCEPT ONLY. Specifically, there is no access control or
threading (only one client at a time). If you want to improve it, do so by all means
and send me the patches.
 
The author accepts no responsibility nor liability for your use of this
software.  Please read the terms and conditions of the website of your mobile
provider before using the program.

=cut

use strict;
use warnings;

use HTTP::Daemon;
use HTTP::Status;
use CGI;
use WWW::SMS::IE::iesms;
use WWW::SMS::IE::o2sms;
use WWW::SMS::IE::vodasms;
use WWW::SMS::IE::meteorsms;

my $port = 51080;
#my $addr = "127.0.0.1";
my $data_dir = "/tmp/";
my $debug = 0;

my $lasterr = "";

my $daemon = HTTP::Daemon->new(
#		LocalAddr => $addr,
		LocalPort => $port,
#		ReusePort => 1,
	) || &log_fatal($@);

&log_info("Listening on " . $daemon->url);

while (my $client = $daemon->accept())
{
	&log_info("Got connection from " . $client->peerhost());
	$client->autoflush(1);

	while (my $request = $client->get_request())
	{
		if ($request->url->path ne "/")
		{
			$client->force_last_request();
			$client->send_error(RC_NOT_FOUND);
			&log_error(RC_NOT_FOUND . ": " . $request->url->path);
			next;
		}

		if ($request->method eq 'GET')
		{
			$client->force_last_request();
			$client->send_basic_header(RC_OK);
			$client->send_crlf();

			print $client &write_form;
		}
		elsif ($request->method eq 'POST')
		{
			# handle post
			my $query = new CGI($request->content());

			my ($username, $password, $carrier, $recipient, $message);

			if (!(	($username = $query->param("u")) &&
				($password = $query->param("p")) &&
				($carrier = $query->param("c")) &&
				($recipient = $query->param("r")) &&
				($message = $query->param("m"))
				))
			{
				$client->force_last_request();
				$client->send_error(RC_BAD_REQUEST);
				&log_error(RC_BAD_REQUEST . ": Missing one or more parameters");
				next;
			}

			&log_info("Got a valid post request, will send message to '$recipient'");

			my $remaining_messages = &send_message($username, $password, $carrier, $recipient, $message);

			if ($remaining_messages == -1)
			{
				$client->force_last_request();
				$client->send_error(RC_INTERNAL_SERVER_ERROR, $lasterr);
				&log_error(RC_INTERNAL_SERVER_ERROR . ": $lasterr");
				next;
			}

			$client->force_last_request();
			$client->send_basic_header(RC_OK);
			$client->send_crlf();

			print $client "<title>ok</title>\n";
			print $client "<h1>ok</h1>\n";
			print $client "<p>$remaining_messages messages remaining</p>\n";
		}
		else
		{
			$client->force_last_request();
			$client->send_error(RC_NOT_IMPLEMENTED);
			&log_error(RC_NOT_IMPLEMENTED . ": " . $request->method);
			next;
		}
	}

	$client->close();

	undef($client);
}

sub send_message
{
	my ($username, $password, $car, $number, $message) = @_;

	my $carrier;

        if ($car eq "meteor")
        {
                $carrier = WWW::SMS::IE::meteorsms->new;
        }
        elsif ($car eq "vodafone")
        {
                $carrier = WWW::SMS::IE::vodasms->new;
        }
        elsif ($car eq "o2")
        {
                $carrier = WWW::SMS::IE::o2sms->new;
        }
        else
        {
                &log_error("Invalid carrier name '$car'");
		return -1;
        }

	$carrier->debug($debug);
	$carrier->config_dir($data_dir);

	if (($number = $carrier->validate_number($number)) == -1)
	{
		&log_error($carrier->validate_number_error());
		return -1;
	}

	if (!$carrier->login($username, $password))
	{
		&log_error("Login failed: " . $carrier->error());
		return -1;
	}

	my $retval = $carrier->send($number, $message);

	if (!$retval)
	{
		&log_error("Message sending failed: " . $carrier->error());
	}

	&log_info("Message sent");

	return $carrier->remaining_messages();
}

sub write_form
{
	return <<"EOF";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
		<title>o2smsd</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	</head>
	<body>
		<h1>o2smsd</h1>

		<form action="/" method="post">
			<h2>Username</h2>
			<p><input type="text" name="u"/></p>
			<h2>Password</h2>
			<p><input type="password" name="p"/></p>
			<h2>Carrier</h2>
			<p><select name="c">
				<option value="o2">o2.ie</option>
				<option value="vodafone">vodafone.ie</option>
				<option value="meteor">meteor.ie</option>
			</select></p>
			<h2>Recipient</h2>
			<p><input type="text" name="r" value="+353" maxlength="20"/></p>
			<h2>Message</h2>
			<p><textarea name="m" cols="40" rows="2"></textarea></p>
			<p><input type="submit" value="Send"/></p>
		</form>
	</body>
</html>
EOF
;
}

sub log_debug
{
	print "" . localtime() . " $0" . "[$$]: Debug - $_[0]\n" if ($debug);
}

sub log_info
{
	print "" . localtime() . " $0" . "[$$]: $_[0]\n";
}

sub log_error
{
	$lasterr = $_[0];
	print STDERR "" . localtime() . " $0" . "[$$]: Error -  $_[0]\n";
}

sub log_fatal
{
	&log_error($_[0]);
	die();
}

=head1 SEE ALSO

L<WWW::SMS::IE::iesms>,
L<http://www.mackers.com/projects/o2sms/>

=head1 AUTHOR

David McNamara (me.at.mackers.dot.com) 

=head1 COPYRIGHT

Copyright 2000-2006 David McNamara

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

