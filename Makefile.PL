use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'SNMP::APCUPS',
    AUTHOR              => 'Rev. Jeffrey Paul <sneak@datavibe.net>',
    VERSION_FROM        => 'lib/SNMP/APCUPS.pm',
    ABSTRACT_FROM       => 'lib/SNMP/APCUPS.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'	=> 0,
	'DateTime'	=> 0,
	'SNMP'		=> 0,
	'Net::Ping'	=> 0,
	'Socket'	=> 0,

	},
    EXE_FILES		=> [ 'qapcups' ],
		   
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SNMP-APCUPS-*' },
);
