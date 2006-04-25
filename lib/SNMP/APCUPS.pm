package SNMP::APCUPS;
use SNMP;
use DateTime;
use Socket;
use Net::Ping;
use warnings qw( all );
use strict;


=head1 NAME

SNMP::APCUPS - Object Oriented Interface to American Power Conversions UPS SNMP Management Cards

=cut 

our $VERSION = '0.02';

=head1 VERSION

Version 0.02

=cut

=head1 REQUIRES

This module requires the following modules:
 - SNMP
 - DateTime
 - Socket
 - Net::Ping

Additionally, the APC PowerNet MIB is required.

 ftp://ftp.apcc.com/apc/public/software	\
   /pnetmib/mib/381/powernet381.mib

=head1 SYNOPSIS

Example: 

	use SNMP::APCUPS;
	
	my $ups = new SNMP::APCUPS( { hostname => '10.0.0.5' } );

	die $ups->errstr if $ups->error;
	
	$ups->query;
	
	die $ups->errstr if $ups->error;
	
	my $status_hashref = $ups->status;

	print "UPS Address:\t" . $ups->hostname . "\n";
	print "UPS Runtime:\t" . $ups->runtime . " seconds\n";
	print "UPS Serial:\t" . $ups->serial . "\n";
	print "UPS Battery:\t" . sprintf("%3.0f",$ups->charge*100) . "%\n";
	print "UPS Load:\t" . sprintf("%3.0f",$ups->load*100) . "%\n";
	print "UPS Model:\t" . $ups->model . "\n";
	print "UPS Name:\t" . $ups->name . "\n";
	print "UPS Birthday:\t" . $ups->birthday . "\n";
	print "UPS Temp:\t" . $ups->temperature . "C\n";

	print "UPS " . ( $ups->needsnewbatt ? "does" : "does not" );
	print " need battery replacement.\n";

	print "UPS is presently running on ";
	print ( $ups->onbattery ? 'battery' : 'input');
	print " power.\n";


=head1 AUTHOR

Rev. Jeffrey Paul, C<< <sneak at datavibe.net> >>

http://sneak.datavibe.net

=head1 BUGS

Please report any bugs or feature requests to
C<bug-snmp-apcups at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SNMP-APCUPS>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SNMP::APCUPS

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SNMP-APCUPS>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SNMP-APCUPS>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SNMP-APCUPS>

=item * Search CPAN

L<http://search.cpan.org/dist/SNMP-APCUPS>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 Rev. Jeffrey Paul, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of the Bantown Public License (BPL).

The complete text of the BPL can be found at:
L<http://www.encyclopediadramatica.com/index.php/BPL>

=cut

sub new {
	my ($class,$args) = @_;
	my $self = {
		hostname 	=> 	(
						defined($args->{'hostname'}) ?
						$args->{'hostname'} :
						undef
					),
		ip		=>	undef,
		class		=>	$class,
		error		=>	0,
		errorstr	=>	'',
		community 	=> 	(
						defined($args->{'community'}) ?
						$args->{'community'} :
						'public'
					),
		lastquery	=>	undef,

	};
	$self = bless($self);
	$self->_check();
	return $self;
}

sub error {
	my $self = shift;
	return 1 if $self->{'error'};
	return 0;
}

sub errstr {
	my $self = shift;
	return undef unless $self->{'error'};
	my $err = "unknown error";
	$err = $self->{'errorstr'}
		if $self->{'errorstr'};
	return $err;
}

sub _check {
	my $self = shift;
	return $self->_rerror("No UPS hostname specified.")
		unless $self->{'hostname'};
	$self->_resolve unless $self->error;
	#$self->_ping unless $self->error;
}

sub _resolve {
	my $self = shift;
	my $tmp = undef;
	$tmp = inet_aton($self->{'hostname'});
	if($tmp) {
		$self->{'ip'} = inet_ntoa($tmp);
	}
	$self->_rerror("Can't resolve: " . $self->{'hostname'})
		unless $self->{'ip'};
}

