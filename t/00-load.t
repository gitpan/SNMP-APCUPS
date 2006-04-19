#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'SNMP::APCUPS' );
}

diag( "Testing SNMP::APCUPS $SNMP::APCUPS::VERSION, Perl $], $^X" );
