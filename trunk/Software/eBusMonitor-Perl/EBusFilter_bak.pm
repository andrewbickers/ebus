package EBusFilter;

use strict;
use POE::Filter;
use EBusCRC;

use vars qw($VERSION @ISA);
$VERSION = '1.000'; 
@ISA = qw(POE::Filter);

my $crc = new EBusCRC();


sub new {
  my $type = shift;
  my $self = bless {}, $type;
  $self->{counter} = 0;
  $self->{dgram} = {};
  return $self;
}

sub clone {
  my $self = shift;
  my $buffer = '';
  my $clone = bless \$buffer, ref $self;
}

sub get_one_start {
  my ($self, $stream) = @_;
  my $raw  = @$stream[0];
  my $byte = asciiConv(@$stream);
  if ($byte == 0xA9) {
    $self->{a9} = 1;
  }
  if ($byte == 0x01 && $self->{a9}) {
    $self->{a9} = 0;
    $self->{expansion} = 1;
    if ($self->{counter} != 6) { # data
      $self->{counter}--;
    }
  }
  if (length(@$stream[0]) > 1) { # more than one byte received
    for (my $i = 0 ; $i < length(@$stream[0]); $i++) {
      my @tmp;
      $tmp[0] =  substr(@$stream[0], $i, 1);
      get_one_start($self, \@tmp);
    }
  } 
  elsif ($byte == 0xAA) { # Start / Stop
    if ($self->{counter} > 1) { #Stop
      print "\n";
    }
    $self->{raw} = "";
    $self->{counter} = 1;
  }
  # QQ
  elsif ($byte != 0xAA && $self->{counter} == 1 ) {
    $self->{raw} = $raw;
    print "QQ:". decToHex($byte) . " ";
    $self->{counter} = 2;
  }
  # ZZ
  elsif ($byte != 0xAA && $self->{counter} == 2 ) {
    $self->{raw} .= $raw;
    print "ZZ:". decToHex($byte) . " ";
    $self->{counter}  = 3;
  }
  # PB
  elsif ($byte != 0xAA && $self->{counter} == 3 ) {
    $self->{raw} .= $raw;
    print "PB:". decToHex($byte) ." ";
    $self->{counter}  = 4;
  }
  # SB
  elsif ($byte != 0xAA && $self->{counter} == 4 ) {
    $self->{raw} .= $raw;
    print "SB:". decToHex($byte) ." ";
    $self->{counter}  = 5;
  }
  # NN
  elsif ($byte != 0xAA && $self->{counter} == 5 ) {
    $self->{raw} .= $raw;
    print "NN:". $byte." ";
    if ($byte < 17) {
      $self->{following} =  $byte; 
    }
    $self->{counter}  = 6;
  }
  # DA
  elsif ($byte != 0xAA && $self->{counter} == 6 && $self->{following} > 0 ) {
    if ($self->{expansion}) {
     $self->{following}++;
     $self->{expansion} = 0;
    }
    $self->{raw} .= $raw;
    print "DA:" .  decToHex($byte) . " ";
    $self->{following}--;
    if ($self->{following} == 0) {
      $self->{counter} = 7;
    }
  }
  # CRC
  elsif ($byte != 0xAA && $self->{counter} == 7) {
    if ($self->{expansion}) {
      $byte = 0xAA;
      $self->{expansion} = 0;
    }
    print "CRC:" .  decToHex($byte) . " ";
    my $crc = $crc->calcCrc($self->{raw});
    if ($byte == $crc ) {
    
    }
    elsif (!$self->{a9}) { 
      print " CRC Mismatch";
    }
    $self->{counter} = 8;
  }
  # ACK
  elsif ($byte != 0xAA && $self->{counter} == 8) {
    print "ACK:" .  decToHex($byte) . " ";
    $self->{counter} = 9;
  }
  # SNN
  elsif ($byte != 0xAA && $self->{counter} == 9) { # Slave reports back
    $self->{raw} = $byte;
    print "SNN:" .  decToHex($byte) . " ";
    $self->{followingSlave} =  $byte; 
    $self->{counter} = 10;
  }
  # SDA
  elsif ($byte != 0xAA && $self->{counter} == 10 && $self->{followingSlave} > 0) {
    if ($self->{expansion}) {
     $self->{following}++;
     $self->{expansion} = 0;
    }
    $self->{raw} .= $byte;
    print "SDA:" .  decToHex($byte) . " ";
    $self->{followingSlave}--;
    if ($self->{followingSlave} == 0) {
      $self->{counter} = 11;
    }
  }
  # SCRC
  elsif ($byte != 0xAA && $self->{counter} == 11) {
    print "SCRC:" .  decToHex($byte) . " ";
    if ($self->{expansion}) {
      $byte = 0xAA;
      $self->{expansion} = 0;
    }
    print "SCRC:" .  decToHex($byte) . " ";
    my $crc = $crc->calcCrc($self->{raw});
    if ($byte == $crc) {
      
    }
    elsif (!$self->{a9}) {
      print " SCRC mismatch";
    }
    $self->{counter} = 12;
  }
  # SACK
  elsif ($byte != 0xAA && $self->{counter} == 12) {
    print "SACK:" .  decToHex($byte) . " ";
    $self->{counter} = 13;
  }
  else {
    if ($byte != 0xAA) {
      print "Datagram error: $byte : counter :".$self->{counter}."\n";
    }
  }
  $self->{dgram} .= join '', @$stream;
}

sub get_one {
  my $self = shift;
  return [ ] unless length $self->{dgram};
  my $chunk = $self->{dgram};
  $self->{dgram} = '';
  return [ $chunk ];
}

sub put {
  my ($self, $chunks) = @_;
  [ @$chunks ];
}

sub get_pending {
  my $self = shift;
  return [ $self->{dgram} ] if length $self->{dgram};
  return undef;
}

sub asciiConv ($)
{
  (my $str = shift) =~ s/(.|\n)/(ord $1)/eg;
  return $str;
}

sub decToHex {
  my ($dec) = @_;
  return sprintf("%x", $dec);
}

1;