sub _ping {
	my $self = shift;
	my $p = Net::Ping->new("icmp");
	unless($p->ping($self->{'ip'},1)) {
		$self->_rerror(
			$self->{'hostname'} .
			" (" . $self->{'ip'} .
			") not reachable."
		);
	}
}


sub query {
	my $self = shift;
	$self->_qups();
	return if $self->error();
	$self->{'lastquery'} = DateTime->now();
	$self->_parseresult();
}

sub _rerror {
	my $self = shift;
	my $err = shift;
	$self->{'error'} = 1;
	$self->{'errorstr'} = $err;
	return $self;
}

sub _decodetable {
	# not a method!
	my $table = {
		'upsBasicOutputStatus'		=>	{
			1	=> 'unknown',
			2	=> 'onLine',
			3	=> 'onBattery',
			4	=> 'onSmartBoost',
			5	=> 'timedSleeping',
			6	=> 'softwareBypass',
			7	=> 'off',
			8	=> 'rebooting',
			9	=> 'swtichedBypass',
			10	=> 'hardwareFailureBypass',
			11	=> 'sleepingUntilPowerReturn',
			12	=> 'onSmartTrim',

		},
		'upsAdvInputLineFailCause'	=>	{
			1	=> 'noTransfer',
			2	=> 'highLineVoltage',
			3	=> 'brownout',
			4	=> 'blackout',
			5	=> 'smallMomentarySag',
			6	=> 'deepMomentarySag',
			7	=> 'smallMomentarySpike',
			8	=> 'largeMomentarySpike',
			9	=> 'selfTest',
			10	=> 'rateOfVoltageChange',
		},
		'upsAdvBatteryReplaceIndicator' =>	{
			1 => 'noBatteryNeedsReplacing',
			2 => 'batteryNeedsReplacing',
		},
		'upsBasicBatteryStatus'		=> 	{
			1 => 'unknown',
			2 => 'batteryNormal',
			3 => 'batteryLow',
		},
	};
	return $table;
}

sub _parseresult {
	my $self = shift;
	my $t = _decodetable();
	my @oids = keys(%{$t});
	
	#copy!
	my %h = %{$self->{'rawstatus'}};
	my $stat = \%h;

	foreach (@oids) {
		if(exists($stat->{$_})) {
			# start your xmodem receiver now
			$stat->{$_} = $t->{$_}{$stat->{$_}};
		}
	}

	my @doids = (
		'upsAdvIdentDateOfManufacture',
		'upsBasicBatteryLastReplaceDate',
	);
	foreach (@doids) {
		$stat->{$_} =
			_dconvert_mmddyy_to_dt($self->{'rawstatus'}{$_});
	}
	
	$self->{'status'} = $stat;
}

