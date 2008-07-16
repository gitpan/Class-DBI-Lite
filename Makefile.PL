use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Class::DBI::Lite',
    VERSION_FROM      => 'lib/Class/DBI/Lite.pm', # finds $VERSION
    PREREQ_PM         => {
      DBI => 0,
      DBD::SQLite => 0,
      Class::Data::Inheritable => 0,
      Test::More => 0,
      SQL::Abstract => 0,
      SQL::Abstract::Limit => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Class/DBI/Lite.pm', # retrieve abstract from module
       AUTHOR         => 'John Drago <jdrago_999@yahoo.com>') : ()),
);
