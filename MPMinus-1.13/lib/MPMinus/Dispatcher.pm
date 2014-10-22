package MPMinus::Dispatcher; # $Id: Dispatcher.pm 133 2013-05-15 13:59:54Z minus $
use strict;

=head1 NAME

MPMinus::Dispatcher - URL Dispatching

=head1 VERSION

Version 1.02

=head1 SYNOPSIS

    package MPM::foo::Handlers;
    use strict;

    use MPMinus::Dispatcher;

    sub handler {
        my $r = shift;
        my $m = MPMinus->m;
    
        $m->set(
                disp => new MPMinus::Dispatcher($m->conf('project'),$m->namespace)
            ) unless $m->disp;
    
        ...

        return Apache2::Const::OK;
    }

=head1 DESCRIPTION

URL Dispatching

=head1 METHODS

=over 8

=item B<new>

    my $disp = new MPMinus::Dispatcher(
            $m->conf('project'),
            $m->namespace)
        );

=item B<get>

    my $drec = $disp->get(
            -uri => $m->conf('request_uri')
        );

=item B<set>

    package MPM::foo::test;
    use strict;
    
    ...

    $disp->set(
            -uri    => ['locarr','test',
                        ['/test.mpm',lc('/test.mpm')]
                       ],
            -init     => \&init,
            -response => \&response,
            -cleanup  => \&cleanup,
            
            ... and other handlers's keys , see later ...
            
            -meta     => {}, # See MPMinus::Transaction
            
        );

=back

=head1 HANDLERS AND KEYS

Supported handlers:

    -postreadrequest
    -trans
    -maptostorage
    -init
    -headerparser
    -access
    -authen
    -authz
    -type
    -fixup
    -response
    -log
    -cleanup

See L<MPMinus::BaseHandlers/"HTTP PROTOCOL HANDLERS"> for details

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

use CTK::Util qw/ :API /; # ����������

