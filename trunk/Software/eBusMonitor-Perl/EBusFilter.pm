package EBusFilter;

use strict;
use POE::Filter;
use EBus;

use vars qw($VERSION @ISA);
$VERSION = '1.000';
@ISA     = qw(POE::Filter);

my $crc = new EBus();

my $buffer = "";

sub new {
  my $type = shift;
  my $self = bless {}, $type;
  return $self;
}

sub clone {
  my $self = shift;
}

sub get_one_start {
  my ( $self, $stream ) = @_;
  my $raw = @$stream[0];

  if ( length($raw) > 1 ) {    # more than one byte received
    for ( my $i = 0 ; $i < length($raw) ; $i++ ) {
      my @tmp;
      $tmp[0] = substr( $raw, $i, 1 );
      get_one_start( $self, \@tmp );
    }
    last;
  }

  my $byte = asciiConv( @$stream[0] );
  if ( $byte == 0xAA ) {
    if ( length($buffer) > 1 ) {    #stop, cause buffer is not empty
      $self->{transfer} = $buffer;
      $buffer = "";
    }
    else {
      $buffer = "";
    }
  }
  else {
    if ( $byte == 0xA9 ) {
      $self->{a9} = 1;
    }
    elsif ( $byte == 0x01 && $self->{a9} ) {
      $self->{a9} = 0;
      $raw = chr(0xAA);
      $buffer .= $raw;
    }
    elsif ( $byte != 0x01 && $self->{a9} ) {
      $self->{a9} = 0;
      $raw = chr(0xA9) . $raw;
    }
    else {
      $buffer .= $raw;
    }
  }
}

sub get_one {
  my $self = shift;
  my $len  = length( $self->{transfer} );
  if ( $len > 7 ) {    # Minium: QQ ZZ PB SB NN DA0 CRC
    my $dgram = {
      QQ => asciiConv( substr( $self->{transfer}, 0, 1 ) ),
      ZZ => asciiConv( substr( $self->{transfer}, 1, 1 ) ),
      PB => asciiConv( substr( $self->{transfer}, 2, 1 ) ),
      SB => asciiConv( substr( $self->{transfer}, 3, 1 ) ),
      NN => asciiConv( substr( $self->{transfer}, 4, 1 ) ),
    };
    my @dataTmp;
    for ( my $i = 0 ; $i < $dgram->{NN} ; $i++ ) {
      push @dataTmp, asciiConv(
        substr( $self->{transfer}, $i + 5, 1 )
          or {
          $self->{transfer} = "";
            return [$dgram];
          }
      );
    }
    $dgram->{DA} = \@dataTmp;

    #debug
    #for ( my $i = 0 ; $i < $len ; $i++ ) {
    #    print decToHex( asciiConv( substr( $self->{transfer}, $i, 1 ) ) )
    #      . " ";
    #}
    #print "\n";

    $dgram->{CHK} =
      asciiConv( substr( $self->{transfer}, 5 + $dgram->{NN}, 1 ) );
    my $check =
      $crc->calcCrcExpanded( substr( $self->{transfer}, 0, 5 + $dgram->{NN} ) );
    if ( $check != $dgram->{CHK} ) {
      $dgram->{CHKSUMFALSE} = 1;
    }
    if ( $len <= ( 5 + $dgram->{NN} ) ) {
      $self->{transfer} = "";
      return [$dgram];
    }
    $dgram->{ACK} =
      asciiConv( substr( $self->{transfer}, 6 + $dgram->{NN}, 1 ) );
    if ( $len <= ( 6 + $dgram->{NN} ) ) {
      $self->{transfer} = "";
      return [$dgram];
    } 
    $dgram->{SNN} =
      asciiConv( substr( $self->{transfer}, 7 + $dgram->{NN}, 1 ) );
      
    if ( $dgram->{SNN} ) {
      my @dataTmp1;
      for ( my $i = 0 ; $i < $dgram->{SNN} ; $i++ ) {
        push @dataTmp1, asciiConv(
          substr( $self->{transfer}, $i + 8, 1 )
            or {
            $self->{transfer} = "";
              return [$dgram];
            }
        );
      }
      $dgram->{SDA}  = \@dataTmp1;
      $dgram->{SCHK} = asciiConv(
        substr( $self->{transfer}, 8 + $dgram->{SNN} + $dgram->{NN}, 1 ) );
      my $checkS = $crc->calcCrcExpanded(
        substr( $self->{transfer}, 7 + $dgram->{NN}, $dgram->{SNN} + 1 ) );
      if ( $checkS != $dgram->{SCHK} ) {
        $dgram->{SCHKSUMFALSE} = 1;
      }
    }
    $self->{transfer} = "";
    return [$dgram];
  }
  return [];
}

sub put {
  my ( $self, $chunks ) = @_;
  [@$chunks];
}

sub get_pending {
  my $self = shift;
  return [ $self->{dgram} ] if length $self->{dgram};
  return undef;
}

sub asciiConv ($) {
  ( my $str = shift ) =~ s/(.|\n)/(ord $1)/eg;
  return $str;
}

sub decToHex {
  my ($dec) = @_;
  return sprintf( "%x", $dec );
}

1;