sub _dconvert_mmddyy_to_dt {
	# not a method!
	my $mmddyy = shift;
	
	my @p = split(/\//,$mmddyy);
	
	$p[2] += 1900 if $p[2] > 50; # yay y2k bugs
	$p[2] += 2000 if $p[2] < 50;
	
	my $dt = DateTime->new(
		year	=> $p[2],
		month	=> $p[0],
		day	=> $p[1],
	);
	return $dt;
}

sub _qups {
	my $self = shift;
	return if $self->error();
	# get from
	# ftp://ftp.apcc.com/apc/public/software \
	# /pnetmib/mib/381/powernet381.mib
	my $miburl = 'ftp://ftp.apcc.com/apc/public/software/'.
		'pnetmib/mib/381/powernet381.mib';
	my $mib = '/usr/share/snmp/mibs/powernet381.mib';
	return $self->_rerror("Can't read MIB: '$mib'. ".
		"Maybe you need to download it from '$miburl'?")
			unless -r $mib;
	
	$ENV{'MIBS'} = $mib;
	my $sess = new SNMP::Session (
			
			DestHost	=> $self->{'ip'},
			Community	=> $self->{'community'},
			Version		=> 1,
			Timeout		=> 500000, 	#usec (.5s)
			Retries		=> 1,		# 1 for tot of 1s
			);
	return $self->_rerror("Unable to SNMP.") unless $sess;
	my @attr = (
		'upsAdvBatteryNominalVoltage',		# VDC
		'upsAdvBatteryActualVoltage',		# VDC
		'upsAdvBatteryCurrent',			# Amperes
		'upsAdvTotalDCCurrent',			# Amperes
		'upsBasicIdentModel',			# model name  
		'upsAdvIdentSerialNumber',		# serial
		'upsAdvBatteryCapacity',		# percentage
		'upsAdvBatteryTemperature',		# degrees C
		'upsBasicInputPhase',			# phase integer
		'upsBasicOutputPhase',			# phase integer
		'upsAdvOutputLoad',			# percentage
		'upsAdvOutputVoltage',			# VAC
		'upsAdvOutputFrequency',		# Hz
		'upsBasicOutputStatus',			# lookup
		'upsAdvBatteryRunTimeRemaining',	# ticks (sec*100)
		'upsAdvInputMaxLineVoltage',		# VAC (last 60s)
		'upsAdvInputMinLineVoltage',		# VAC (last 60s)
		'upsAdvInputLineVoltage',		# VAC
		'upsAdvInputFrequency',			# Hz
 		'upsAdvInputLineFailCause',		# lookup
		'upsBasicIdentName',			# ups name string
		'upsAdvIdentFirmwareRevision',		# version string
		'upsAdvIdentDateOfManufacture',		# MM/DD/YY string	
		'upsAdvBatteryReplaceIndicator',	# lookup
		'upsBasicBatteryLastReplaceDate',	# MM/DD/YY
		'upsBasicBatteryTimeOnBattery', 	# secs * 100
		'upsBasicBatteryStatus',		# lookup
	);

	my @arg;

	foreach (@attr) {
		push(@arg,[ $_ ]);
	}

	my $vl =  new SNMP::VarList(@arg);
	my @info = $sess->getnext($vl);

	return $self->_rerror("Unable to fetch UPS parameters.") unless @info;
	
	my $x = 0;
	my $h = { };
	foreach (@attr) {
		$h->{$attr[$x]} = $info[$x];
		$x++;
	}
	$self->{'rawstatus'} = $h;
}

#convenient accessors:

sub hostname {
	my $self = shift;
	return undef if $self->error;
	return $self->{'hostname'};
}

sub onbattery {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	return undef
		if $self->{'status'}{'upsBasicOutputStatus'} eq 'unknown';
	return 1
		if $self->{'status'}{'upsBasicOutputStatus'} eq 'onBattery';
	return 1
		if $self->{'status'}{'upsBasicOutputStatus'} eq 'onSmartBoost';
	return 0;
}

sub status {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	
	#copy;
	my %h = %{$self->{'status'}};
	
	return \%h;
}

sub needsnewbatt {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	if (
		$self->{'status'}{'upsAdvBatteryReplaceIndicator'}
		eq
		'batteryNeedsReplacing'
	) { 
		return 1;
	} elsif (
		$self->{'status'}{'upsAdvBatteryReplaceIndicator'}
		eq
		'noBatteryNeedsReplacing'
	) {
		return 0;
	} else {
		return undef;
	}
}

sub runtime {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	my $s = $self->{'status'}{'upsAdvBatteryRunTimeRemaining'}/100;
	$s = int($s);
	return $s;
}

sub charge {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	my $p = $self->{'status'}{'upsAdvBatteryCapacity'}/100;
	return $p;
}

sub model {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	return $self->{'status'}{'upsBasicIdentModel'};
}

sub serial {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	return $self->{'status'}{'upsAdvIdentSerialNumber'};
}

sub name {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	return $self->{'status'}{'upsBasicIdentName'};
}

sub load {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	my $l = $self->{'status'}{'upsAdvOutputLoad'}/100;
}

sub birthday {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	my $dt = $self->{'status'}{'upsAdvIdentDateOfManufacture'};
	return $dt->ymd;
}

sub temperature {
	my $self = shift;
	$self->query unless $self->{'lastquery'};
	return undef if $self->error;
	return $self->{'status'}{'upsAdvBatteryTemperature'};
}

1;

__END__
