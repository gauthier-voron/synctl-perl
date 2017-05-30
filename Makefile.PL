use 5.022001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Synctl',
    VERSION_FROM      => 'lib/Synctl.pm',
    PREREQ_PM         => {},
    ABSTRACT_FROM     => 'lib/Synctl.pm',
    EXE_FILES         => [ 'script/synctl' , 'script/synconvert' ],
    AUTHOR            => 'Gauthier Voron <gauthier@mnesic.fr>',
    LICENSE           => 'gpl',
    MAN1PODS          => {
        'doc/synctl-fsck.pod'  => 'blib/man1/synctl-fsck.1',
        'doc/synctl-help.pod'  => 'blib/man1/synctl-help.1',
        'doc/synctl-init.pod'  => 'blib/man1/synctl-init.1',
        'doc/synctl-list.pod'  => 'blib/man1/synctl-list.1',
        'doc/synctl-recv.pod'  => 'blib/man1/synctl-recv.1',
        'doc/synctl-rm.pod'    => 'blib/man1/synctl-rm.1',
        'doc/synctl-send.pod'  => 'blib/man1/synctl-send.1',
        'doc/synctl-serve.pod' => 'blib/man1/synctl-serve.1',
    }
);
