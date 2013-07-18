package MPMinus::Helper::Handlers; # $Id: Handlers.pm 192 2013-07-17 19:13:18Z minus $
use strict;

=head1 NAME

MPMinus::Helper::Handlers - MPMinus helper's handlers

=head1 VERSION

Version 1.03

=head1 SYNOPSIS

    use base qw/MPMinus::Helper::Handlers/;

=head1 DESCRIPTION

MPMinus helper's handlers

See mpm manpage

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
$VERSION = 1.03;

use constant {
        NOTCONFIGURED => "MPMinus is not configured! Please type following command:\n\n\tmpm config",
        NOTBUILDED => "Skeleton is not builded! Please check your internet connection (http port)",
        NOTPROJECT => "Project missing. Use mpm project <projectname>",
        MAINTAINER => "http://search.cpan.org/src/ABALAMA/MPMinus-[VERSION]/src/mpminus-skel.tar.gz",
        OPERATIONS => [
                [qw/add controlleradd cadd/],
                [qw/list controllerlist clist/],
                [qw/del controllerdel cdel remove rm/],
                [qw/exit quit/],
            ],
    };

use CTK;
use CTK::ConfGenUtil;
use Config::General;
use TemplateM;
use Text::SimpleTable;
use Data::Dumper; $Data::Dumper::Deparse = 1;
use MPMinus::Helper::Util;
use MPMinus::Helper::Skel;
use MPMinus::Debug::System qw/metadata_info/;
use Try::Tiny;
use Perl::OSType qw/ os_type /;

use File::Copy;     # Export: copy / move
#use File::Path;     # Export: mkpath / rmtree
use File::Basename; # Export: dirname / basename
use File::Temp qw/tempfile tempdir/;
use File::Copy::Recursive qw(dircopy dirmove);

BEGIN {
    sub start { local $| = 1; print CTK::CTKCP @_ ? @_ : '' if CTK::DEBUG && $OPT{debug} }
    sub finish { say(@_) if CTK::DEBUG && $OPT{debug} }
    sub _{my $s=shift||'';my $l=length $s;$s.($l<70?('.'x(70-$l)):'').' '}
}

