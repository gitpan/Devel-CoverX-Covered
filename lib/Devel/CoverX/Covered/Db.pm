
=head1 NAME

Devel::CoverX::Covered::Db - Covered database collection and reporting



=head1 DESCRIPTION


=head2 Error handling model

Failures will result in a die.

=cut

use strict;
package Devel::CoverX::Covered::Db;
use Moose;

use Devel::Cover::DB;

use Data::Dumper;
use DBIx::Simple;
use DBD::SQLite;
use File::Path;
use File::chdir;
use Path::Class;



=head1 PROPERTIES

=head2 dir

The directory for the cover_db.

=cut
has 'dir' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    default => sub { dir("./cover_db")->absolute },
);




=head2 db

DBIx::Simple $db object. Created lazily under "dir".

=cut
has 'db' => (
    is => 'ro',
    isa => 'DBIx::Simple',
    lazy => 1,
    default => sub { $_[0]->connect_to_db },
);



=head1 METHODS

=head2 connect_to_db() : DBIx::Simple $db

Connect to the covered db and return the new DBIx::Simple object.

If there is no db at all, create it first.

=cut
sub connect_to_db {
    my $self = shift;

    my $db_file = file($self->dir, "covered", "covered.db");

    -r $db_file or return $self->create_db($db_file);

    my $db = DBIx::Simple->connect("dbi:SQLite:dbname=$db_file", "", "", {RaiseError => 1});

    return $db;
}



=head2 create_db($db_file) : DBIx::Simple $db

Create $db_file with the correct schema.

Return newly created DBIx::Simple $db object.

=cut
sub create_db {
    my $self = shift;
    my ($db_file) = @_;

    #Refactor: extract method: ensure_dir_of_file
    my $db_dir = $db_file->dir;
    mkpath([ $db_dir ]);
    -e $db_dir or die("Could not create covered db dir ($db_dir)\n");

    my $db = DBIx::Simple->connect("dbi:SQLite:dbname=$db_file", "", "", { RaiseError => 1 });

    my @ddl_tables = (
        q{
            CREATE TABLE covered_calling_metric (
                covered_calling_metric_id INTEGER PRIMARY KEY,

                calling_file       VARCHAR NOT NULL,
                covered_file       VARCHAR NOT NULL,
                covered_row        INTEGER NOT NULL,
                covered_sub_name   VARCHAR NOT NULL,
                metric_type        VARCHAR NOT NULL,
                metric             INTEGER NOT NULL
            )
        },
        q{
            CREATE INDEX covered_calling_metric_covered_metric_row ON covered_calling_metric (
                covered_file,
                metric,
                covered_row
            )
        },
        q{
            CREATE INDEX covered_calling_metric_calling ON covered_calling_metric (calling_file)
        },
    );

    for my $ddl (@ddl_tables) {
#        print "DDL: $ddl\n";
        $db->query($ddl) or die("Could not run DDL ($ddl): " . $db->error . "\n");
    }

    return $db;
}



=head2 in_transaction($subref) : $ret

Run $subref->() in a transaction and return the return value of
$subref in scalar context.

If anything dies inside $subref, roll back and rethrow exception.

=cut
sub in_transaction {
    my $self = shift;
    my ($subref) = @_;

    my $db = $self->db;

    $db->begin();
    my $ret = eval { $subref->() };
    if(my $err = $@) {
        $db->rollback();
        die $err;
    }
    else {
        $db->commit();
    }

    return $ret;
}



=head2 collect_runs() : 1

Collect coverage statistics for test runs in "dir".

=cut
sub collect_runs {
    my $self = shift;

    $self->in_transaction( sub {
        local $CWD = $self->dir->parent;
        for my $run_db_dir ($self->get_run_dirs()) {
            my $cover_db = Devel::Cover::DB->new(db => $self->dir);

            my $run_db_file = "$run_db_dir/cover.12";  #Eeh, refactor
            -e $run_db_file or warn("No run db ($run_db_file)\n"), next;
            $cover_db->read($run_db_file);

            $self->collect_run($cover_db);
        }
    });

    return 1;
}




=head2 get_run_dirs() : @dirs

Return list of directories for test runs under the "dir".

=cut
sub get_run_dirs {
    my $self = shift;
    return grep { -d $_ } grep { /\d$/ } sort glob($self->dir . "/runs/*");
}



=head2 collect_run($cover_db) : 1

Collect coverage statistics for the test run Devel::Cover::DB
$cover_db.

Don't collect coverage for eval (-e).

=cut
sub collect_run {
    my $self = shift;
    my ($cover_db) = @_;

    my @runs = $cover_db->runs;
    @runs > 1 and warn("More than one run in run cover db\n"), return 0;
    my $calling_file_name = $runs[0]->run;
    $calling_file_name eq "-e" and return 0;

    $self->reset_calling_file($calling_file_name);

    my @source_file_names = $cover_db->cover->items;
    for my $source_file_name (@source_file_names) {
        my $file_data = $cover_db->cover->file($source_file_name);

        for my $metric_type ("statement", "subroutine" ) { #time, branch
            my $row_metric = $file_data->$metric_type or next;

            for my $row (keys %$row_metric) {
                my $row_locations = $row_metric->{$row} or next;
                my $row_location = $row_locations->[0] or next;

                my $sub_name = "";
                if($row_location->can("name")) {
#print Dumper($row_location);                    
                    $sub_name = $row_location->name;
                    $sub_name eq "BEGIN" and next;
                    $sub_name eq "__ANON__" and next;
                }
                
                my $is_covered = $row_location->covered;

                $self->report_metric_coverage(
                    metric_type      => $metric_type,
                    calling_file     => $calling_file_name,
                    covered_file     => $source_file_name,
                    covered_row      => $row,
                    covered_sub_name => $sub_name,
                    metric           => $is_covered,
                );
            }
        }
    }

    return 1;
}




=head2 reset_calling_file($calling_file_name) : 1

Clear out the stored data related to $calling_file_name.

=cut
sub reset_calling_file {
    my $self = shift;
    my ($calling_file_name) = @_;

    $self->db->delete("covered_calling_metric", { calling_file => $calling_file_name });

    return 1;
}



=head2 report_metric_coverage(metric_type, calling_file, covered_file, covered_row, covered_sub_name, metric) : 1

Report the coverage metric defined by the parameters.

Make all file paths relative to "dir" if possible.

=cut
sub report_metric_coverage {
    my $self = shift;
    my (%p) = @_;

    $p{$_} = $self->relative_file($p{$_}) . "" for (qw/ calling_file covered_file /);
#print Dumper(\%p);
    $self->db->insert("covered_calling_metric", \%p);

    return 1;
}



=head2 test_files_covering($source_file_name) : @test_file_names

Return list of test files that cover any line in $source_file_name.

=cut
sub test_files_covering {
    my $self = shift;
    my ($calling_file_name) = @_;

    #This needs to be sub coverage, so a "use" doesn't execute
    #statements e.g. "use strict;".
    my @test_files = $self->db->query(
        q{
        SELECT DISTINCT(calling_file)
            FROM covered_calling_metric
            WHERE
                    covered_file = ?
                AND metric_type = "subroutine"
                AND metric > 0
            ORDER by calling_file
        },
        $calling_file_name,
    )->flat;

    return @test_files;
}



=head2 relative_file($file) : Path::Class::File $relative_file

Return $file relative to cover_db/.. if possible, otherwise just
return $file.

=cut
sub relative_file {
    my $self = shift;
    my ($file) = @_;
    $file = file($file);
    $file->is_absolute or return $file;
    return $file->relative( $self->dir->parent );
}



1;



__END__
