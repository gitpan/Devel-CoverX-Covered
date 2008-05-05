
use strict;
use warnings;
use Test::More tests => 32;
use Test::Exception;

use Data::Dumper;
use Path::Class;
use File::Path;



use lib "lib";

use Devel::CoverX::Covered::Db;
use Devel::CoverX::Covered;


my $test_dir = dir(qw/ t data cover_db /);
my $covered_dir = dir($test_dir->parent, "covered");

rmtree([ $test_dir, $covered_dir ]);
ok( ! -d $test_dir, "  no cover_db");
ok( ! -d $covered_dir, "  no covered");
mkpath([ $test_dir, $covered_dir ]);
ok( -d $test_dir, "  created cover_db");
ok( -d $covered_dir, "  created covered_db");

END {
    rmtree([ $test_dir, $covered_dir ]);
    ok( ! -d $test_dir, "  Cleaned up ($test_dir)");
    ok( ! -d $covered_dir, "  Cleaned up ($covered_dir)");
}



diag("Create db file");
lives_ok(
    sub { Devel::CoverX::Covered::Db->new() },
    "Create DB ok with no params ok",
);

my $count;

ok(my $covered_db = Devel::CoverX::Covered::Db->new(dir => $test_dir), "Create DB ok");
ok($covered_db->db, "  and got db object");
is(
    scalar @{[ glob( file($test_dir->parent, "covered") . "/*.db") ]},
    1,
    "  and SQLite db file",
);

$covered_db->db->query("select count(*) from covered_calling_metric")->into( $count );
is($count, 0, "  and got empty table");

$covered_db->db->query("select count(*) from file")->into( $count );
is($count, 0, "  and got empty table");




diag("Connect to existing db file");
ok($covered_db = Devel::CoverX::Covered::Db->new(dir => $test_dir), "Create DB ok");
ok(my $db = $covered_db->db, "  and got db object");

$db->query("select count(*) from covered_calling_metric")->into( $count );
is($count, 0, "  and got empty table");





diag("reset_calling_file");

sub count_rows {
    my ($db, $table) = @_;
    $table ||= "covered_calling_metric";
    $db->query("select count(*) from $table")->into( my $count );
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
insert_dummy_calling_file(
    $covered_db,
    calling_file => "a.t",
    covered_file => "x.pm",
);
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



is(count_rows($db), 2, "  Fixture rows");
is(count_rows($db, "file"), 4, "  Fixture file rows");
insert_dummy_calling_file(
    $covered_db,
    calling_file     => "c.t",
    covered_file     => "x.pm",
    covered_row      => 20,
    covered_sub_name => "c",
    metric           => 1,
);
is(count_rows($db), 3, "  Fixture rows");
is(count_rows($db, "file"), 4, "  Fixture file rows");
insert_dummy_calling_file(
    $covered_db,
    calling_file     => "c.t",
    covered_file     => "x.pm",
    covered_row      => 30,
    covered_sub_name => "a",
    metric           => 1,
);
is(count_rows($db), 4, "  Fixture rows");
is(count_rows($db, "file"), 4, "  Fixture file rows");
is_deeply(
    [ $covered_db->test_files_covering(file($covered_db->dir, "x.pm") . "") ],
    [ file(qw/ t data cover_db c.t /) . "" ],
    "test_files_covering with two subroutine metric 1 finds the correct test file",
) or die(Dumper([ $covered_db->test_files_covering(file(qw/ t data cover_db x.pm /) . "") ]));


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
