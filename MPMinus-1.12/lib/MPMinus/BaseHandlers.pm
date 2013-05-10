package MPMinus::BaseHandlers; # $Id: BaseHandlers.pm 113 2013-04-30 12:53:00Z minus $
use strict;

=head1 NAME

MPMinus::BaseHandlers - Base handlers of MPMinus

=head1 VERSION

Version 1.01

=head1 SYNOPSIS

    package MPM::foo::Handlers;
    use strict;

    use MPMinus;
    use base qw/MPMinus::BaseHandlers/;
    
    sub new { bless {}, __PACKAGE__ }
    sub handler {
        my $r = shift;
        my $m = MPMinus->m;
        $m->conf_init($r, __PACKAGE__);

        # Handlers
        $r->handler('modperl'); # modperl, perl-script
        $r->set_handlers(PerlAccessHandler => sub { __PACKAGE__->AccessHandler($m) });
        $r->set_handlers(PerlFixupHandler => sub { __PACKAGE__->FixupHandler($m) });
        $r->set_handlers(PerlResponseHandler => sub { __PACKAGE__->ResponseHandler($m) });
        $r->set_handlers(PerlLogHandler => sub { __PACKAGE__->LogHandler($m) });
        $r->set_handlers(PerlCleanupHandler => sub { __PACKAGE__->CleanupHandler($m) });
        return __PACKAGE__->InitHandler($m);
    }
    sub InitHandler {
        my $pkg = shift;
        my $m = shift;

        # ... Setting Nodes ...
        # $m->set( nodename => ' ... value ... ' ) unless $m->nodename;
        
        ...

        return __PACKAGE__->SUPER::InitHandler($m);
    }

=head1 DESCRIPTION

Base handlers of MPMinus

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
$VERSION = 1.01;

use MPMinus::Dispatcher;
use Apache2::Const;

sub InitHandler {
    ########################
    # Секция инициализации #
    ########################
    my $pkg = shift;
    my $m = shift;
    
    # Dispatcher Nodes
    $m->set(disp => new MPMinus::Dispatcher($m->conf('project'),$m->namespace)) unless $m->disp;
    my $record = $m->disp->get(-uri=>$m->conf('request_uri'));
    $m->set(drec => $record);
    
    return $record->{Init}->($m) if $record->{Init};
    return Apache2::Const::OK;
}
sub AccessHandler {
    ###########################
    # Секция контроля доступа #
    ###########################
    my $pkg = shift;
    my $m = shift;
    my $record = $m->drec;
    return $record->{Access}->($m) if $record->{Access};
    return Apache2::Const::OK;
}
sub FixupHandler {
    ###########################################
    # Секция подготовки данных, предобработка #
    ###########################################
    my $pkg = shift;
    my $m = shift;
    my $record = $m->drec;
    return $record->{Fixup}->($m) if $record->{Fixup};
    return Apache2::Const::OK;
}
sub ResponseHandler {
    ##############################
    # Секция формирования ответа #
    ##############################
    my $pkg = shift;
    my $m = shift;
    my $record = $m->drec;
    return $record->{Response}->($m) if $record->{Response};
    return Apache2::Const::SERVER_ERROR;
} 
sub LogHandler {
    ##############################################
    # Секция записи данных о свершенных событиях #
    ##############################################
    my $pkg = shift;
    my $m = shift;
    $m->log("Index-record not found", "error") if $m->r->status() == Apache2::Const::NOT_FOUND;
    my $record = $m->drec;
    return $record->{Log}->($m) if $record->{Log};
    return Apache2::Const::OK;
}
sub CleanupHandler {
    ###################################
    # Очистка всех временных структур #
    ###################################
    my $pkg = shift;
    my $m = shift;
    my $record = $m->drec;
    return $record->{Cleanup}->($m) if $record->{Cleanup};
    return Apache2::Const::OK;
}

1;

