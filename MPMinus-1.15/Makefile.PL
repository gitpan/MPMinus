#!/usr/bin/perl -w
use strict;
use ExtUtils::MakeMaker;
use File::Spec::Functions qw/catfile/;

our $MSWIN = $^O =~ /mswin/i ? 1 : 0;

my $build_requires = {
        'ExtUtils::MakeMaker'   => 6.60,
        'Test::More'            => 0.94,
    };

my $prereq_pm = {
        'mod_perl2'             => 2.00,
        'Apache::DBI'           => 1.11,
        'Archive::Extract'      => 0.60,
        'CGI'                   => 3.60,
        'CTK'                   => 1.12,
        'Digest'                => 1.16,
        'ExtUtils::Manifest'    => 1.58,
        'File::Copy::Recursive' => 0.38,
        'File::Temp'            => 0.22,
        'TemplateM'             => 3.02,
        'Text::SimpleTable'     => 2.03,
    };

use vars qw/$exefiles/;
$exefiles = [
        catfile(qw/bin mpm/),
    ];

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

package MY;

sub postamble {
my $section = <<'MAKE_FRAG';
.PHONY: skel

SKELSRC = skel
SKELNAME = mpminus-skel
SKELVNAME = mpminus-skel-$(VERSION)

skel : src$(DFSEP)$(SKELVNAME).tar.gz
	$(NOECHO) $(NOOP)

src$(DFSEP)$(SKELVNAME).tar.gz :
	$(PREOP)
	$(TO_UNIX)
	cd src && $(TAR) $(TARFLAGS) $(SKELNAME).tar $(SKELSRC)
	$(COMPRESS) src$(DFSEP)$(SKELNAME).tar
	$(CP) src$(DFSEP)$(SKELNAME).tar.gz src$(DFSEP)$(SKELVNAME).tar.gz
	-md5sum src$(DFSEP)$(SKELVNAME).tar.gz > src$(DFSEP)$(SKELVNAME).md5
	-sha1sum src$(DFSEP)$(SKELVNAME).tar.gz > src$(DFSEP)$(SKELVNAME).sha1
	$(POSTOP)

MAKE_FRAG
return $section;
}

1;