sub new {
    my $class = shift;
    my @in = read_attributes([
          ['PROJECT','PRJ','SITE','PROJECTNAME','NAME'],
          ['NAMESPACE', 'NS']
        ],@_);

    # �������� ��������
    my $namespace = $in[1] || '';
    my %args = (
            project   => $in[0] || '', # ��� �������
            namespace => $namespace,   # ������������ ���� ��� ����������� ���������� ������ Index
            records   => {},           # ������ (URIs)
        );

    my $self = bless \%args, $class;
   
    # ������ ������. ������ �� ��������� (NOT_FOUND)
    $self->set('default');

    # ��������� ��������� �������
    eval "
        use $namespace\::Index;
        $namespace\::Index\::init(\$self);
    "; 
    croak("Error initializing the module $namespace\::Index\: $@") if $@;
    
    return $self;
}
sub set {
    # ���������� ������ ��� ��������� ������
    my $self = shift;
    my @in = read_attributes([
          ['URI','URL','REQUEST','KEY'], # 0
          
          # HTTP Protocol Handlers
          ['POSTREADREQUEST','HPOSTREADREQUEST','POSTREADREQUESTHANDLER'],  # 1
          ['TRANS','HTRANS','TRANSHANDLER'],                                # 2
          ['MAPTOSTORAGE','HMAPTOSTORAGE','MAPTOSTORAGEHANDLER'],           # 3
          ['INIT','HINIT','INITHANDLER'],                                   # 4
          ['HEADERPARSER','HHEADERPARSER','HEADERPARSERHANDLER'],           # 5
          ['ACCESS','HACCESS','ACCESSHANDLER'],                             # 6
          ['AUTHEN','HAUTHEN','AUTHENHANDLER'],                             # 7
          ['AUTHZ','HAUTHZ','AUTHZHANDLER'],                                # 8
          ['TYPE','HTYPE','TYPEHANDLER'],                                   # 9
          ['FIXUP','HFIXUP','FIXUPHANDLER'],                                # 10
          ['RESPONSE','HRESPONSE','RESPONSEHANDLER'],                       # 11
          ['LOG','HLOG','LOGHANDLER'],                                      # 12
          ['CLEANUP','HCLEANUP','CLEANUPHANDLER'],                          # 13
          
          ['ACTION','ACTIONS','META'], # 14
          
        ],@_);

    # ������������� ������
    my $uri = $in[0];
    my $uniqname;
    my $type = 'location';
    my %params;
    if (ref($uri) eq 'ARRAY') {
        # �� ������� ���������������
        croak("Invalid URI in the definition section of the called module") unless $uri->[0];
        if (lc($uri->[0]) eq 'regexp') {
            $type     = 'regexp';
            $uniqname = $uri->[1] || 'undefined'; # ���������� ���
            %params = (
                regexp => $uri->[2] || qr/^undefined$/
            )
        } elsif (lc($uri->[0]) eq 'locarr') {
            $type     = 'locarr';
            $uniqname = $uri->[1] || 'undefined'; # ���������� ���
            %params = (
                locarr => $uri->[2] || []
            )
        } elsif (lc($uri->[0]) eq 'mixarr') {
            $type     = 'mixarr';
            $uniqname = $uri->[1] || 'undefined'; # ���������� ���
            %params = (
                mixarr => $uri->[2] || []
            )            
        } else {
            croak("Wrong type dispatch called module!")
        }
    } else {
        # ������� ���������������
        $uniqname = $uri;
    }
    
    $self->{records}->{$uniqname} = {
            Postreadrequest => $in[1] || sub { Apache2::Const::OK },
            Trans           => $in[2] || sub { Apache2::Const::OK },
            Maptostorage    => $in[3] || sub { Apache2::Const::OK },
            Init            => $in[4] || sub { Apache2::Const::OK },
            headerparser    => $in[5] || sub { Apache2::Const::OK },
            Access          => $in[6] || sub { Apache2::Const::OK },
            Authen          => $in[7] || sub { Apache2::Const::OK },
            Authz           => $in[8] || sub { Apache2::Const::OK },
            Type            => $in[9] || sub { Apache2::Const::OK },
            Fixup           => $in[10] || sub { Apache2::Const::OK },
            Response        => $in[11] || \&default, # ����� ������� ����������!
            Log             => $in[12] || sub { Apache2::Const::OK },
            Cleanup         => $in[13] || sub { Apache2::Const::OK },
            
            type     => $type,         # ��� ���������������
            params   => {%params},     # ��������� (����������)
            actions  => $in[14] || {}, # �������
        };
    
}
sub get {
    # ���������� ����������
    my $self = shift;
    my @in = read_attributes([
          ['URI','URI','REQUEST','KEY'],
        ],@_);
    my $uri = $in[0] || 'default';
    my $ret = $uri;
    
    # ������� ����������� ���������������� �������� ������� �� ��������.
    # ������ ������� ����������� ���� �� ������� ������� � ����������!
    
    # ������� 1
    # ����� �� ����������� location
    $ret = 'default' unless grep {$_ eq $uri} keys %{$self->{records}};
    
    # ������� 2
    # ����� �� ������� ������ location
    if ($ret eq 'default') {
        # ����� ��������������� �����
        my @locarr_keys = grep {$self->{records}->{$_}->{type} eq 'locarr'} keys %{$self->{records}};
        foreach my $key (@locarr_keys) {
            $ret = $key if grep {$uri eq $_} @{$self->{records}->{$key}->{params}->{locarr}};
        }
        $ret ||= 'default';
    }

    # ������� 3
    # ����� �� ������� ������ location � Regexp
    if ($ret eq 'default') {
        # ����� ��������������� �����
        my @mixarr_keys = grep {$self->{records}->{$_}->{type} eq 'mixarr'} keys %{$self->{records}};
        foreach my $key (@mixarr_keys) {
            $ret = $key if grep {
                        if (ref $_ && lc(ref $_) eq 'regexp') {
                            $uri =~ $_
                        } else {
                            $uri eq $_
                        }
                    }
                    @{$self->{records}->{$key}->{params}->{mixarr}};
        }
        $ret ||= 'default';
    }

    
    # ������� 4
    # ����� �� regexp
    if ($ret eq 'default') {
        my @regexp_keys = grep {$self->{records}->{$_}->{type} eq 'regexp'} keys %{$self->{records}};
        if (@regexp_keys) {
            ($ret) = grep {$uri =~ $self->{records}->{$_}->{params}->{regexp}} @regexp_keys;
            $ret ||= 'default';
        }
    }
   
    return $self->{records}->{$ret};
}
sub default { Apache2::Const::NOT_FOUND };

1;
