#!/usr/bin/perl

#$Id: vcard2o2smsrc.pl 211 2006-04-13 13:20:55Z mackers $

use strict;
use Text::vCard::Addressbook;

my $vcardfile = shift;

my $address_book = Text::vCard::Addressbook->new(
		{
		'source_file' => $vcardfile,
		});

foreach my $vcard ($address_book->vcards())
{
	my $alias = '';

	if (my $nick = $vcard->nickname())
	{
		$alias = $nick;
	}
	else
	{
		my $names = $vcard->get({'node_type'=>'name'});

		foreach my $name (@{$names})
		{
			$alias = substr($name->given(),0,1) . $name->family();
		}
	}

	if ($alias == '')
	{
		$alias = $vcard->fullname();
	}

	$alias =~ s/\W//g;
	$alias = lc($alias);

	my @nodes = $vcard->get({
			'node_type' => 'tel',
			'types' => 'cell',
			});

	if (my $cell = $nodes[0])
	{
		print "alias " . $alias . " " . $cell->value() . "\n";
	}

}
