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

our $VERSION = '1.1.1';
my  $AUTOLOAD;



use warnings;
use strict;



sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    $self->{'ConfigFile'} = shift;

    $self->{'Parsed'} = {};

    return $self;
}

sub parse {
    my $self = shift;
    my $file = shift || $self->{'ConfigFile'};

    open FILE, $file;

    {
        local $/ = '}';

        while ( <FILE> ) {
            # Split the file into blocks
            my @block = split /\n/, $_;

            # Each block is an object (pool, node, etc) and has a key
            my ( $obj, $key );

            # Line counter
            my $c = 0;

            # Parse through a block line-by-line
            foreach my $ln ( @block ) {
                # Remove leading and trailing whitespace
                $ln =~ s/^\s+//g;
                $ln =~ s/\s+$//g;

                # Identify an object and key
                if ( $ln =~ /^(\w+)\s+(.+?)\s+{/ && $c == 1) {
                    $obj = $1;
                    $key = $2;
                }

                # Parsing instructions for different object types
                elsif ( $key && $obj ) {
                    for ( $obj ) {
                        (
                            /^auth$/ ||
                            /^monitor$/ ||
                            /^node$/ ||
                            /^partition$/ ||
                            /^route$/ ||
                            /^self$/ ||
                            /^user$/
                        ) && do {
                            if ( $ln =~ /^(\w+)\s+(.*)$/ ) {
                                $self->{'Parsed'}->{$obj}->{$key}->{$1} = $2;
                            }
                        };

                        /^rule$/ && do {
                            $self->{'Parsed'}->{$obj}->{$key} .= "$ln\n";
                        };

                        /^pool$/ && do {
                            if (
                                $ln =~ /^(nat)\s+(.*)$/ ||
                                $ln =~ /^(monitor)\s+(.*)$/ ||
                                $ln =~ /^(session)\s+(.*)$/ ||
                                $ln =~ /^(lb method)\s+(.*)$/
                            ) {
                                $self->{'Parsed'}->{$obj}->{$key}->{$1} = $2;
                            }
                            elsif ( $ln ne 'members' ) {
                                next if $ln eq '}';
                                $ln = $1 if $ln =~ /members\s+(.*)$/;
                                push @{$self->{'Parsed'}->{$obj}->{$key}->{'members'}}, $ln;
                            }
                        };

                        /^profile$/ && do {
                            if (
                                $ln =~ /^(.*)\s+(\w+)$/
                            ) {
                                $self->{'Parsed'}->{$obj}->{$key}->{$1} = $2;
                            }
                        };

                        /^virtual$/ && do {
                            if (
                                $ln =~ /^(ip)\s+(.*)$/ ||
                                $ln =~ /^(pool)\s+(.*)$/ ||
                                $ln =~ /^(snat)\s+(.*)$/ ||
                                $ln =~ /^(rules)\s+(.*)$/ ||
                                $ln =~ /^(persist)\s+(.*)$/ ||
                                $ln =~ /^(translate)\s+(.*)$/ ||
                                $ln =~ /^(destination)\s+(.*)$/
                            ) {
                                $self->{'Parsed'}->{$obj}->{$key}->{$1} = $2;
                            }
                            elsif ( $ln ne 'profiles' ) {
                                next if $ln eq '}';
                                push @{$self->{'Parsed'}->{$obj}->{$key}->{'profiles'}}, $ln;
                            }
                        };
                    }
                }

                $c++;
            }
        }
    }

    close FILE;
}

sub write {
    my $self = shift;
    my $file = shift || $self->{'ConfigFile'};

    foreach my $obj ( qw(
        self partition route user monitor auth profile node pool
    ) ) {
        foreach my $key ( keys %{$self->{'Parsed'}->{$obj}} ) {
            print "$obj $key {\n";

            my $w =  \%{$self->{'Parsed'}->{$obj}->{$key}};
            
            if ( ref $w eq 'HASH' ) {
                foreach my $key ( keys %{$w} ) {
                    if ( ref $w->{$key} eq 'ARRAY' ) {
                        if ( @{$w->{$key}} > 1 ) {
                            print "   $key\n";
                            foreach my $item ( @{$w->{$key}} ) {
                                print "      $item\n";
                            }
                        }
                        else {
                            print "   $key " . $w->{$key}[0] . "\n";
                        }
                    }
                    else {
                        print "   $key " . $w->{$key} . "\n";
                    }
                }
            }

            print "}\n";
        }
    }

    #--
}



1;

