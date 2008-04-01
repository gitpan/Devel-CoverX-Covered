
=head1 NAME

Devel::CoverX::Covered - Collecting and report caller and covered
statistics from the cover_db



=head1 DESCRIPTION

=head2 Dealing with large code bases and large test suites

When a test suite grows as a team of developers implement new
features, knowing exactly which test files provide test coverage for
which parts of the application becomes less and less obvious.

This is especially true for tests on the acceptance / integration /
system level (rather than on the unit level where the focus of tests
is often more focused and easily deduced).

This is also extra obvious for developers new to the code base who
have no clue what types of code may need extra testing, or about
common idioms for testing certain parts of the application.



=head2 Enter Devel::CoverX::Covered

This module extracts and stores the relationship between covering test
files and covered source files.

This makes it possible to

=over 4

=item *

Given a source file, list the test files that provide coverage to that
source file. This can be done on a file, sub routine and row level.

=item *

Given a test file, list the source files and subs covered by that test
file.


=item *

Given a source file, report efficiently on the coverage details per
row, or sub.



=head2 Usage Scenarios

Using this module it shoud be possible to implement e.g.

=over 4

=item *

From within the editor, list or open interesting source / test files,
depending on the editor context (current file, sub, line).


=item *

When a source file is saved or changed on disk, look up which tests
correspond to that source file and run only those, thereby providing a
quicker feedback loop than running the entire test suite.

=back


=head2 Development Status

This is a first release with limited funcionality.



=head1 SYNOPSIS

=head2 Nightly / automatic run

  #Clean up from previous test run
  cover -delete

  #Test run with coverage instrumentation
  PERL5OPT=-MDevel::Cover prove -r t

  #Collect covered and caller information
  #  Don't run with Devel::Covered enabled
  covered runs

  #Post process to generate covered database
  cover -report Covered


=head2 During development

  #Query the covered database per source file
  covered covering --source_file=lib/MyApp/DoStuff.pm
  t/myapp-do_stuff.t
  t/myapp-do_stuff/edge_case1.t
  t/myapp-do_stuff/edge_case2.t

-- not implemented --

  #Query the covered database per source file and row
  covered covering --source_file=lib/MyApp/DoStuff.pm --row=37
  t/myapp-do_stuff/edge_case1.t

  covered covering --source_file=lib/MyApp/DoStuff.pm --row=142
  t/myapp-do_stuff.t
  t/myapp-do_stuff/edge_case2.t

  #Query the covered database per source file and subroutine
  covered covering --source_file=lib/MyApp/DoStuff.pm --sub=as_xml
  t/myapp-do_stuff.t


  #Query the covered database per test file
  covered by --test_file=t/myapp-do_stuff.t
  lib/MyApp/DoStuff.pm
  lib/MyApp/DoStuff/DoOtherStuff.pm


  #Query the covered database for details of a source file
  covered lines --test_file=lib/MyApp/DoStuff.pm --metric=statement
  11, 1
  17, 0
  26, 0
  32, 1
  77, 3
  80, 1
  99, 2
  102, 2
  104, 1

=cut

use strict;
package Devel::CoverX::Covered;
our $VERSION = 0.001;



1;



__END__