sub VOID {
    my %cmd = @_; #debug(join "; ",@{$cmd{arguments}});
    my $c = _generalc();
    my $config = $c->config;
    
    # Подготавливаем данные
    my $cgsf = [];
    if (value($config,'loadstatus')) {
        $cgsf = array($config, 'configfiles') || [];
    }
    my $env = Dumper(\%ENV);
    my $inc = Dumper(\@INC);
    my $cfg = Dumper($config);

    # Непосредственно данные
    my @rslth = qw/foo bar baz/;
    my @rsltd = (
            [qw/qwe rty uiop/],
            [qw/asd fgh jkl/],
            [qw/zxc vbn m/],
        );
    my $data = _result('text',\@rslth,\@rsltd);

    # Отладка
    debug "Directories:";
    debug "    DATADIR  : ",$c->datadir;
    debug "    LOGDIR   : ",$c->logdir;
    debug "    LOGFILE  : ",$LOGFILE;
    debug "    CONFDIR  : ",$c->confdir;
    debug "    CONFFILE : ",$c->cfgfile;
    debug "Loaded configuration files:";
    debug("    ",($_ || '')) for (@$cgsf);
    debug "-----BEGIN ENV DUMP-----";
    debug $env;
    debug "-----END ENV DUMP-----";
    debug "-----BEGIN INC DUMP-----";
    debug $inc;
    debug "-----END INC DUMP-----";
    debug "-----BEGIN CFG DUMP-----";
    debug $cfg;
    debug "-----END CFG DUMP-----";
    debug "Data:";
    debug $data;
    
    # Всяка-разна
    
    1;
}
sub CONFIG {
    # Настройка системы
    say("MPMinus configuration...");
    my %cmd = @_;
    my ($param, $value) = @{$cmd{arguments}};
    my $c = _generalc();
    my $config = $c->config;
    my $cfile = $CONFFILE;
    my $skel = new MPMinus::Helper::Skel( -c => $c, s => $OPT{sharedir}, -url => MAINTAINER, );
    unless ($skel->checkstatus) { say(NOTBUILDED) unless $skel->build }
    
    debug("Config file     : $cfile");
    debug("Skeleton status : ".($skel->checkstatus ? 'OK' : 'ERROR'));

    if ($param) {
        # Конфигурирование отдельно-взятого параметра
        say("Edit configuration option \"$param\"...");
        unless ($value) {
            my $now = value($config, $param);
            $now = '' unless defined $now;
            $value = $c->cli_prompt("Input new value (now set: \"$now\"):");
        }
        $config->{$param} = $value;
        say("Option \"$param\" set to: \"",$value,"\"");
    } else {
        # Переконфигурирование системы полностью
        if ($c->cli_prompt('Are you sure you want to change all of parameter setting?:','no') =~ /^\s*y/i) {
            say("Creating mpm configuration...");
            $config = newconfig($c);
        } else {
            say("Aborted");
            return 1;
        }
    }
    #say Dumper($config);
    
    # Запись в файл
    my $conf = new Config::General( -ConfigHash => $config );
    $conf->save_file($cfile);
    say("Done");
    
    1;
}
sub TEST {
    # Тестирование функционала и вывод итоговой таблицы
    my $c = _generalc();
    my $config = $c->config;
    my ($steps, $i) = (11,0);
    my $tbl = Text::SimpleTable->new( 
            [ 25, 'PARAM' ],
            [ 57, 'VALUE / MESSAGE' ],
            [ 7,  'RESULT' ],
        );
    my $tst = '';
    my $v = '';
    
    # PASSED  -- Тест пройден!
    # FAILED  -- Тест НЕ пройден!
    # SKIPPED -- Тест пропущен!
    
    # debug's finishes:
    #  DONE   -- Процесс тестирования прошел корректно
    #  ERROR  -- Процесс тестирования прошел с ошибками
    
    # 1. Процесс httpd, доступность переменных и основных каталогов
    $tst = "HTTPD values";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    my $apache = getApache($c);
    my ($aroot, $aconfig) = ($apache->{HTTPD_ROOT},$apache->{SERVER_CONFIG_FILE});
    $tbl->row('HTTPD root directory', $aroot, ($aroot && (-e $aroot) && ((-d $aroot) || (-l $aroot))) ? 'PASSED' : 'FAILED');
    $tbl->row('HTTPD server config file', $aconfig, ($aconfig && (-e $aconfig) && ((-f $aconfig) || (-l $aconfig))) ? 'PASSED' : 'FAILED');
    finish "DONE";
    
    # 2. ModPerlRoot
    $tst = "MPMinus root directory";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    $v = to_void($config->{lc('ModPerlRoot')});
    if ($v) { $tbl->row($tst, $v, ((-e $v) && ((-d $v) || (-l $v))) ? 'PASSED' : 'FAILED') } 
    else { $tbl->row($tst, $v, 'SKIPPED') }
    finish "DONE";
    
    # 3. ApacheHomePath
    $tst = "Apache root directory";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    $v = to_void($config->{httpdroot});
    if ($v) { $tbl->row($tst, $v, ((-e $v) && ((-d $v) || (-l $v))) ? 'PASSED' : 'FAILED') } 
    else { $tbl->row($tst, $v, 'SKIPPED') }
    finish "DONE";

    # 4. ApacheConfigFile
    $tst = "Apache config file";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    $v = to_void($config->{serverconfigfile});
    if ($v) { $tbl->row($tst, $v, ((-e $v) && ((-f $v) || (-l $v))) ? 'PASSED' : 'FAILED') } 
    else { $tbl->row($tst, $v, 'SKIPPED') }
    finish "DONE";

    # 5. ServerName
    $tst = "Global server name";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    $v = to_void($config->{lc('ServerName')});
    eval "
        no warnings;
        no strict;
        require Net::Ping;
        my \$pingo = Net::Ping->new('tcp', 5);
        my (\$hn,\$pn) = split(':','$v');
        \$hn ||= '$v';
        \$pn ||= '80';
        \$hn =~ s/\:.*//g;
        \$pingo->port_number(\$pn);
        my \$ee = \"Server \\\"\$hn\\\" not reachable on port \\\"\$pn\\\"\" 
        unless \$pingo->ping(\$hn);
        \$pingo->close();
        undef(\$pingo);
        die(\$ee) if \$ee;
    ";
    my $evalerror = $@ || '';
    if ($evalerror) {
        $tbl->row($tst, $v."\n".$evalerror, 'FAILED');
        finish "ERROR";
        debug($evalerror);
    } else {
        $tbl->row($tst, $v, $v ? 'PASSED' : 'SKIPPED');
        finish "DONE";
    }
    
    # 6. NameVirtualHost
    $tst = "NameVirtualHost";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    $v = to_void(value($config->{lc('NameVirtualHost')}));
    $tbl->row($tst, $v, $v ? 'PASSED' : 'FAILED');    
    finish "DONE";

    # 7. SMTP
    $tst = "SMTP server";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    my $smtptrysend = 1;
    $v = to_void(value($config->{lc('SMTP')}));
    if ($v) {
        eval "
            no warnings;
            no strict;
            require Net::SMTP;
            my \$smtp = Net::SMTP->new('$v', Timeout => 5);
            die('Server \"$v\" not reachable') unless \$smtp;
            my \$domainresult = \$smtp->domain() || '';
            my \$ee = 'SMTP domain not defined' unless \$domainresult;
            \$smtp->quit;
            die(\$ee) if \$ee;
        ";
        $evalerror = $@ || '';
        if ($evalerror) {
            $tbl->row($tst, $v."\n".$evalerror, 'FAILED');
            finish "ERROR";
            debug($evalerror);
            $smtptrysend = 0;
        } else {
            $tbl->row($tst, $v, 'PASSED');
            finish "DONE";
        }
    } else {
        $smtptrysend = 0 if $c->isostype("Windows");
        $tbl->row($tst, $v, 'SKIPPED');    
        finish "DONE";
    }

    # 8. MAIL address
    $tst = "MAIL address";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    $v = to_void($config->{lc('MailTo')});
    $tbl->row('MailTo', $v, $v ? 'PASSED' : 'FAILED');
    $v = to_void($config->{lc('MailFrom')});
    $tbl->row('MailFrom', $v, $v ? 'PASSED' : 'FAILED');
    $v = to_void($config->{lc('ErrorMail')});
    $tbl->row('ErrorMail', $v, $v ? 'PASSED' : 'FAILED');
    $v = to_void($config->{lc('MailCC')});
    $tbl->row('MailCC', $v, $v ? 'PASSED' : 'SKIPPED');
    $v = to_void($config->{lc('MailChrST')});
    $tbl->row('MailCharSet', $v, $v ? 'PASSED' : 'SKIPPED');
    $v = to_void($config->{lc('MailCmd')});
    $tbl->row('MailCommand', $v, $v ? 'PASSED' : 'SKIPPED');
    $v = to_void($config->{lc('MailFlag')});
    $tbl->row('MailFlag', $v,  $v ? 'PASSED' : 'SKIPPED');
    finish "DONE";
    
    # 9. Skeleton files
    $tst = "Skeleton files";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    my $skel = new MPMinus::Helper::Skel( -c => $c, s => $OPT{sharedir}, -url => MAINTAINER, );
    if ($skel->checkstatus) { $v = 1 } else { $v = $skel->build }
    $tbl->row($tst, $skel->{skeldir}, $v ? 'PASSED' : 'FAILED');    
    finish "DONE";
    
    # 10. Версия MPMinus (backward)
    $tst = "Version of mpminus-skel";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    my $mpminusv = $skel->{rplc}{VERSION};
    $tbl->row($tst, $mpminusv, $mpminusv =~ /^\d+\.\d+$/ ? 'PASSED' : 'FAILED');    
    finish "DONE";

    # 11. Отправка письма
    $tst = "Trying mail sending";
    start _ sprintf('%d/%d %s',++$i,$steps, $tst);
    
    if ($smtptrysend) {
        $v = CTK::sendmail(
            -to      => $config->{lc('MailTo')},
            -cc      => $config->{lc('MailCC')},
            -from    => $config->{lc('MailFrom')},
            -charset => $config->{lc('MailChrST')},
            -smtp    => $config->{lc('SMTP')},
            -sendmail=> $config->{lc('MailCmd')},
            -flags   => $config->{lc('MailFlag')},
            -subject => 'MPMinus test message',
            -message => "Test report\n===========\n\n".$tbl->draw,
        );
        if ($v) {
            $tbl->row($tst, 'Mail has been sent', 'PASSED');
            finish "DONE";
            
        } else {
            $tbl->row($tst, 'Mail was NOT sent', 'FAILED');
            finish "ERROR";
            debug('Mail was NOT sent');
        }
    } else {
        $tbl->row($tst, '', 'SKIPPED');
        finish "DONE";
    }
    
    #exception("blah-blah-blah");
    say($tbl->draw);
    1;
}
sub CREATE {
    # Создание проекта
    my %cmd = @_;
    my ($pname) = @{$cmd{arguments}};
    my $c = _generalc();
    my $config = $c->config;
    say(NOTCONFIGURED) && return 0 unless $config->{loadstatus} && $config->{httpdroot};
    my $skel = new MPMinus::Helper::Skel( -c => $c, s => $OPT{sharedir}, -url => MAINTAINER, );
    unless ($skel->checkstatus) { say(NOTBUILDED) && return 0 unless $skel->build }
    #say $skel->checkstatus ? 'SKELETON OK' : 'SKELETON ERROR';
    #say Dumper($skel);
    my %h;
    
    # 1. Создаем табличку как в тесте для отображения результатов
    my $tbl = Text::SimpleTable->new( 
            [ 25, 'PARAM' ],
            [ 57, 'VALUE / MESSAGE' ],
        );

    # 2. Наполняем переменные которые будут использоваться для стеширования
    
    # ServerConfigFile & HttpdRoot
    $h{ServerConfigFile} = to_void(value($config->{lc('ServerConfigFile')}));
    $h{ServerConfigFile} =~ s/\\/\//g;
    $h{HttpdRoot} = to_void(value($config->{lc('HttpdRoot')}));
    $h{HttpdRoot} =~ s/\\/\//g;
    
    say("\nGeneral project data\n");
    
    # ProjectName
    $pname = cleanProjectName($pname);
    unless ($pname) {
        $pname = cleanProjectName($c->cli_prompt('Project Name:', 'Foo'));
    }
    $h{'ProjectName'} = $pname;
    $h{'ProjectNameL'} = lc("$pname");
    $tbl->row( 'ProjectName', $pname );

    # ServerName & ServerNameF & ServerNameC
    my $servername = cleanServerName($c->cli_prompt('Server Name (site):', 
            lc("$pname").'.'.(value($config->{lc('ServerName')}) || 'localhost')
        ));
    $h{ServerName} = $servername;
    my $servernamef = cleanServerNameF($servername);
    $h{ServerNameF} = $servernamef;
    my $servernamec = $servername;
    $servernamec =~ s/\:\d+$//;
    $h{ServerNameC} = $servernamec;
    $tbl->row( 'ServerName', $servername );
    $tbl->row( 'ServerNameF', $servernamef );
    
    # ServerAlias
    my $serveralias = cleanServerName($c->cli_prompt('Server Alias (second site name):',''));
    $h{ServerAlias} = $serveralias;
    $tbl->row( 'ServerAlias', $serveralias );
    
    # ProjectVersion
    my $prjver = $c->cli_prompt('Current Project Version:','1.00');
    if ($prjver !~ /^\d{1,2}\.\d{1,2}$/) {
        # Некорректная версия
        say("   Invalid Version \"$prjver\"");
        $prjver = '1.00';
    }
    $h{ProjectVersion} = $prjver;
    $tbl->row( 'ProjectVersion', $prjver );
    
    # GMT
    my $gmt = CTK::dtf("%w %MON %_D %hh:%mm:%ss %YYYY %Z", time(), 'GMT'); # scalar(gmtime)." GMT";
    $h{GMT}  = $gmt;
    $tbl->row( 'GMT', $h{GMT} );
    
    # Platform
    my $platform = $^O || 'Unix';
    $platform =~ s/[^a-z0-9_]/X/ig;
    $h{Platform} = $platform;
    $h{PlatformType} = os_type($platform);
    $tbl->row( 'Platform', $h{Platform} );
    $tbl->row( 'PlatformType', $h{PlatformType} );

    # ServerAdmin
    my $serveradmin = $c->cli_prompt('Server Admin Email:', 
            value($config->{lc('ErrorMail')}) || 'root@localhost'
        );
    $h{ServerAdmin} = $serveradmin;
    $tbl->row( 'ServerAdmin', $h{ServerAdmin} );

    # SMTP
    my $smtp = $c->cli_prompt('SMTP Server:', value($config->{lc('SMTP')}) || '');
    $h{SMTP} = $smtp || '0';
    $tbl->row( 'SMTP', $h{SMTP} );

    # DefaultCharset
    my $defaultcharset = $c->cli_prompt('DefaultCharset:','utf-8');
    $h{DefaultCharset} = $defaultcharset;
    $tbl->row( 'DefaultCharset', $h{DefaultCharset} );
    
    # ContentType
    my $contenttype = $c->cli_prompt('ContentType:',"text/html; charset=$defaultcharset");
    $h{ContentType} = $contenttype;
    $tbl->row( 'ContentType', $h{ContentType} );

    # DocumentRoot & ModperlRoot
    my $modperlroot  = to_void(value($config->{lc('ModperlRoot')}));
    my $documentroot = $c->cli_prompt('DocumentRoot:', CTK::catdir($modperlroot || CTK::webdir, $servernamec));
    $documentroot =~ s/\\/\//g;
    $h{DocumentRoot} = $documentroot;
    $tbl->row( 'DocumentRoot', $h{DocumentRoot} );
    
    # ModperlRoot
    my $newmproot = $c->cli_prompt('ModperRoot (DocumentRoot for MPM):', $documentroot);
    $h{ModperlRoot} = $newmproot;
    $tbl->row( 'ModperlRoot', $h{ModperlRoot} );

    # Спрашиваем, ведь папка введена существующая
    if ( $documentroot && -e $documentroot && $c->cli_prompt('Directory already exists! Are you sure you want to continue?:','no') !~ /^\s*y/i) {
        say('Operation aborted');
        return 1;
    }

    # VirtualHost
    $h{NameVirtualHost} = to_void(value($config->{lc('NameVirtualHost')}));
    $tbl->row( 'NameVirtualHost', $h{NameVirtualHost} );

    # IncludePath
    $h{IncludePath} = CTK::catdir($documentroot,'inc');
    $h{IncludePath} =~ s/\\/\//g;
    $tbl->row( 'IncludePath', $h{IncludePath} );

    say("\nAddition information\n");
    
    # License
    my $lic = $c->cli_prompt('License:','GPL');
    $h{License} = $lic;
    $tbl->row( 'License', $h{License} );

    # Author
    my $author = $c->cli_prompt('Your Full Name:','Mr. Anonymous');
    $h{Author} = $author;
    $tbl->row( 'Author', $h{Author} );

    say("\nSystem flags\n");
    
    # GlobalDebug
    my $globaldebug = $c->cli_prompt('Flag GlobalDebug:','no');
    $h{GlobalDebug} = $globaldebug  && $globaldebug =~ /^\s*y/i ? 1 : 0;
    $tbl->row( 'GlobalDebug', $h{GlobalDebug} );
    
    say("\nDebug handlers (serverstatus, serverinfo and perlstatus)\n");
    
    # ServerStatus
    my $serverstatus = $c->cli_prompt('ServerStatus Location enable?:','no') =~ /^\s*y/i ? 1 : 0;
    $h{ServerStatus} = $serverstatus;
    $tbl->row( 'ServerStatus', $h{ServerStatus} );
    
    # ServerInfo
    my $serverinfo = $c->cli_prompt('ServerInfo Location enable?:','no') =~ /^\s*y/i ? 1 : 0;
    $h{ServerInfo} = $serverinfo;
    $tbl->row( 'ServerInfo', $h{ServerInfo} );
    
    # PerlStatus
    my $perlstatus = $c->cli_prompt('PerlStatus Location enable?:','no') =~ /^\s*y/i ? 1 : 0;
    $h{PerlStatus} = $perlstatus;
    $tbl->row( 'PerlStatus', $h{PerlStatus} );
    
    say("\nEnabled controllers\n");

    # RootController
    my $rootc = $c->cli_prompt('Enable Root controller?:','yes') =~ /^\s*y/i ? 1 : 0;
    $h{RootController} = $rootc;
    $tbl->row( 'RootController', $h{RootController} );
    
    # InfoController
    my $infoc = $c->cli_prompt('Enable Info (Kernel) controller?:','yes') =~ /^\s*y/i ? 1 : 0;
    $h{InfoController} = $infoc;
    $tbl->row( 'InfoController', $h{InfoController} );
    
    # 3. Отрисовка результата перед запросом
    say($tbl->draw);
    unless ($c->cli_prompt('All right?:','yes') =~ /^\s*y/i) {
        say('Operation aborted');
        #say(Dumper(\%h));
        return 1;
    }

    # Запрос на отправку письма
    my $sendreport = $c->cli_prompt('Send report to e-mail?:','no') =~ /^\s*y/i ? 1 : 0;

    say("\nCreating project \"$pname\"...");
    
    # 4. Получается список файлов (с их путями) для создания проекта из файла MANIFEST
    # MANIFEST и SUMMARY не должны быть приведены в файле MANIFEST!
    start _ ">>> Reading MANIFEST file";
    my $manifest = $skel->readmanifest;
    finish $manifest && ref($manifest) eq 'HASH' ? "OK" : "ERROR";
    #say Dumper($skel->readmanifest);
    
    start _ ">>> Reading SUMMARY file";
    my $summary = $skel->readsummary;
    finish $summary ? "OK" : "ERROR";
    
    my $tmpdir = tempdir( CLEANUP => 1 );
    
    # 5. Создается проект используя шаблонные методы templatem через try {} catch {};
    $manifest = {} unless $manifest && ref($manifest) eq 'HASH';
    my $n = scalar(keys %$manifest);
    my $i = 0;
    foreach my $km (keys %$manifest) {$i++;
        start _ sprintf('>>> Processing %d/%d "%s"', $i, $n, $km);

        # Path & SubDirectories
        my $kmf = $km;
        $kmf =~ s/PROJECTNAME/$pname/g;
        $kmf =~ s/PLATFORM/$platform/g;
        $kmf =~ s/SERVERNAMEF/$servernamef/g;
        $kmf =~ s/MANIFEST.MPM/MANIFEST/g;
        my $f_src   = $manifest->{$km};             # Источник (файл)
        my $f_dst   = CTK::catfile($tmpdir,$pname,$kmf); # Приемник (файл)
        my $dir_src = dirname($f_src);              # Источник (каталог)
        my $dir_dst = dirname($f_dst);              # Приемник (каталог)
        CTK::preparedir( $dir_dst, 0777 ) or finish("ERROR") && next;
        
        if (-B $f_src) { # Обработка двоичных файлов
            copy($f_src,$f_dst) or finish("ERROR") && say("Copy failed \"$f_src\" -> \"$f_dst\": $!") && next;
        } elsif ($km =~ /s?html?$/) { # Файлы SHTML и HTML копируем!
            copy($f_src,$f_dst) or finish("ERROR") && say("Copy failed \"$f_src\" -> \"$f_dst\": $!") && next;
        } else {
            my $f_dst_orig = $f_dst.".orig"; # Имя файла оригинала
            
            if ($km =~ /\.(conf|ht\w+)$/) { # Все файлы конфигурации должны быть сохранены!
                my $f_fd = CTK::catfile($documentroot,$kmf); # Самый конечный ресурс
                my $f_fd_old = $f_fd.".orig"; # Имя файла оригинала на конечном ресурсе
                if (-e $f_fd) {
                    # Файл конечный существует, значит есть над чем поработать!
                    if (-e $f_fd_old) {
                        # Нашелся ранее сохраненный файл оригинала. Копируем его в TMP
                        copy($f_fd_old,$f_dst_orig) or debug("Copy failed \"$f_fd_old\" -> \"$f_dst_orig\": $!");
                    } else {
                        # Никакого сохраненного ранее файл оригинала нет, 
                        # значит можем переименовать имеющийся конфигурауционный в .orig
                        copy($f_fd,$f_dst_orig) or debug("copy failed \"$f_fd\" -> \"$f_dst_orig\": $!");
                    }
                }
            }
                
            # Выполнение процессинга !!!
            try {
                my $tpl = new TemplateM(-file => $f_src, -asfile => 1, -utf8 => 1);
                $tpl->stash(%h);
                $tpl->cast_if($_,$h{$_} ? 1 : 0) foreach (qw/ServerAlias ServerStatus ServerInfo PerlStatus/);
                $tpl->cast_if('UTF8', $defaultcharset && $defaultcharset =~ /^utf\-?8/i);
                my $cbox = $tpl->start('Controllers');
                    $cbox->loop(Controller => 'Root') if $rootc;
                    $cbox->loop(Controller => 'Info') if $infoc;
                $cbox->finish;
                CTK::bsave($f_dst, $tpl->output(), 1);
            } catch {
                finish("ERROR");
                say("Processing failed \"$f_src\" -> \"$f_dst\": $_");
                next;
            };
            
        }

        finish "OK";
    }
    
    # Копирование всей структуры в папку назначения
    start _ ">>> Moving directories";
    my $dir_from = CTK::catdir($tmpdir,$pname);
    my $dir_into = $documentroot;
    if (dirmove($dir_from,$dir_into)) {
        finish "OK";
    } else {
        finish("ERROR");
        say("Can't move directory \"$dir_from\" -> \"$dir_into\": $!");
    }
    
    # 6. Запускается команда /usr/bin/perl Makefile.PL (см. pays для примера)

    # Запрос на выполнение команды
    if ($c->cli_prompt('Try to install the module automatically?:','yes') =~ /^\s*y/i) {
        my $myperl = CTK::syscfg('perlpath') || 'perl';
        my $mymake = MPMinus::Helper::Skel::Backward::get_make() || 'make';
        my $myroot = $documentroot; 
        $myroot =~ s/\//\\/g if CTK::isostype('Windows');
        CTK::execute(qq{cd $myroot && $myperl Makefile.PL && $mymake && $mymake test && $mymake install && $mymake clean});
    } else {
        say("Your site can\'t installed! Please type following commands:\n");
        say("\tcd $documentroot");
        say("\tperl Makefile.PL");
        say("\tmake");
        say("\tmake test");
        say("\tmake install");
        say("\tmake clean");
    }
    
    say("OK");
    
    # 7. выдается поздравительное сообщение из файла SUMMARY простешировав все величины
    my $t = new TemplateM(-template => $summary);
    $t->stash(%h);
    my $summarypage = $t->output();
    say($summarypage);
    
    # 8. Отправляется письмо с текстом SUMMARY
    if ($sendreport) {
        my $mvs = CTK::sendmail(
            -to      => $serveradmin,
            -cc      => $config->{lc('MailCC')},
            -from    => $config->{lc('MailFrom')},
            -charset => $config->{lc('MailChrST')},
            -smtp    => $config->{lc('SMTP')},
            -sendmail=> $config->{lc('MailCmd')},
            -flags   => $config->{lc('MailFlag')},
            -subject => 'MPMinus report',
            -message => "Create project report\n".
                        "=====================\n".
                        "\n".$tbl->draw."\n".
                        "Message\n".
                        "=======\n".
                        "\n".$summarypage."\n",
        );
        if ($mvs) 
            { debug('Mail has been sent') } 
        else 
            { debug('Mail was NOT sent') }
    }
    
    1;
}
sub PROJECT {
    # Управление проектом
    my %cmd = @_;
    my ($pname, $pcmd, $controller) = @{$cmd{arguments}}; # Project, Command, Controller
    my $c = _generalc();
    my $config = $c->config;
    say(NOTCONFIGURED) && return 0 unless $config->{loadstatus} && $config->{httpdroot};
    my $skel = new MPMinus::Helper::Skel( -c => $c, s => $OPT{sharedir}, -url => MAINTAINER, );
    unless ($skel->checkstatus) { say(NOTBUILDED) && return 0 unless $skel && $skel->build }
    my %h;

    # Проверки на "вшивость" и определение команд/значений
    say(NOTPROJECT) && return 0 unless $pname;

    # ServerName & ServerNameF & ServerNameC
    my $pnamel = lc("$pname");
    my $servername = cleanServerName($pnamel.'.'.(value($config->{lc('ServerName')}) || 'localhost'));
    my $servernamef = cleanServerNameF($servername);
    my $servernamec = $servername; $servernamec =~ s/\:\d+$//;

    # DocumentRoot & ModperlRoot & Metafile
    my $modperlroot  = value($config->{lc('ModperlRoot')});
    my $documentroot = CTK::catdir($modperlroot || CTK::webdir, $servernamec);
    my $metaf = CTK::catfile($documentroot, "META.yml");
    unless ( $documentroot && -e $documentroot && -e $metaf) {
        $documentroot = $modperlroot;
        $metaf = CTK::catfile($documentroot, "META.yml");
        unless ( $documentroot && -e $documentroot && -e $metaf) {
            $documentroot = $c->cli_prompt("Please enter DocumentRoot directory:");
            $metaf = CTK::catfile($documentroot, "META.yml") if $documentroot && -e $documentroot;;
        }
        unless ( $documentroot && -e $documentroot && -e $metaf) {
            say("Project in \"$documentroot\" not found! Operation aborted");
            return 0;
        }
    }
    
    # Operations
    my %ops; 
    $pcmd ||= '';
    foreach (@{(OPERATIONS)}) { $ops{$_->[0]} = $_ };
    my $needenter = 1;
    foreach my $k (keys %ops) {
        my $v = $ops{$k};
        if (grep { lc($pcmd) eq $_ } @$v) {
            $needenter = 0;
            $pcmd = $k;
            last;
        }
    }
    $pcmd = $c->cli_select('Please select the command:', [(sort {$a cmp $b} keys %ops)], 'exit') if $needenter;
    say("Bye") && return 1 if $pcmd eq 'exit';
    
    # Чтение манифеста и метафайла
    start _ ">>> Reading MANIFEST file";
    my $manifest = $skel->readmanifest;
    if ($manifest && ref($manifest) eq 'HASH') { 
        finish "OK";
    } else {
        finish "ERROR";
        say "Cant' load file MANIFEST";
        return 0;
    }
    start _ ">>> Reading META file";
    my %meta = metadata_info($metaf);
    if (%meta && $meta{Error}) {
        finish "ERROR";
        say $meta{Error};
        return 0;
    } else {
        finish "OK";
    }
    #say Dumper($manifest);    
    #say Dumper(\%meta);

    # Формирование массива %h для стеширование и формирование данных контроллеров
    if ( 1
            && $meta{x_mpminus} 
            && (ref($meta{x_mpminus}) eq 'HASH') 
            && ($meta{x_mpminus}{ProjectNameL} eq $pnamel)
        ) {
        %h = %{($meta{x_mpminus})};
        $pname = $meta{x_mpminus}{ProjectName} if $meta{x_mpminus}{ProjectName};
    } else {
        say "Metadata incorrect! Please rebuild the project \"$pname\"";
        return 0;
    }
    #say Dumper(\%h);
    
    # Получение списка контроллеров из метаданных
    my $allowcontrollers = array($h{Controllers});
    if ($pcmd eq 'list') {
        if (@$allowcontrollers) {
            say("Available controllers of project \"$pname\"\n\t", join("\n\t",@$allowcontrollers), "\n");
        } else {
            say("No controllers found");
        }
        return 1;
    }
    
    # Получение путей Index.pm, Foo.pm и Makefile.PL из манифеста
    my $index_src    = $manifest->{'lib/MPM/PROJECTNAME/Index.pm'} || '';
    my $foo_src      = $index_src;
    $foo_src =~ s/Index/Foo/;
    my $makefile_src = $manifest->{'Makefile.PL'} || '';
    
    my @clist;
    $controller = cleanProjectName($controller);
    unless ($controller) {
        if ($pcmd eq 'del') {
            # FOR DEL
            $controller = cleanProjectName($c->cli_select(
                    'Please select controller for removig:',
                    $allowcontrollers,
                    1,
                ));
        } else {
            # FOR ADD
            say("Already exists controllers:\n\t", join("\n\t",@$allowcontrollers), "\n");
            $controller = cleanProjectName($c->cli_prompt('Please enter new controller name:', 'Foo'));
        }
    }
    say("Controller incorrect") && return 0 unless $controller;
    $h{ControllerName} = $controller;
    
    # Типовые операции
    if ($pcmd eq 'del') {
        # FOR DEL
        say("Controller \"$controller\" not exists. Operation aborted") && return 0 unless 
            grep {$_ eq $controller} @$allowcontrollers;
        
        # Модифкация списка котроллеров
        @clist = grep {$_ ne $controller} @$allowcontrollers; # Удаляем
        
    } else {
        # FOR ADD
        say("Controller \"$controller\" already exists. Operation aborted") && return 0 if 
            grep {$_ eq $controller} @$allowcontrollers;
            
        # Проверка контроллера на уровне файлов
        my $foo_dst = CTK::catfile($documentroot,'lib','MPM',$pname,$controller.".pm");
        my $overwrite = 1;
        $overwrite = 0 if (1
            && (-e $foo_dst) 
            && $c->cli_prompt("File \"$foo_dst\" already exists. Overwrite it?:",'no') !~ /^\s*y/i
        );
        
        # Модифкация списка котроллеров
        @clist = @$allowcontrollers;
        push @clist, $controller unless grep {$_ eq $controller} @clist;
        
        # Запись нового файла контроллера
        start _ ">>> Writing \"$foo_dst\"";
        if ($overwrite) {
            try {
                my $tpl = new TemplateM(-file => $foo_src, -asfile => 1, -utf8 => 1);
                $tpl->stash(%h);
                CTK::bsave($foo_dst, $tpl->output(), 1);
                finish("OK");
            } catch {
                finish("ERROR");
                say("Processing \"$foo_src\" failed: $_");
            };
        } else {
            finish("SKIPPED");
        }
        
    }
    
    # Запись нового индексного файла
    my $index_dst = CTK::catfile($documentroot,'lib','MPM',$pname,"Index.pm");
    start _ ">>> Writing \"$index_dst\"";
    try {
        my $itpl = new TemplateM(-file => $index_src, -asfile => 1, -utf8 => 1);
        $itpl->stash(%h);
        my $cbox = $itpl->start('Controllers');
        $cbox->loop(Controller => $_) foreach (grep {$_} @clist);
        $cbox->finish;
        CTK::bsave($index_dst, $itpl->output(), 1);
        finish("OK");
    } catch {
        finish("ERROR");
        say("Processing \"$index_src\" failed: $_");
    };

    # Запись нового мейкера
    my $makefile_dst = CTK::catfile($documentroot,"Makefile.PL");
    start _ ">>> Writing \"$makefile_dst\"";
    try {
        my $mtpl = new TemplateM(-file => $makefile_src, -asfile => 1, -utf8 => 1);
        $mtpl->stash(%h);
        my $mbox = $mtpl->start('Controllers');
        $mbox->loop(Controller => $_) foreach (grep {$_} @clist);
        $mbox->finish;
        CTK::bsave($makefile_dst, $mtpl->output(), 1);
        finish("OK");
    } catch {
        finish("ERROR");
        say("Processing \"$makefile_src\" failed: $_");
    };
    
    # Перенос META.xml перед мейкингом
    if ( -e $metaf.".old" ) {
        unlink $metaf;
    } else {
        move($metaf,$metaf.".old") or debug("Move failed \"$metaf\" -> \"$metaf.old\": $!");
    }
    
    # Запрос на выполнение команды
    if ($c->cli_prompt('Try to install the module automatically?:','yes') =~ /^\s*y/i) {
        my $myperl = CTK::syscfg('perlpath') || 'perl';
        my $mymake = MPMinus::Helper::Skel::Backward::get_make() || 'make';
        my $myroot = $documentroot; 
        $myroot =~ s/\//\\/g if CTK::isostype('Windows');
        CTK::execute(qq{cd $myroot && $myperl Makefile.PL && $mymake && $mymake test && $mymake install && $mymake clean});
    } else {
        say("Your site can\'t installed! Please type following commands:\n");
        say("\tcd $documentroot");
        say("\tperl Makefile.PL");
        say("\tmake");
        say("\tmake test");
        say("\tmake install");
        say("\tmake clean");
    }

    say("Controller \"$controller\" was successfully added!") if $pcmd eq 'add';
    say("Controller \"$controller\" was successfully deleted!") if $pcmd eq 'del';
    
    1;
}

