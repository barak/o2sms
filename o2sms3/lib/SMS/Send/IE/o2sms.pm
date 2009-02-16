package SMS::Send::IE::o2sms;

use warnings;
use strict;

=head1 NAME

SMS::Send::IE::o2sms - SMS::Send o2sms Driver

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS
    
  # Create a o2sms sender
  my $send = SMS::Send->new( 'IE::o2sms' 
  	_login    => '0861234567',
	_password => 's3cr3t',
  	);
  
  # Send a message
  $send->send_sms(
  	text => 'ook!',
  	to   => '+353 86 1234567',
  	);

=head1 DESCRIPTION

SMS::Send::IE::o2sms is a driver for L<SMS::Send>.

It is a simple wrapper around L<WWW::SMS::IE::o2sms>.

=cut

use base 'SMS::Send::Driver';
#use Data::Dumper;

require WWW::SMS::IE::iesms;
require WWW::SMS::IE::o2sms;

#####################################################################
# Constructor

sub new
{
	my $class = shift;
	my %args = @_;

	# Create the object

	my $self = bless {
		messages => [],
		login    => $args{_login},
		password => $args{_password},
	}, $class;

	return $self;
}

sub send_sms
{
	my $self = shift;

	my %message = @_;
	my $recipient = $message{to};
	my $text = $message{text};

	my $ok = 0;

	my $carrier = new WWW::SMS::IE::o2sms;

	if ($carrier->login($self->{login}, $self->{password}))
	{
		my $retval = $carrier->send($recipient, $text);

		if ($retval)
		{
			$ok = 1;
		}
		else
		{
			#print $carrier->error() . "\n";
		}
	}

	return $ok;
}

=back

=head1 DISCLAIMER

The author accepts no responsibility nor liability for your use of this
software.  Please read the terms and conditions of the website of your mobile
provider before using the program.

=head1 SEE ALSO

L<WWW::SMS::IE::o2sms>,

L<http://www.mackers.com/projects/o2sms/>

=head1 AUTHOR

David McNamara (me.at.mackers.dot.com)

=head1 COPYRIGHT

Copyright 2000-2006 David McNamara

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
