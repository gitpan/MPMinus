#!/usr/bin/perl -w
use strict;
use ExtUtils::MakeMaker;

our $MSWIN = $^O =~ /mswin/i ? 1 : 0;

my $build_requires = {
        'ExtUtils::MakeMaker'   => 6.60,
        'Test::More'            => 0.94,
       #'Test::Pod::Coverage'   => 1.08,
    };

my $prereq_pm = {
        'mod_perl2'             => 2.00,
        'CGI'                   => 3.00,
        'CTK'                   => 1.12,
        'TemplateM'             => 3.02,
        'Apache::DBI'           => 1.11,
    };

use vars qw/$exefiles/;
$exefiles = [qw(
        bin/mpm
    )];
push @$exefiles, (qw(bin/pv.exe)) if $MSWIN;

WriteMakefile(
    'NAME'                  => 'MPMinus',
    'DISTNAME'              => 'MPMinus',
    'MIN_PERL_VERSION'      => 5.008001,
    'VERSION_FROM'          => 'lib/MPMinus.pm', 
    'ABSTRACT_FROM'         => 'lib/MPMinus.pm',
    'BUILD_REQUIRES'        => $build_requires,
    'PREREQ_PM'             => $prereq_pm,
    'EXE_FILES'             => $exefiles,
    'AUTHOR'                => 'Lepenkov Sergey (Serz Minus) <minus@mail333.com>',
    'LICENSE'               => 'gpl',
    'META_MERGE' => {
        recommends => {
            'DBI'           => 0,
            'Data::Dumper'  => 0,
        },
        resources => {
            homepage        => 'http://www.serzik.ru',
            repository      => 'http://svn.serzik.ru/MPMinus/trunk',
            license         => 'http://opensource.org/licenses/gpl-license.php',
        },
    },
);


1;

__END__

package MY;
use CTK::Util qw/dformat/;

sub postamble {
my $section = <<'MAKE_FRAG';
.PHONY: build configure

pure_all :: build
	$(NOECHO) $(NOOP)

build : $(FIRST_MAKEFILE) $(INST_SCRIPT)$(DFSEP).exists\
        $(INST_SCRIPT)$(DFSEP).configured $(INST_SCRIPT)$(DFSEP).builded
	$(NOECHO) $(NOOP)

$(INST_SCRIPT)$(DFSEP).builded : [PLS]
	$(NOECHO) $(ECHO) "Scripts building..."
[BLD]
	$(NOECHO) $(TOUCH) $(INST_SCRIPT)$(DFSEP).builded

configure : monm.conf
	$(NOECHO) $(ECHO) "(Force) Configuration..."
	$(ABSPERLRUN) -Ilib monm.pl configure
	$(NOECHO) $(TOUCH) $(INST_SCRIPT)$(DFSEP).configured

$(INST_SCRIPT)$(DFSEP).configured : monm.conf
	$(NOECHO) $(ECHO) "Configuration..."
	$(ABSPERLRUN) -Ilib monm.pl configure
	$(NOECHO) $(TOUCH) $(INST_SCRIPT)$(DFSEP).configured

pure_install :: build
	-$(RM_F) $(DESTINSTALLSITESCRIPT)$(DFSEP).configured $(DEV_NULL)
	-$(RM_F) $(DESTINSTALLSITESCRIPT)$(DFSEP).builded $(DEV_NULL)

clean :: Makefile.PL
	-$(RM_F) $(MAKEFILE_OLD)

MAKE_FRAG
my $rptbld = <<'BLD';
	$(NOECHO) $(RM_F) $(INST_SCRIPT)$(DFSEP)[BNS]
	$(CP) [BNS].pl $(INST_SCRIPT)$(DFSEP)[BNS]
	$(FIXIN) $(INST_SCRIPT)$(DFSEP)[BNS]
	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_SCRIPT)$(DFSEP)[BNS]
BLD
my @srs = @$::exefiles;
my @bns = @srs;
@bns = map {$_ =~ s/^.*?\///; $_} @bns;
my @pls = @bns;
@pls = map {$_.".pl"} grep {$_} @pls;
#print join "\n", @pls;
my $bld = '';
$bld .= dformat($rptbld, {BNS => $_}) for (@bns);
return dformat($section,{
        PLS => join(" ", @pls),
        BLD => $bld,
    });
}

1;