sub _generalc {
    # Общий для основных обработчиков
    my $c = new CTK ( cfgfile => $CONFFILE || CTK::CFGFILE );
    
    # Секция подготовки отвалидированнх параметров general конфигурации
    my $config = $c->config;
    $config->{general} = {
            configfile => $c->cfgfile,
            logdir     => $c->logdir,
            datadir    => $c->datadir,
            confdir    => $c->confdir,
        };
    
    return $c;
}
sub _result {
    # Процедура возвращает данные в выбранном (по типу) формате
    my $type  = shift || ''; # Тип
    my $rslth = shift || []; # Заголовки (линйный массив)
    my $rsltd = shift || []; # Данные
    
    return '' unless $type;
    return '' if $type =~ /no/i;
    return Dumper($rslth,$rsltd) if $type =~ /dump/i;
    #return Dump($rslth,$rsltd) if $type =~ /ya?ml/i;
    #return XMLout({heders => [{th=>$rslth}], data => [{td => $rsltd}]}, RootName => 'result', NoEscape => 1) if $type =~ /xml/i;;
    
    my %headers = ();
    my @headerc = ();
    my $i = 0;
    # максимумы данных
    foreach (@$rslth) {
        $headerc[$i] = length($_) || 1; # Счетчик
        $headers{$_} = $i; # КЛЮЧ -> [индекс]
        $i++;
    }
    foreach my $row (@$rsltd) {
        $i=0;
        foreach my $col (@$row) {
            $headerc[$i] = length($col) if defined($col) && length($col) > $headerc[$i];
            $i++
        }
    }
        
    # Формирование результата
    my $tbl = Text::SimpleTable->new(map {$_ = [$headerc[$headers{$_}],$_]} @$rslth);
    foreach my $row (@$rsltd) {
        my @tmp = ();
        foreach my $col (@$row) { push @tmp, (defined($col) ? $col : '') }
        $tbl->row(@tmp);
    }
    return $tbl->draw() || '';
}

