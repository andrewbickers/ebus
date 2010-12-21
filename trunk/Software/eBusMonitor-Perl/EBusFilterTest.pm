package EBusFilter;

use strict;
use POE::Filter;
use EBusCRC;

use vars qw($VERSION @ISA);
$VERSION = '1.000'; 
@ISA = qw(POE::Filter);

my $crc = new EBusCRC();

my $buffer ="";

sub new {
  my $type = shift;
  my $self = bless {}, $type;
  return $self;
}

sub clone {
  my $self = shift;
  #my $buffer = '';
  #my $clone = bless \$buffer, ref $self;
}

sub get_one_start {
  my ($self, $stream) = @_;
  my $raw  = @$stream[0];
  if (length(@$stream[0]) > 1) { # more than one byte received
    for (my $i = 0 ; $i < length(@$stream[0]); $i++) {
      my @tmp;
      $tmp[0] =  substr(@$stream[0], $i, 1);
      get_one_start($self, \@tmp);
    } 
 }
 my $byte = asciiConv(@$stream);
  if ($byte == 0xAA) {
   if (length($buffer) > 1) { #stop, cause buffer is not empty 
     $self->{transfer} = $buffer;
     $buffer = "";
   }
   else {
     $buffer = "";
   }
  }
  else {
    $buffer .= $raw;
  }
}

sub get_one {
  my $self = shift;
  my $len = length($self->{transfer});
  if ($len > 0) {
  
   for (my $i = 0; $i < $len; $i++) {
    print decToHex(asciiConv(substr($self->{transfer}, $i, 1))). " ";
   }
   print "\n";
   $self->{transfer} = "";
  }
  return [ ];
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

