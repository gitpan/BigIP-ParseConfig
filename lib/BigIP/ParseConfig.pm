package BigIP::ParseConfig;

# BigIP::ParseConfig, F5/BigIP configuration parser
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

our $VERSION = '1.1.3';
my  $AUTOLOAD;



use warnings;
use strict;



# Initialize the module
sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    $self->{'ConfigFile'} = shift;

    return $self;
}

# Return a list of objects
sub monitors   { return shift->_objectlist( 'monitor' ); }
sub nodes      { return shift->_objectlist( 'node' ); }
sub partitions { return shift->_objectlist( 'partition' ); }
sub pools      { return shift->_objectlist( 'pool' ); }
sub profiles   { return shift->_objectlist( 'profile' ); }
sub routes     { return shift->_objectlist( 'route' ); }
sub rules      { return shift->_objectlist( 'rule' ); }
sub users      { return shift->_objectlist( 'user' ); }
sub virtuals   { return shift->_objectlist( 'virtual' ); }

# Return a list of pool members
sub members {
    my $self = shift;
    my $pool = shift;

    $self->{'Parsed'} ||= $self->_parse();

    return 0 unless $self->{'Parsed'}->{'pool'}->{$pool}->{'members'};

    if ( ref $self->{'Parsed'}->{'pool'}->{$pool}->{'members'} eq 'ARRAY' ) {
        return @{$self->{'Parsed'}->{'pool'}->{$pool}->{'members'}};
    }
    else {
        return $self->{'Parsed'}->{'pool'}->{$pool}->{'members'};
    }
}

# Modify an object
sub modify {
    my $self = shift;

    my ( $arg );
    %{$arg} = @_;

    return 0 unless $arg->{'type'} && $arg->{'key'};

    my $obj = $arg->{'type'};
    my $key = $arg->{'key'};
    delete $arg->{'type'};
    delete $arg->{'key'};

    $self->{'Parsed'} ||= $self->_parse();

    return 0 unless $self->{'Parsed'}->{$obj}->{$key};

    foreach my $attr ( keys %{$arg} ) {
        next unless $self->{'Parsed'}->{$obj}->{$key}->{$attr};
        $self->{'Modify'}->{$obj}->{$key}->{$attr} = $arg->{$attr};
    }

    return 1;
}

# Write out a new configuration file
sub write {
    my $self = shift;
    my $file = shift || $self->{'ConfigFile'};

    die "No changes found; no write necessary" unless $self->{'Modify'};

    foreach my $obj ( qw( self partition route user monitor auth profile node pool rule virtual ) ) {
        foreach my $key ( keys %{$self->{'Parsed'}->{$obj}} ) {
            if ( $self->{'Modify'}->{$obj}->{$key} ) {
                $self->{'Output'} .= "$obj $key {\n";
                foreach my $attr ( keys %{$self->{'Parsed'}->{$obj}->{$key}} ) {
                    $self->{'Modify'}->{$obj}->{$key}->{$attr} ||= $self->{'Parsed'}->{$obj}->{$key}->{$attr};
                    if ( ref $self->{'Modify'}->{$obj}->{$key}->{$attr} eq 'ARRAY' ) {
                        if ( @{$self->{'Modify'}->{$obj}->{$key}->{$attr}} > 1 ) {
                            $self->{'Output'} .= "   $attr\n";
                            foreach my $val ( @{$self->{'Modify'}->{$obj}->{$key}->{$attr}} ) {
                                $self->{'Output'} .= "      $val\n";
                            }
                        }
                        else {
                            $self->{'Output'} .= "   $attr " . $self->{'Modify'}->{$obj}->{$key}->{$attr}[0] . "\n";
                        }
                    }
                    else {
                        $self->{'Output'} .= "   $attr " . $self->{'Modify'}->{$obj}->{$key}->{$attr} . "\n";
                    }
                }
                $self->{'Output'} .= "}\n";
            }
            else {
                $self->{'Output'} .= $self->{'Raw'}->{$obj}->{$key};
            }
        }
    }

    open FILE, ">$file" || return 0;
    print FILE $self->{'Output'};
    close FILE;

    return 1;
}



# Return a list of objects
sub _objectlist {
    my $self = shift;
    my $obj  = shift;

    $self->{'Parsed'} ||= $self->_parse();

    if ( $self->{'Parsed'}->{$obj} ) {
        return keys %{$self->{'Parsed'}->{$obj}};
    }
    else {
        return 0;
    }
}

# Parse the configuration file
sub _parse {
    my $self = shift;
    my $file = shift || $self->{'ConfigFile'};

    die "File not found: $self->{'ConfigFile'}\n" unless -e $self->{'ConfigFile'};

    open FILE, $file || return 0;
    my @file = <FILE>;
    close FILE;

    my ( $data, $parsed );

    until ( !$file[0] ) {
        my $ln = shift @file;

        my ( $P );

        if ( $ln =~ /^(auth|monitor|node|partition|pool|profile|route|rule|self|user|virtual)\s+(.*)\s+{$/ ) {
            $data->{'obj'} = $1;
            $data->{'key'} = $2;
          # $P = \${$self->{'Parsed'}}->{$1}->{$2};
        }

        if ( $data->{'obj'} && $data->{'key'} ) {
            $self->{'Raw'}->{$data->{'obj'}}->{$data->{'key'}} .= $ln;

            if ( $ln =~ /^\s{3}(\w+)\s+(.+?)$/ ) {
              # $$P->{$1} = $2;
                $parsed->{$data->{'obj'}}->{$data->{'key'}}->{$1} = $2;
            }

            if ( $ln =~ /^\s{3}(\w+)$/ ) { $data->{'list'} = $1; }

            if ( $ln =~ /^\s{6}((\w+|\d+).+?)$/ && $data->{'list'} ) {
                no strict 'refs';
                push @{$parsed->{$data->{'obj'}}->{$data->{'key'}}->{$data->{'list'}}}, $1;
                use strict 'refs';
            }
        }
    }

    return $parsed;
}



1;