1;
__END__

sub PROJECT {
    my ($project, $prec, $arg1) = @_;
    unless ($project) {
        ::say("Error: project name missing. Use mpm project <projectname>");
        return 0;
    }
    # Проверка существования проекта
    my $home  = File::Spec->catfile($::PRJTSDIR,$project);
    my $metaf = File::Spec->catfile($::PRJTSDIR,$project,::METAFILE);
    unless ((-e $home) && ((-d $home) || (-l $home)) && (-e $metaf)) {
        ::say("Error: invalid project \"$project\". Use mpm create <projectname> to creating first");
        return 0;
    }
    
    # Детальная проверка META
    ::say("Checking META file...");
    my $meta = YAML::LoadFile($metaf);
    unless ($meta->{ProjectName} && $meta->{ProjectName} eq $project) {
        ::say("Bad META-data in file $metaf. Check project's name registr");
        return 0;
    }
    # Модифицируем GMT в META
    $meta->{GMT} = scalar(gmtime)." GMT";
    
    # Детальная проверка MANIFEST и Index.pm
    ::say("Checking MANIFEST file...");
    my $indexf;
    my $indexk = 'inc/MPM/PROJECTNAME/Index.pm';
    my $foof;
    my $fook   = 'inc/MPM/PROJECTNAME/Foo.pm';
    my $manifest = ::readManifest();
    if ($manifest && $manifest->{$indexk}) {
        ::say("Checking Index file...");
        if ( -e $manifest->{$indexk} ) {
            $indexf = $manifest->{$indexk};
        } else {
            ::say("Can't load file \"$indexf\" from src directory");
            return 0;
        }
        ::say("Checking Foo file...");
        if ( -e $manifest->{$fook} ) {
            $foof = $manifest->{$fook};
        } else {
            ::say("Can't load file \"$foof\" from src directory");
            return 0;
        }
    } else {
        ::say("Can't load MANIFEST file in src-directory");
        return 0;
    }
    ::say("All of checkings passed successfully\n");

    # Выбор операции
    my @operations = qw/
        controlleradd cadd
        controllerlist clist
        controllerdel cdel
        exit
    /;
    my $c = 0;
    my $v = ::selectPrompt(\@operations);
    while ($c < 10) {$c++;
        ::say($v->[1]) if $v->[0];
        $v = ::selectPrompt(\@operations, $prec ? $prec : ::prompt('Your choice:', 'exit'));
        last unless ($v->[0]);
        ::say("   ERROR $c from 10: Bad choice\n");
        $prec = '';
    }
    my $op = $v->[0] ? 'exit' : lc($v->[1]);
    ::say();

    # Операция выбрана
    if ($op =~ /controlleradd|controllerdel|cadd|cdel/ ) {
        # Добавление и Удаление контроллеров
        $c = 0; $v = '';
        my $controller = '';
        my $allowcontrollers = $meta->{Controllers} || [];
        $allowcontrollers = [] if ref($allowcontrollers) ne 'ARRAY';
        ::say("Allowed controllers:\n\t", join("\n\t",@$allowcontrollers), "\n") if @$allowcontrollers;
        while ($c < 5) {$c++;
            $v = $arg1 ? $arg1 : ::prompt('Controller Name:', 'Foo');
            $controller = ::cleanProjectName($v);
            if ($controller ne $v) {
                # Было преобразование
                if (::prompt("  Name \"$controller\" is OK?:", 'yes') !~ /^y/i) {
                    $c = 0; redo;
                }
            }
            if ($op =~ /del/) {
                # Удаление - Должно быть в списке доступных
                last if grep {$_ eq $controller} @$allowcontrollers;
            } else {
                # Добавление - не должно быть в списке доступных
                last unless grep {$_ eq $controller} @$allowcontrollers;
            }
            ::say("   ERROR $c from 5: Invalid Controller Name\n");
        }
        return 0 unless $controller; # Имя должно быть задано
        # Проверка контроллера
        my $foof_dst = File::Spec->catfile($home,'inc','MPM',$project,$controller.".pm");
        if ((-e $foof_dst) && $op =~ /add/) {
            return 0 if ::prompt("Controller \"$controller\" already exists. Overwrite?", 'No') !~ /^y/i;
        }
        ::say("Controller Name: $controller\n");
        
        # Модифкация списка котроллеров
        my @clist = @$allowcontrollers;
        @clist = grep {$_ ne $controller} @clist if $op =~ /del/; # Удаляем
        if ($op =~ /add/) {
            # Добавляем контроллер в список
            push @clist, $controller unless grep {$_ eq $controller} @clist;
            # Запись нового файла контроллера
            my $footpl = new TemplateM(-file=>$foof, -asfile=>1,);
            $footpl->stash(%$meta, ControllerName => $controller);
            #::say($footpl->output());
            file_save($foof_dst,$footpl->output());
            ::say("Controller file \"$foof_dst\" created");
        }

        # Запись META файла
        my %newmeta = %$meta;
        $newmeta{Controllers} = \@clist;
        YAML::DumpFile($metaf,\%newmeta);
        ::say("META file \"$metaf\" modified");
        
        # Запись нового индексного файла 
        my $itpl = new TemplateM(-file=>$indexf, -asfile=>1,);
        $itpl->stash(%$meta);
        my $cbox = $itpl->start('Controllers');
        $cbox->loop(Controller => $_) foreach (grep {$_} @clist);
        $cbox->finish;
        my $indexf_dst = File::Spec->catfile($home,'inc','MPM',$project,'Index.pm');
        file_save($indexf_dst,$itpl->output());
        ::say("Index file \"$indexf_dst\" modified");
        
        # Done
        ::say("Done. Controller \"$controller\" added") if $op =~ /add/;
        ::say("Done. Controller \"$controller\" deleted") if $op =~ /del/;
        ::say("\nPlease restart Apache-server");
    } elsif ($op =~ /controllerlist|clist/ ) {
        # Список доступных контроллеров
        my $allowcontrollers = $meta->{Controllers} || [];
        $allowcontrollers = [] if ref($allowcontrollers) ne 'ARRAY';
        ::say("Controllers list of project \"$project\"");
        if (@$allowcontrollers) {
            ::say("Allowed controllers:\n\t", join("\n\t",@$allowcontrollers), "\n");
        } else {
            ::say("No controllers found");
        }
    } else {
        ::say("Bye");
    }

    return 1;
}


### !!! CONFIGURE взята из проекта-прототипа - monm !!! ###
sub CONFIGURE {
    # Конфигурирование на уровне Makefile. 
    # Производится копирование конфигурационного файла из катаога программы в каталог $DATADIR

    my $overwrite = "Yes";
    $overwrite = $c->cli_prompt('Configuration files already exists. Do you want to overwrite it?:', 'No') if $cfile && -e $cfile;
    $overwrite = $overwrite =~ /^\s*y/i ? 1 : 0;
    
    # Копируем сам файл monm.conf
    copy( $cfile, $cfile.".old") if $cfile && $overwrite && -e $cfile;
    copy( CTK::catfile($EXEDIR,'monm.conf'), $cfile) if $overwrite;
    copy( $CONFFILE, $cfile.".default");
    
    # Копируем все файлы *.conf каталога conf в каталог конфигурации
    $c->fcopy(
            -in     => CTK::catfile($EXEDIR,'conf'),
            -out    => $CONFDIR,
            -file   => qr/\.conf(\.sample$|$)/, 
        ) if $overwrite;
    say;    
    say("Your configuration located in \"",$cmd{sysconfdir}||'',"\" directory");
    say;
    1;
}

1;
