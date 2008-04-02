
use strict;
use warnings;
use Test::More tests => 21;

use Path::Class;
use File::Path;

use Devel::CoverX::Covered::Db;


my $test_dir = dir(qw/ t data cover_db /);

rmtree([$test_dir]);
ok( ! -d $test_dir, "  no cover_db");
mkpath([$test_dir]);
ok( -d $test_dir, "  created cover_db");

END {
    rmtree([$test_dir]);
    ok( ! -d $test_dir, "  Cleaned up ($test_dir)");
}



diag("Create db file");
ok(my $covered_db = Devel::CoverX::Covered::Db->new(dir => $test_dir), "Create DB ok");
ok($covered_db->db, "  and got db object");
ok(-e file($test_dir, "covered", "covered.db"), "  and SQLite db file");

$covered_db->db->query("select count(*) from covered_calling_metric")->into( my $count );
is($count, 0, "  and got empty table");



diag("Connect to existing db file");
ok($covered_db = Devel::CoverX::Covered::Db->new(dir => $test_dir), "Create DB ok");
ok(my $db = $covered_db->db, "  and got db object");

$db->query("select count(*) from covered_calling_metric")->into( $count );
is($count, 0, "  and got empty table");





diag("reset_calling_file");

sub count_rows {
    my ($db) = @_;
    $db->query("select count(*) from covered_calling_metric")->into( my $count );
    return $count;
}

sub insert_dummy_calling_file {
    my ($covered_db, %p) = @_;

    for my $name (qw/ calling_file covered_file /) {
        $p{$name} &&= file( $covered_db->dir, $p{$name} ) . "";
    }

    my %args = (
        metric_type      => "subroutine",
        calling_file     => "",
        covered_file     => "",
        covered_row      => "",
        covered_sub_name => "",
        metric           => 0,
        %p,
    );

    $covered_db->report_metric_coverage(%args);
};

is(count_rows($db), 0, "No rows");
insert_dummy_calling_file($covered_db, calling_file => "a.t", covered_file => "x.pm");
insert_dummy_calling_file(
    $covered_db,
    calling_file     => "b.t",
    covered_file     => "x.pm",
    covered_row      => 10,
    covered_sub_name => "b",
);
insert_dummy_calling_file(
    $covered_db,
    calling_file     => "c.t",
    covered_file     => "x.pm",
    covered_row      => 20,
    covered_sub_name => "c",
);
is(count_rows($db), 3, "Fixture rows");
is_deeply(
    [ $covered_db->covered_files() ],
    [ file(qw/ t data cover_db x.pm /) . "" ],
    "source_files found one file",
);
is_deeply(
    [ $covered_db->test_files() ],
    [ sort ( map { file(qw/ t data cover_db /, "$_.t") . "" } qw/ a b c / )  ],
    "test_files found three files",
);


ok($covered_db->reset_calling_file(file(qw/ t data cover_db a.t /)), "reset_calling_file a.t");
is(count_rows($db), 2, "One less row");





diag("test_files_covering, source_files_covered_by");
is_deeply(
    [ $covered_db->test_files_covering(file(qw/ t data cover_db x.pm /) . "") ],
    [],
    "test_files_covering with subroutine metric 0 finds nothing",
);



insert_dummy_calling_file(
    $covered_db,
    calling_file     => "c.t",
    covered_file     => "x.pm",
    covered_row      => 20,
    covered_sub_name => "c",
    metric           => 1,
);
insert_dummy_calling_file(
    $covered_db,
    calling_file     => "c.t",
    covered_file     => "x.pm",
    covered_row      => 30,
    covered_sub_name => "a",
    metric           => 1,
);
is_deeply(
    [ $covered_db->test_files_covering(file(qw/ t data cover_db x.pm /) . "") ],
    [ file(qw/ t data cover_db c.t /) . "" ],
    "test_files_covering with two subroutine metric 1 finds the correct test file",
);


is_deeply(
    [ $covered_db->source_files_covered_by(file(qw/ t data cover_db c.t /) . "") ],
    [ file(qw/ t data cover_db x.pm /) . "" ],
    "source_files_covered_by finds the correct source file",
);



insert_dummy_calling_file(
    $covered_db,
    calling_file     => "a.t",
    covered_file     => "x.pm",
    covered_row      => 30,
    covered_sub_name => "a",
    metric           => 1,
);
is_deeply(
    [ sort $covered_db->test_files_covering(file(qw/ t data cover_db x.pm /) . "") ],
    [ file(qw/ t data cover_db a.t /) . "", file(qw/ t data cover_db c.t /) . "" ],
    "test_files_covering with two subroutine metric 1 finds the correct test files",
);

is_deeply(
    [ $covered_db->source_files_covered_by(file(qw/ t data cover_db c.t /) . "") ],
    [ file(qw/ t data cover_db x.pm /) . "" ],
    "source_files_covered_by finds the correct source file",
);






__END__
