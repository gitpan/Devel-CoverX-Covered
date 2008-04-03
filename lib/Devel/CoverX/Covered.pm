
=head1 NAME

Devel::CoverX::Covered - Collect and report caller (test file) and
covered (source file) statistics from the cover_db



=head1 DESCRIPTION

=head2 Dealing with large code bases and large test suites

When a test suite grows as a team of developers implement new
features, knowing exactly which test files provide test coverage for
which parts of the application becomes less and less obvious.

This is especially true for tests on the acceptance / integration /
system level (rather than on the unit level where the tests are more
focused and easily deduced).

This is also extra obvious for developers new to the code base who
have no clue what types of code may need extra testing, or about
common idioms for testing certain parts of the application.



=head2 Enter Devel::CoverX::Covered

Devel::CoverX::Covered extracts and stores the relationship between
covering test files and covered source files.

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

Using this module it should be possible to implement e.g.

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
  #  Run this _before_ running "cover"
  #  Don't run with Devel::Covered enabled
  covered runs

  #Post process to generate covered database
  cover -report Html_basic


=head2 During development

  #Query the covered database per source file
  covered covering --source_file=lib/MyApp/DoStuff.pm
  t/myapp-do_stuff.t
  t/myapp-do_stuff/edge_case1.t
  t/myapp-do_stuff/edge_case2.t


  #Query the covered database per test file
  covered by --test_file=t/myapp-do_stuff.t
  lib/MyApp/DoStuff.pm
  lib/MyApp/DoStuff/DoOtherStuff.pm


  #List all known files
  covered info

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


  #Query the covered database per test file, but also show covered
  #subroutines (\t separated)
  covered subs_by --test_file=t/myapp-do_stuff.t
  lib/MyApp/DoStuff.pm       as_xml
  lib/MyApp/DoStuff.pm       do_stuff
  lib/MyApp/DoStuff.pm       new
  lib/MyApp/DoStuff/DoOtherStuff.pm   new
  lib/MyApp/DoStuff/DoOtherStuff.pm   do_other_stuff


  #Query the covered database for details of a source file
  covered lines --test_file=lib/MyApp/DoStuff.pm --metric=statement
  11\t1
  17\t0
  26\t0
  32\t1
  77\t3
  80\t1
  99\t2
  102\t2
  104\t1


=head1 EDITOR SUPPORT

=head2 Emacs

L<Devel::PerlySense> has a feature "Go to Tests - Other Files" for
navigating to related files.


=head2 Vim

Ovid provides a few simple but conveinent key bindings here:
L<http://use.perl.org/~Ovid/journal/36030>.


=cut

use strict;
package Devel::CoverX::Covered;
our $VERSION = 0.005;



1;



__END__

=head1 SEE ALSO

L<Devel::Cover>



=head1 AUTHOR

Johan Lindström, C<< <johanl[ÄT]DarSerMan.com> >>



=head1 BUGS AND CAVEATS

=head2 BUG REPORTS

Please report any bugs or feature requests to
C<bug-devel-coverx-covered@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Devel-CoverX-Covered>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head2 CAVEATS


=head2 KNOWN BUGS

Well, this is more of a cop out really...

Since the covered database file is stuffed into the cover_db
directory, Devel::Cover's "cover" program will report the Cover
database as invalid when in fact it works perfectly well.



=head1 COPYRIGHT & LICENSE

Copyright 2007 Johan Lindström, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
