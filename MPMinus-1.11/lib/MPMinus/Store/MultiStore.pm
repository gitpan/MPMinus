package MPMinus::Store::MultiStore; # $Id: MultiStore.pm 122 2013-05-07 13:05:41Z minus $
use strict;

=head1 NAME

MPMinus::Store::MultiStore - Multistoring

=head1 VERSION

Version 1.02

=head1 SYNOPSIS

    use MPMinus::Store::MultiStore;

    # Multistoring
    my $mso = new MPMinus::Store::MultiStore (
            -m   => $m, # OPTIONAL
            -mso => {
                
                foo => {
                    -dsn    => 'DBI:mysql:database=TEST;host=192.168.1.1',
                    -user   => 'login',
                    -pass   => 'password',
                    -attr   => {
                        mysql_enable_utf8 => 1,
                        RaiseError => 0,
                        PrintError => 0,
                    },
                },
                
                bar => {
                    -dsn    => 'DBI:Oracle:SID',
                    -user   => 'login',
                    -pass   => 'password',
                    -attr   => {
                        RaiseError => 0,
                        PrintError => 0,
                    },
                }, 
            },
        );

    my @stores = $mso->stores; # foo, bar
    
    $mso->set(baz => new MPMinus::Store::DBI( {
                -dsn    => 'DBI:Oracle:BAZSID',
                -user   => 'login',
                -pass   => 'password',
                -attr   => {
                    RaiseError => 0,
                    PrintError => 0,
                },
            })
        );
        
    my @stores = $mso->stores; # foo, bar, baz
    
    my $foo = $mso->get('foo');
    my $foo = $mso->store('foo');
    my $foo = $mso->foo;

=head1 DESCRIPTION

Multistoring Database independent interface for MPMinus on MPMinus::Store::DBI based.

See L<MPMinus::Store::DBI>

=head1 METHODS

=over 8

=item B<get, store>

    my $foo = $mso->get('foo');
    my $foo = $mso->store('foo');
    my $foo = $mso->foo;

Getting specified connection by name

=item B<set>

    $mso->set(baz => new MPMinus::Store::DBI( {
                -dsn    => 'DBI:Oracle:BAZSID',
                -user   => 'login',
                -pass   => 'password',
                -attr   => {
                    RaiseError => 0,
                    PrintError => 0,
                },
            })
        );

Setting specified connection by name and returns state of operation

=item B<stores>

    my @stores = $mso->stores; # foo, bar, baz

Returns current connections as list (array)

=back

=head1 HISTORY

=over 8

=item B<1.00 / 13.11.2010>

Init version

=item B<1.01 / 22.12.2010>

ƒобавлен метод получени€ списка сторесов

=item B<1.02 / Wed Apr 24 14:53:38 2013 MSK>

General refactoring

=back

=head1 SEE ALSO

L<MPMinus::Store::DBI>, L<CTK::DBI>, L<Apache::DBI>, L<DBI>

=head1 AUTHOR

Serz Minus (Lepenkov Sergey) L<http://serzik.ru> E<lt>minus@mail333.comE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2013 D&D Corporation. All Rights Reserved

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

See C<LICENSE> file

=cut

use vars qw($VERSION);
$VERSION = 1.02;

use MPMinus::Store::DBI;
use CTK::Util qw/ :API /;

sub new {
    my $class = shift;
    my @in = read_attributes([
            ['M', 'GLOBAL', 'GLOB', 'MPMINUS', 'MPM'],
            ['CONFIG','MSCONFIG','MSO','CONF','DATA','MULTISTORE','STORES'],
        ],@_);
    my $m = $in[0];
    my $s = $in[1] || {};
    unless ($s && ref($s) eq 'HASH') {
        $s = {};
        # “ут читаем данные конфигурации (на перспективу)
        # $s = ...
    }
    my @stores = keys %$s; # ѕринимаем значени€ всех соединений
    
    # пробегаемс€ по всем соединени€м и устанавливаем их в общий массив
    my $ret = {};
    foreach my $store (@stores) {
        my $sc = $s->{$store};
        if ($sc && ref($sc) eq 'HASH') {
            $sc->{-m} = $m if $m;
            $ret->{$store} = new MPMinus::Store::DBI(%$sc);
        } else {
            $ret->{$store} = undef;
        }
    }
    
    return bless {
            m => $m,
            s => {%$s},
            stores => $ret,
        }, $class;
}
sub stores {
    # ¬озврат списка коннектов
    my $self = shift;
    my $stores = $self->{stores};
    return ($stores && ref($stores) eq 'HASH') ? keys(%$stores) : ();
}
sub get {
    # ¬озврат конкретного соединени€
    my $self = shift;
    my $name = shift;
    if ($name && $self->{stores} && $self->{stores}->{$name}) {
        return $self->{stores}->{$name};
    } else {
        carp("Can't find store \"$name\"");
    }
    return undef;
}
sub store { goto &get };
sub set {
    # ”становка конкретного соединени€
    my $self = shift;
    my $name = shift;
    my $value = shift;
    carp("Key name undefined") && return undef unless $name;
    carp("Value incorrect or is't MPMinus::Store::DBI object") && return undef unless $value && ref($value) eq 'MPMinus::Store::DBI';
    
    $self->{stores}->{$name} = $value;
}
sub AUTOLOAD {
    my $self = shift;
    our $AUTOLOAD;
    my $AL = $AUTOLOAD;
    my $ss = undef;
    $ss = $1 if $AL=~/\:\:([^\:]+)$/;
    
    if ($ss && $self->{stores} && $self->{stores}->{$ss}) {
        return $self->{stores}->{$ss};
    } else {
        carp("Can't find store \"$ss\"");
    }
    return undef;
}
sub DESTROY {
    my $self = shift;
    undef $self;
}

1;
