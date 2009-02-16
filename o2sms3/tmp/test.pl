#!/usr/bin/perl

	use WWW::SMS::IE::iesms;
	use WWW::SMS::IE::o2sms;

	my $c = WWW::SMS::IE::o2sms->new;

$c->debug(2);

while (1)
{
$c->_choose_agent_string();
sleep(1);
print "=====\n";
} 
