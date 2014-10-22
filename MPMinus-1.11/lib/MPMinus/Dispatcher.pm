package MPMinus::Dispatcher; # $Id: Dispatcher.pm 113 2013-04-30 12:53:00Z minus $
use strict;

=head1 NAME

MPMinus::Dispatcher - URL Dispatching

=head1 VERSION

Version 1.01

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
          ['URI','URL','REQUEST','KEY'],
          ['INIT','HINIT','INITHANDLER'],
          ['ACCESS','HACCESS','ACCESSHANDLER'],
          ['FIXUP','HFIXUP','FIXUPHANDLER'],
          ['RESPONSE','HRESPONSE','RESPONSEHANDLER'],
          ['LOG','HLOG','LOGHANDLER'],
          ['CLEANUP','HCLEANUP','CLEANUPHANDLER'],
          ['ACTION','ACTIONS','META'],
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
            Init     => $in[1] || sub { Apache2::Const::OK },
            Access   => $in[2] || sub { Apache2::Const::OK },
            Fixup    => $in[3] || sub { Apache2::Const::OK },
            Response => $in[4] || \&default, # ����� ������� ����������!
            Log      => $in[5] || sub { Apache2::Const::OK },
            Cleanup  => $in[6] || sub { Apache2::Const::OK },
            
            type     => $type,         # ��� ���������������
            params   => {%params},     # ��������� (����������)
            actions  => $in[7] || {},  # �������
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
