use strict;
use warnings;

use FindBin;
$ENV{DBIX_CUSTOM_TEST_RUN} = 1;

use DBIx::Custom;
{
    package DBIx::Custom;
    no warnings 'redefine';
    has dsn => 'dbi:SQLite:dbname=:memory:';
    sub quote { '""' }
    sub create_table1 { 'create table table1 (key1, key2);' }
    sub create_table1_2 {'create table table1 (key1, key2, key3, key4, key5);' }
    sub create_table2 { 'create table table2 (key1, key3);' }
    sub create_table_reserved { 'create table "table" ("select", "update")' }
}

require "$FindBin::Bin/common.t";
