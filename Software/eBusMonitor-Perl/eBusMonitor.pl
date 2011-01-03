#!/usr/bin/perl
use strict;
use warnings;
use POE;
use EBusFilter;
use EBus;
use POE::Component::Client::TCP;
use POE::Component::EasyDBI;

my $debug = 0;

my $ebus = EBus->new();

# HAP specific
my $moduleDbId = 269;
my $config     = 132;
my $insertLimit = 60; # DB-Inserts einschraenken. 
my $time = time() - $insertLimit;

# XPort
my $remoteIP = "192.168.165.9";
my $remotePort = "10001";

# Database
POE::Component::EasyDBI->new(
	alias    => "database",
	dsn      => "dbi:mysql:hap",
	username => "hap",
	password => "password",
	options  => { autocommit => 1, },
);

POE::Session->create(
	inline_states => {
		_start         => sub { },
		dataIn         => \&dataIn,
		dataError      => \&dataError,
		dbUpdateStatus => \&dbUpdateStatus,
	},
);

POE::Component::Client::TCP->new(
	Alias         => 'tcpClient',
	RemoteAddress => $remoteIP,
	RemotePort    => $remotePort,
	Connected     => sub {
		print "Connected\n";
	},
	ConnectError => sub {
		print "Connection failed.\n";
	},
	ServerInput  => \&dataIn,
	InlineStates => {
		ServerOutput => sub {
			my ( $kernel, $heap, $data ) = @_[ KERNEL, HEAP, ARG0 ];
			$heap->{server}->put($data);
		  }
	},
	Filter => EBusFilter->new(),
);

POE::Kernel->run();
exit 0;

sub dataIn {
	my ( $kernel, $heap, $data ) = @_[ KERNEL, HEAP, ARG0 ];

	# Sollwertuebertragung des Reglers an andere Regler
	if ($debug && ( $data->{PB} == 8 && $data->{SB} == 0 )) {
		print
"# $data->{QQ} $data->{ZZ} ############## Sollwertuebertragung des Reglers an andere Regler ###################\n";
		print "Kesselsoll:"
		  . $ebus->data2b( $data->{DA}[0], $data->{DA}[1] ) . "\n";
		print "Aussentemp.:"
		  . $ebus->data2b( $data->{DA}[2], $data->{DA}[3] ) . "\n";
		print "Brauchwasserbereitung aktiv\n" if ( $data->{DA}[5] == 0 );
		print "Heizkreis aktiv\n"             if ( $data->{DA}[5] == 1 );
		print "Brauchwassersoll:"
		  . $ebus->data2b( $data->{DA}[6], $data->{DA}[7] ) . "\n";

	}

	# Betriebsdaten des Reglers an den Feuerungsautomaten
	elsif ($debug && ( $data->{PB} == 5 && $data->{SB} == 7 )) {
		print
"# $data->{QQ} $data->{ZZ} ############## Betriebsdaten des Reglers an den Feuerungsautomaten ###################\n";
		print "Brenner abschalten\n"      if ( $data->{DA}[0] == 0x00 );
		print "Brauchwassser bereitung\n" if ( $data->{DA}[0] == 0x55 );
		print "Heizbetrieb\n"             if ( $data->{DA}[0] == 0xAA );
		print "Kesselsollwert"
		  . $ebus->data2c( $data->{DA}[2], $data->{DA}[3] ) . "\n";
		print "Kesselsollwert-Druck"
		  . $ebus->data2b( $data->{DA}[4], $data->{DA}[5] ) . "\n";
		print "Stellgrad:" . $ebus->data1c( $data->{DA}[6] ) . "\n";
		print "Brauchwassersoll:" . $ebus->data1c( $data->{DA}[7] ) . "\n";

	}

	# Betriebsdaten des Feuerungsautomaten an den Regler - Block 1
	elsif ((time() - $time >= $insertLimit) && ($data->{PB} == 5
		&& $data->{SB} == 3
		&& $data->{DA}[0] == 1
		&& $data->{QQ} == 3
		&& $data->{ZZ} == 254 ))
	{
                $time = time();
                print time()."\n";
		# Kessel
		$kernel->post(
			'database',
			insert => {
				sql =>
'INSERT INTO status (TS, Type, Module, Address, Status, Config) VALUES (?,?,?,?,?,?)',
				placeholders => [
					time(), 40, $moduleDbId, 200,
					$ebus->data1c( $data->{DA}[4] ), $config
				],
				event => '',
			}
		);

		# Ruecklauf
		$kernel->post(
			'database',
			insert => {
				sql =>
'INSERT INTO status (TS, Type, Module, Address, Status, Config) VALUES (?,?,?,?,?,?)',
				placeholders =>
				  [ time(), 40, $moduleDbId, 201, $data->{DA}[5], $config ],
				event => '',
			}
		);

		# Boiler
		$kernel->post(
			'database',
			insert => {
				sql =>
'INSERT INTO status (TS, Type, Module, Address, Status, Config) VALUES (?,?,?,?,?,?)',
				placeholders =>
				  [ time(), 40, $moduleDbId, 202, $data->{DA}[6], $config ],
				event => '',
			}
		);

		# Aussen
		$kernel->post(
			'database',
			insert => {
				sql =>
'INSERT INTO status (TS, Type, Module, Address, Status, Config) VALUES (?,?,?,?,?,?)',
				placeholders =>
				  [ time(), 40, $moduleDbId, 203, $data->{DA}[7], $config ],
				event => '',
			}
		);

		# Stellgrad
		$kernel->post(
			'database',
			insert => {
				sql =>
'INSERT INTO status (TS, Type, Module, Address, Status, Config) VALUES (?,?,?,?,?,?)',
				placeholders =>
				  [ time(), 40, $moduleDbId, 204, $data->{DA}[3], $config ],
				event => '',
			}
		);
        # Flamme an/aus
	$kernel->post(
		'database',
		insert => {
			sql =>
'INSERT INTO status (TS, Type, Module, Address, Status, Config) VALUES (?,?,?,?,?,?)',
			placeholders =>
			  [ time(), 40, $moduleDbId, 205, ($data->{DA}[2] & 8)*12.5, $config ],
			event => '',
		}
	);
	}
	elsif ($debug) {
		print "QQ:" . $data->{QQ};
		print " ZZ:" . $data->{ZZ};
		print " PB:" . $data->{PB};
		print " SB:" . $data->{SB};
		print " NN:" . $data->{NN};
		for ( my $i = 0 ; $i < $data->{NN} ; $i++ ) {
			print " DA$i:" . $data->{DA}[$i];
		}
		print " CHK:" . $data->{CHK};
		print " ACK:" . $data->{ACK};
		if ( $data->{SNN} ) {
			print " SNN:" . $data->{SNN};
			for ( my $i = 0 ; $i < $data->{SNN} ; $i++ ) {
				print " SDA$i:" . $data->{SDA}[$i];
			}
			print " SCHK:" . $data->{SCHK};
		}
		print " (!)"  if ( $data->{CHKSUMFALSE} );
		print " (!!)" if ( $data->{SCHKSUMFALSE} );
		print "\n";
	}
}
