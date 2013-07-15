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
# $Id: 01-use.t 149 2013-05-29 09:35:05Z minus $
#
#########################################################################
use Test::More tests => 2;
BEGIN { use_ok('MPMinus'); };
is(MPMinus->VERSION,1.15,'Version checking');
1;
