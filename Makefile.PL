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
);
