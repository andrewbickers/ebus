#!/usr/bin/perl
use strict;
use warnings;
use POE;
use EBusFilter;
use POE::Component::Client::TCP;

my %names;
$names{0x3}  = "Feuerungsautomat";
$names{0xfe} = "Broadcast";
$names{0x10} = "Heizungsregler";
$names{0x30} = "Bedienmodul";
$names{0x51} = "Bedienmodul";
$names{0x70} = "Bedienmodul";
$names{0xF1} = "Heizungsregler";

POE::Session->create(
	inline_states => {
		_start    => sub { },
		dataIn    => \&dataIn,
		dataError => \&dataError,
	},
);

POE::Component::Client::TCP->new(
	Alias         => 'tcpClient',
	RemoteAddress => "192.168.165.9",
	RemotePort    => "10001",
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
