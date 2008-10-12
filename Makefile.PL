use 5.008005;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Class::DBI::Lite',
    VERSION_FROM      => 'lib/Class/DBI/Lite.pm', # finds $VERSION
    PREREQ_PM         => {
      Test::More                => 0,
      Test::Memory::Cycle       => 0,
      DBIx::ContextualFetch     => 0,
      DBI                       => 0,
      DBD::SQLite               => 0,
      Ima::DBI                  => 0,
      DBIx::ContextualFetch     => 0,
      SQL::Abstract             => 0,
      SQL::Abstract::Limit      => 0,
    },
    dist => {
      PREOP => 'pod2text lib/Class/DBI/Lite.pm > $(DISTVNAME)/README',
    },
    (
      $] >= 5.005 ?     ## Add these new keywords supported since 5.005
        (
          ABSTRACT_FROM  => 'lib/Class/DBI/Lite.pm', # retrieve abstract from module
          AUTHOR         => 'John Drago <jdrago_999@yahoo.com>'
        ) : ()
    ),
);

