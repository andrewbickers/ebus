#!/usr/bin/perl 
use strict;
use warnings;
use POE;
use Device::SerialPort;
use Symbol qw(gensym);
use EBusFilterTest;
use POE::Wheel::ReadWrite;

POE::Session->create(
 inline_states => {
    _start => \&setup_device,
    dataIn => \&dataIn,
    dataError => \&dataError,
 },
);
POE::Kernel->run();
exit 0;

sub setup_device {
  my ($kernel, $heap) = @_[KERNEL, HEAP];
  my $handle = gensym();
  my $port = tie(*$handle, "Device::SerialPort", "/dev/ttyUSB0");
  die "can't open port: $!" unless $port;
  $port->datatype('raw');
  $port->baudrate(2400);
  $port->databits(8);
  $port->parity("none");
  $port->stopbits(1);
  #$port->handshake("rts");
  $port->write_settings();
  
  $heap->{port} = $port;
  $heap->{port_wheel} = POE::Wheel::ReadWrite->new(
    Handle => $handle,
    Filter => EBusFilter->new(),
    InputEvent => "dataIn",
    ErrorEvent => "dataError",
  );
}

sub dataIn {
  my ( $kernel, $heap, $data ) = @_[ KERNEL, HEAP, ARG0 ];
  print $data."\n";
}

sub dataError {
  print "Fuck up\n";
}