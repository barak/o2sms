#
# $Id$

package WWW::SMS::IE::emobilesms;

=head1 NAME

WWW::SMS::IE::emobilesms - A module to send SMS messages using the website of 
emobile Ireland

=head1 SYNOPSIS

  require WWW::SMS::IE::iesms;
  require WWW::SMS::IE::emobilesms;

  my $carrier = new WWW::SMS::IE::emobilesms;

  if ($carrier->login('0871234567', 'password'))
  {
    my $retval = $carrier->send('+353865551234', 'Hello World!');

    if (!$retval)
    {
      print $carrier->error() . "\n";
    }
  }

=head1 DESCRIPTION

L<WWW::SMS::IE::emobilesms> is a class to send SMS messages via the command line
using the website of emobile Ireland -- http://www.emobile.ie/

For more information see L<WWW::SMS::IE::iesms>

=cut

use strict;
use warnings;
use vars qw( $VERSION );
$VERSION = sprintf("0.%02d", q$Revision: 352 $ =~ /(\d+)/);

@WWW::SMS::IE::emobilesms::ISA = qw{WWW::SMS::IE::iesms};

use constant LOGIN_START_STEP => 0;
use constant LOGIN_END_STEP => 6;
use constant SEND_START_STEP => 7;
use constant SEND_END_STEP => undef;
use constant REMAINING_MESSAGES_MATCH => 1;
use constant ACTION_FILE => "emobilesms.action";
use constant SIMULATED_DELAY_MIN => 0;
use constant SIMULATED_DELAY_MAX => 0;
use constant SIMULATED_DELAY_PERCHAR => 0.25;

sub _init
{
	my $self = shift;

	$self->_log_debug("creating new instance of emobilesms carrier");

	$self->_login_start_step(LOGIN_START_STEP);
	$self->_login_end_step(LOGIN_END_STEP);
	$self->_send_start_step(SEND_START_STEP);
	$self->_send_end_step(SEND_END_STEP);
	$self->_remaining_messages_match(REMAINING_MESSAGES_MATCH);
	$self->_action_file(ACTION_FILE);
	$self->_simulated_delay_max(SIMULATED_DELAY_MAX);
	$self->_simulated_delay_min(SIMULATED_DELAY_MIN);
	$self->_simulated_delay_perchar(SIMULATED_DELAY_PERCHAR);

	$self->full_name("emobile Ireland");
	$self->domain_name("emobile.ie");

	if ($self->is_win32())
	{
		$self->config_dir($ENV{TMP});
		$self->config_file($self->_get_home_dir() . "emobilesms.ini");
		$self->message_file("emobilesms_lastmsg.txt");
		$self->history_file("emobilesms_history.txt");
		$self->cookie_file("emobilesms.cookie");
		$self->action_state_file("emobilesms.state");
	}
	else
	{
		$self->config_dir($self->_get_home_dir() . "/.emobilesms/");
		$self->config_file("config");
		$self->message_file("lastmsg");
		$self->history_file("history");
		$self->cookie_file(".cookie");
		$self->action_state_file(".state");
	}
}

sub is_emobile
{
	return 1;
}

sub _format_number
{
	my ($self, $number) = @_;

	$number =~ s/^\+353/0/;

	return $number;
}

sub max_length
{
  return 480;
}


=head1 DISCLAIMER

The author accepts no responsibility nor liability for your use of this
software.  Please read the terms and conditions of the website of your mobile
provider before using the program.

=head1 SEE ALSO

L<WWW::SMS::IE::iesms>,
L<WWW::SMS::IE::emobilesms>,
L<WWW::SMS::IE::emobilesms> 

L<http://www.mackers.com/projects/o2sms/>

=head1 AUTHOR

David McNamara (me.at.mackers.dot.com)

=head1 COPYRIGHT

Copyright 2000-2006 David McNamara

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;