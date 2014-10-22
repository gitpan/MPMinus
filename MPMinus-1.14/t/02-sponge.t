#!/usr/bin/perl -w
#########################################################################
#
# Serz Minus (Lepenkov Sergey), <minus@mail333.com>
#
# Copyright (C) 1998-2013 D&D Corporation. All Rights Reserved
# 
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# $Id: 02-sponge.t 127 2013-05-08 07:27:01Z minus $
#
#########################################################################
use Test::More tests => 9;
BEGIN { 
    use_ok('MPMinus::Store::DBI');
}

my $o = new_ok(MPMinus::Store::DBI => [
        -driver => 'Sponge',
        -attr   => { 
                RaiseError => 1,
                PrintError => 0,
            },
    ]);
isa_ok($o, "MPMinus::Store::DBI");
my $dbh = $o->connect();
ok($dbh, 'DB handler');
isa_ok($dbh, "DBI::db");
my $sth = $dbh->prepare("select * from table", {
        NAME => [
             qw/h1     h2     h3/],
        rows => [
            [qw/foo    bar    baz/],
            [qw/qux    quux   corge/],
            [qw/grault garply waldo/],
        ],
    });
isa_ok($sth, "DBI::st");
ok($sth->execute(), 'execute statement (SQL): select * from table');
my $result = $sth->fetchall_arrayref;
is(ref($result) => 'ARRAY', 'result is ARRAY');
is($result->[1][1] => 'quux', 'quux search');
1;
