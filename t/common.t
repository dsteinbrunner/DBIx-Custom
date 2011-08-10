use Test::More;
use strict;
use warnings;
use DBIx::Custom;
use Encode qw/encode_utf8/;

my $dbi;

plan skip_all => $ENV{DBIX_CUSTOM_SKIP_MESSAGE} || 'common.t is always skipped'
  unless $ENV{DBIX_CUSTOM_TEST_RUN}
    && eval { $dbi = DBIx::Custom->connect; 1 };

plan 'no_plan';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /DEPRECATED/};
sub test { print "# $_[0]\n" }

# Constant
my $create_table1 = $dbi->create_table1;
my $create_table1_2 = $dbi->create_table1_2;
my $create_table2 = $dbi->create_table2;
my $create_table_reserved = $dbi->create_table_reserved;
my $q = substr($dbi->quote, 0, 1);
my $p = substr($dbi->quote, 1, 1) || $q;

# Variable
# Variables
my $builder;
my $datas;
my $sth;
my $source;
my @sources;
my $select_source;
my $insert_source;
my $update_source;
my $param;
my $params;
my $sql;
my $result;
my $row;
my @rows;
my $rows;
my $query;
my @queries;
my $select_query;
my $insert_query;
my $update_query;
my $ret_val;
my $infos;
my $model;
my $model2;
my $where;
my $update_param;
my $insert_param;
my $join;
my $binary;

# Drop table
eval { $dbi->execute('drop table table1') };

# Create table
$dbi->execute($create_table1);
$model = $dbi->create_model(table => 'table1');
$model->insert({key1 => 1, key2 => 2});
is_deeply($model->select->all, [{key1 => 1, key2 => 2}]);

test 'DBIx::Custom::Result test';
$dbi->delete_all(table => 'table1');
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$source = "select key1, key2 from table1";
$query = $dbi->create_query($source);
$result = $dbi->execute($query);

@rows = ();
while (my $row = $result->fetch) {
    push @rows, [@$row];
}
is_deeply(\@rows, [[1, 2], [3, 4]], "fetch");

$result = $dbi->execute($query);
@rows = ();
while (my $row = $result->fetch_hash) {
    push @rows, {%$row};
}
is_deeply(\@rows, [{key1 => 1, key2 => 2}, {key1 => 3, key2 => 4}], "fetch_hash");

$result = $dbi->execute($query);
$rows = $result->fetch_all;
is_deeply($rows, [[1, 2], [3, 4]], "fetch_all");

$result = $dbi->execute($query);
$rows = $result->fetch_hash_all;
is_deeply($rows, [{key1 => 1, key2 => 2}, {key1 => 3, key2 => 4}], "all");

test 'Insert query return value';
$source = "insert into table1 {insert_param key1 key2}";
$query = $dbi->execute($source, {}, query => 1);
$ret_val = $dbi->execute($query, param => {key1 => 1, key2 => 2});
ok($ret_val);

test 'Direct query';
$dbi->delete_all(table => 'table1');
$insert_source = "insert into table1 {insert_param key1 key2}";
$dbi->execute($insert_source, param => {key1 => 1, key2 => 2});
$result = $dbi->execute('select * from table1;');
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2}]);

test 'Filter basic';
$dbi->delete_all(table => 'table1');
$dbi->register_filter(twice       => sub { $_[0] * 2}, 
                    three_times => sub { $_[0] * 3});

$insert_source  = "insert into table1 {insert_param key1 key2};";
$insert_query = $dbi->execute($insert_source, {}, query => 1);
$insert_query->filter({key1 => 'twice'});
$dbi->execute($insert_query, param => {key1 => 1, key2 => 2});
$result = $dbi->execute('select * from table1;');
$rows = $result->filter({key2 => 'three_times'})->all;
is_deeply($rows, [{key1 => 2, key2 => 6}], "filter fetch_filter");

test 'Filter in';
$dbi->delete_all(table => 'table1');
$insert_source  = "insert into table1 {insert_param key1 key2};";
$insert_query = $dbi->execute($insert_source, {}, query => 1);
$dbi->execute($insert_query, param => {key1 => 2, key2 => 4});
$select_source = "select * from table1 where {in table1.key1 2} and {in table1.key2 2}";
$select_query = $dbi->execute($select_source,{}, query => 1);
$select_query->filter({'table1.key1' => 'twice'});
$result = $dbi->execute($select_query, param => {'table1.key1' => [1,5], 'table1.key2' => [2,4]});
$rows = $result->all;
is_deeply($rows, [{key1 => 2, key2 => 4}], "filter");

test 'DBIx::Custom::SQLTemplate basic tag';
$dbi->execute('drop table table1');
$dbi->execute($create_table1_2);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->insert(table => 'table1', param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});

$source = "select * from table1 where key1 = :key1 and {<> key2} and {< key3} and {> key4} and {>= key5};";
$query = $dbi->execute($source, {}, query => 1);
$result = $dbi->execute($query, param => {key1 => 1, key2 => 3, key3 => 4, key4 => 3, key5 => 5});
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5}], "basic tag1");

$source = "select * from table1 where key1 = :key1 and {<> key2} and {< key3} and {> key4} and {>= key5};";
$query = $dbi->execute($source, {}, query => 1);
$result = $dbi->execute($query, {key1 => 1, key2 => 3, key3 => 4, key4 => 3, key5 => 5});
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5}], "basic tag1");

$source = "select * from table1 where {<= key1} and {like key2};";
$query = $dbi->execute($source, {}, query => 1);
$result = $dbi->execute($query, param => {key1 => 1, key2 => '%2%'});
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5}], "basic tag2");

test 'DIB::Custom::SQLTemplate in tag';
$dbi->execute('drop table table1');
$dbi->execute($create_table1_2);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->insert(table => 'table1', param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});

$source = "select * from table1 where {in key1 2};";
$query = $dbi->execute($source, {}, query => 1);
$result = $dbi->execute($query, param => {key1 => [9, 1]});
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5}], "basic");

test 'DBIx::Custom::SQLTemplate insert tag';
$dbi->delete_all(table => 'table1');
$insert_source = 'insert into table1 {insert_param key1 key2 key3 key4 key5}';
$dbi->execute($insert_source, param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});

$result = $dbi->execute('select * from table1;');
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5}], "basic");

test 'DBIx::Custom::SQLTemplate update tag';
$dbi->delete_all(table => 'table1');
$insert_source = "insert into table1 {insert_param key1 key2 key3 key4 key5}";
$dbi->execute($insert_source, param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->execute($insert_source, param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});

$update_source = 'update table1 {update_param key1 key2 key3 key4} where {= key5}';
$dbi->execute($update_source, param => {key1 => 1, key2 => 1, key3 => 1, key4 => 1, key5 => 5});

$result = $dbi->execute('select * from table1 order by key1;');
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 1, key3 => 1, key4 => 1, key5 => 5},
                  {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10}], "basic");

test 'Named placeholder';
$dbi->execute('drop table table1');
$dbi->execute($create_table1_2);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->insert(table => 'table1', param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});

$source = "select * from table1 where key1 = :key1 and key2 = :key2";
$result = $dbi->execute($source, param => {key1 => 1, key2 => 2});
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5}]);

$source = "select * from table1 where key1 = \n:key1\n and key2 = :key2";
$result = $dbi->execute($source, param => {key1 => 1, key2 => 2});
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5}]);

$source = "select * from table1 where key1 = :key1 or key1 = :key1";
$result = $dbi->execute($source, param => {key1 => [1, 2]});
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5}]);

$source = "select * from table1 where key1 = :table1.key1 and key2 = :table1.key2";
$result = $dbi->execute(
    $source,
    param => {'table1.key1' => 1, 'table1.key2' => 1},
    filter => {'table1.key2' => sub { $_[0] * 2 }}
);
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5}]);

$dbi->execute('drop table table1');
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => '2011-10-14 12:19:18', key2 => 2});
$source = "select * from table1 where key1 = '2011-10-14 12:19:18' and key2 = :key2";
$result = $dbi->execute(
    $source,
    param => {'key2' => 2},
);

$rows = $result->all;
is_deeply($rows, [{key1 => '2011-10-14 12:19:18', key2 => 2}]);

$dbi->delete_all(table => 'table1');
$dbi->insert(table => 'table1', param => {key1 => 'a:b c:d', key2 => 2});
$source = "select * from table1 where key1 = 'a\\:b c\\:d' and key2 = :key2";
$result = $dbi->execute(
    $source,
    param => {'key2' => 2},
);
$rows = $result->all;
is_deeply($rows, [{key1 => 'a:b c:d', key2 => 2}]);

test 'Error case';
eval {DBIx::Custom->connect(dsn => 'dbi:SQLit')};
ok($@, "connect error");

eval{$dbi->execute("{p }", {}, query => 1)};
ok($@, "create_query invalid SQL template");

test 'insert';
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$result = $dbi->execute('select * from table1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2}, {key1 => 3, key2 => 4}], "basic");

$dbi->execute('delete from table1');
$dbi->register_filter(
    twice       => sub { $_[0] * 2 },
    three_times => sub { $_[0] * 3 }
);
$dbi->default_bind_filter('twice');
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2}, filter => {key1 => 'three_times'});
$result = $dbi->execute('select * from table1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 3, key2 => 4}], "filter");
$dbi->default_bind_filter(undef);

$dbi->execute('drop table table1');
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2}, append => '   ');
$rows = $dbi->select(table => 'table1')->all;
is_deeply($rows, [{key1 => 1, key2 => 2}], 'insert append');

eval{$dbi->insert(table => 'table1', noexist => 1)};
like($@, qr/noexist/, "invalid");

eval{$dbi->insert(table => 'table', param => {';' => 1})};
like($@, qr/safety/);

eval { $dbi->execute("drop table ${q}table$p") };
$dbi->execute($create_table_reserved);
$dbi->apply_filter('table', select => {out => sub { $_[0] * 2}});
$dbi->insert(table => 'table', param => {select => 1});
$result = $dbi->execute("select * from ${q}table$p");
$rows   = $result->all;
is_deeply($rows, [{select => 2, update => undef}], "reserved word");

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert({key1 => 1, key2 => 2}, table => 'table1');
$dbi->insert({key1 => 3, key2 => 4}, table => 'table1');
$result = $dbi->execute('select * from table1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2}, {key1 => 3, key2 => 4}], "basic");

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => \"'1'", key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$result = $dbi->execute('select * from table1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2}, {key1 => 3, key2 => 4}], "basic");

test 'update';
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1_2);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->insert(table => 'table1', param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});
$dbi->update(table => 'table1', param => {key2 => 11}, where => {key1 => 1});
$result = $dbi->execute('select * from table1 order by key1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 11, key3 => 3, key4 => 4, key5 => 5},
                  {key1 => 6, key2 => 7,  key3 => 8, key4 => 9, key5 => 10}],
                  "basic");
                  
$dbi->execute("delete from table1");
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->insert(table => 'table1', param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});
$dbi->update(table => 'table1', param => {key2 => 12}, where => {key2 => 2, key3 => 3});
$result = $dbi->execute('select * from table1 order by key1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 12, key3 => 3, key4 => 4, key5 => 5},
                  {key1 => 6, key2 => 7,  key3 => 8, key4 => 9, key5 => 10}],
                  "update key same as search key");

$dbi->update(table => 'table1', param => {key2 => [12]}, where => {key2 => 2, key3 => 3});
$result = $dbi->execute('select * from table1 order by key1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 12, key3 => 3, key4 => 4, key5 => 5},
                  {key1 => 6, key2 => 7,  key3 => 8, key4 => 9, key5 => 10}],
                  "update key same as search key : param is array ref");

$dbi->execute("delete from table1");
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->insert(table => 'table1', param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});
$dbi->register_filter(twice => sub { $_[0] * 2 });
$dbi->update(table => 'table1', param => {key2 => 11}, where => {key1 => 1},
              filter => {key2 => sub { $_[0] * 2 }});
$result = $dbi->execute('select * from table1 order by key1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 22, key3 => 3, key4 => 4, key5 => 5},
                  {key1 => 6, key2 => 7,  key3 => 8, key4 => 9, key5 => 10}],
                  "filter");

$result = $dbi->update(table => 'table1', param => {key2 => 11}, where => {key1 => 1}, append => '   ');

eval{$dbi->update(table => 'table1', where => {key1 => 1}, noexist => 1)};
like($@, qr/noexist/, "invalid");

eval{$dbi->update(table => 'table1')};
like($@, qr/where/, "not contain where");

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$where = $dbi->where;
$where->clause(['and', 'key1 = :key1', 'key2 = :key2']);
$where->param({key1 => 1, key2 => 2});
$dbi->update(table => 'table1', param => {key1 => 3}, where => $where);
$result = $dbi->select(table => 'table1');
is_deeply($result->all, [{key1 => 3, key2 => 2}], 'update() where');

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->update(
    table => 'table1',
    param => {key1 => 3},
    where => [
        ['and', 'key1 = :key1', 'key2 = :key2'],
        {key1 => 1, key2 => 2}
    ]
);
$result = $dbi->select(table => 'table1');
is_deeply($result->all, [{key1 => 3, key2 => 2}], 'update() where');

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$where = $dbi->where;
$where->clause(['and', 'key2 = :key2']);
$where->param({key2 => 2});
$dbi->update(table => 'table1', param => {key1 => 3}, where => $where);
$result = $dbi->select(table => 'table1');
is_deeply($result->all, [{key1 => 3, key2 => 2}], 'update() where');

eval{$dbi->update(table => 'table1', param => {';' => 1})};
like($@, qr/safety/);

eval{$dbi->update(table => 'table1', param => {'key1' => 1}, where => {';' => 1})};
like($@, qr/safety/);

eval { $dbi->execute('drop table table1') };
eval { $dbi->execute("drop table ${q}table$p") };
$dbi->execute($create_table_reserved);
$dbi->apply_filter('table', select => {out => sub { $_[0] * 2}});
$dbi->apply_filter('table', update => {out => sub { $_[0] * 3}});
$dbi->insert(table => 'table', param => {select => 1});
$dbi->update(table => 'table', where => {select => 1}, param => {update => 2});
$result = $dbi->execute("select * from ${q}table$p");
$rows   = $result->all;
is_deeply($rows, [{select => 2, update => 6}], "reserved word");

eval {$dbi->update_all(table => 'table', param => {';' => 2}) };
like($@, qr/safety/);

eval { $dbi->execute("drop table ${q}table$p") };
$dbi->execute($create_table_reserved);
$dbi->apply_filter('table', select => {out => sub { $_[0] * 2}});
$dbi->apply_filter('table', update => {out => sub { $_[0] * 3}});
$dbi->insert(table => 'table', param => {select => 1});
$dbi->update(table => 'table', where => {'table.select' => 1}, param => {update => 2});
$result = $dbi->execute("select * from ${q}table$p");
$rows   = $result->all;
is_deeply($rows, [{select => 2, update => 6}], "reserved word");

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1_2);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->insert(table => 'table1', param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});
$dbi->update({key2 => 11}, table => 'table1', where => {key1 => 1});
$result = $dbi->execute('select * from table1 order by key1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 11, key3 => 3, key4 => 4, key5 => 5},
                  {key1 => 6, key2 => 7,  key3 => 8, key4 => 9, key5 => 10}],
                  "basic");

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1_2);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->insert(table => 'table1', param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});
$dbi->update(table => 'table1', param => {key2 => \"'11'"}, where => {key1 => 1});
$result = $dbi->execute('select * from table1 order by key1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 11, key3 => 3, key4 => 4, key5 => 5},
                  {key1 => 6, key2 => 7,  key3 => 8, key4 => 9, key5 => 10}],
                  "basic");

test 'update_all';
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1_2);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2, key3 => 3, key4 => 4, key5 => 5});
$dbi->insert(table => 'table1', param => {key1 => 6, key2 => 7, key3 => 8, key4 => 9, key5 => 10});
$dbi->register_filter(twice => sub { $_[0] * 2 });
$dbi->update_all(table => 'table1', param => {key2 => 10}, filter => {key2 => 'twice'});
$result = $dbi->execute('select * from table1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 20, key3 => 3, key4 => 4, key5 => 5},
                  {key1 => 6, key2 => 20, key3 => 8, key4 => 9, key5 => 10}],
                  "filter");


test 'delete';
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$dbi->delete(table => 'table1', where => {key1 => 1});
$result = $dbi->execute('select * from table1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 3, key2 => 4}], "basic");

$dbi->execute("delete from table1;");
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$dbi->register_filter(twice => sub { $_[0] * 2 });
$dbi->delete(table => 'table1', where => {key2 => 1}, filter => {key2 => 'twice'});
$result = $dbi->execute('select * from table1;');
$rows   = $result->all;
is_deeply($rows, [{key1 => 3, key2 => 4}], "filter");

$dbi->delete(table => 'table1', where => {key1 => 1}, append => '   ');

$dbi->delete_all(table => 'table1');
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$dbi->delete(table => 'table1', where => {key1 => 1, key2 => 2});
$rows = $dbi->select(table => 'table1')->all;
is_deeply($rows, [{key1 => 3, key2 => 4}], "delete multi key");

eval{$dbi->delete(table => 'table1', where => {key1 => 1}, noexist => 1)};
like($@, qr/noexist/, "invalid");

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$where = $dbi->where;
$where->clause(['and', 'key1 = :key1', 'key2 = :key2']);
$where->param({ke1 => 1, key2 => 2});
$dbi->delete(table => 'table1', where => $where);
$result = $dbi->select(table => 'table1');
is_deeply($result->all, [{key1 => 3, key2 => 4}], 'delete() where');

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$dbi->delete(
    table => 'table1',
    where => [
        ['and', 'key1 = :key1', 'key2 = :key2'],
        {ke1 => 1, key2 => 2}
    ]
);
$result = $dbi->select(table => 'table1');
is_deeply($result->all, [{key1 => 3, key2 => 4}], 'delete() where');

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->delete(table => 'table1', where => {key1 => 1}, prefix => '    ');
$result = $dbi->execute('select * from table1;');
$rows   = $result->all;
is_deeply($rows, [], "basic");

test 'delete error';
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
eval{$dbi->delete(table => 'table1')};
like($@, qr/"where" must be specified/,
         "where key-value pairs not specified");

eval{$dbi->delete(table => 'table1', where => {';' => 1})};
like($@, qr/safety/);

$dbi = DBIx::Custom->connect;
eval { $dbi->execute("drop table ${q}table$p") };
$dbi->execute($create_table_reserved);
$dbi->apply_filter('table', select => {out => sub { $_[0] * 2}});
$dbi->insert(table => 'table', param => {select => 1});
$dbi->delete(table => 'table', where => {select => 1});
$result = $dbi->execute("select * from ${q}table$p");
$rows   = $result->all;
is_deeply($rows, [], "reserved word");

test 'delete_all';
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$dbi->delete_all(table => 'table1');
$result = $dbi->execute('select * from table1;');
$rows   = $result->all;
is_deeply($rows, [], "basic");


test 'select';
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
$rows = $dbi->select(table => 'table1')->all;
is_deeply($rows, [{key1 => 1, key2 => 2},
                  {key1 => 3, key2 => 4}], "table");

$rows = $dbi->select(table => 'table1', column => ['key1'])->all;
is_deeply($rows, [{key1 => 1}, {key1 => 3}], "table and columns and where key");

$rows = $dbi->select(table => 'table1', where => {key1 => 1})->all;
is_deeply($rows, [{key1 => 1, key2 => 2}], "table and columns and where key");

$rows = $dbi->select(table => 'table1', column => ['key1'], where => {key1 => 3})->all;
is_deeply($rows, [{key1 => 3}], "table and columns and where key");

$rows = $dbi->select(table => 'table1', append => "order by key1 desc limit 1")->all;
is_deeply($rows, [{key1 => 3, key2 => 4}], "append statement");

$dbi->register_filter(decrement => sub { $_[0] - 1 });
$rows = $dbi->select(table => 'table1', where => {key1 => 2}, filter => {key1 => 'decrement'})
            ->all;
is_deeply($rows, [{key1 => 1, key2 => 2}], "filter");

eval { $dbi->execute("drop table table2") };
$dbi->execute($create_table2);
$dbi->insert(table => 'table2', param => {key1 => 1, key3 => 5});
$rows = $dbi->select(
    table => [qw/table1 table2/],
    column => 'table1.key1 as table1_key1, table2.key1 as table2_key1, key2, key3',
    where   => {'table1.key2' => 2},
    relation  => {'table1.key1' => 'table2.key1'}
)->all;
is_deeply($rows, [{table1_key1 => 1, table2_key1 => 1, key2 => 2, key3 => 5}], "relation : exists where");

$rows = $dbi->select(
    table => [qw/table1 table2/],
    column => ['table1.key1 as table1_key1', 'table2.key1 as table2_key1', 'key2', 'key3'],
    relation  => {'table1.key1' => 'table2.key1'}
)->all;
is_deeply($rows, [{table1_key1 => 1, table2_key1 => 1, key2 => 2, key3 => 5}], "relation : no exists where");

eval{$dbi->select(table => 'table1', noexist => 1)};
like($@, qr/noexist/, "invalid");

$dbi = DBIx::Custom->connect;
eval { $dbi->execute("drop table ${q}table$p") };
$dbi->execute($create_table_reserved);
$dbi->apply_filter('table', select => {out => sub { $_[0] * 2}});
$dbi->insert(table => 'table', param => {select => 1, update => 2});
$result = $dbi->select(table => 'table', where => {select => 1});
$rows   = $result->all;
is_deeply($rows, [{select => 2, update => 2}], "reserved word");

test 'fetch filter';
eval { $dbi->execute('drop table table1') };
$dbi->register_filter(
    twice       => sub { $_[0] * 2 },
    three_times => sub { $_[0] * 3 }
);
$dbi->default_fetch_filter('twice');
$dbi->execute($create_table1);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$result = $dbi->select(table => 'table1');
$result->filter({key1 => 'three_times'});
$row = $result->one;
is_deeply($row, {key1 => 3, key2 => 4}, "default_fetch_filter and filter");

test 'filters';
$dbi = DBIx::Custom->new;

is($dbi->filters->{decode_utf8}->(encode_utf8('あ')),
   'あ', "decode_utf8");

is($dbi->filters->{encode_utf8}->('あ'),
   encode_utf8('あ'), "encode_utf8");

test 'transaction';
$dbi = DBIx::Custom->connect;
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->dbh->begin_work;
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->insert(table => 'table1', param => {key1 => 2, key2 => 3});
$dbi->dbh->commit;
$result = $dbi->select(table => 'table1');
is_deeply(scalar $result->all, [{key1 => 1, key2 => 2}, {key1 => 2, key2 => 3}],
          "commit");

$dbi = DBIx::Custom->connect;
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->dbh->begin_work(0);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
$dbi->dbh->rollback;

$result = $dbi->select(table => 'table1');
ok(! $result->fetch_first, "rollback");

test 'cache';
eval { $dbi->execute('drop table table1') };
$dbi->cache(1);
$dbi->execute($create_table1);
$source = 'select * from table1 where key1 = :key1 and key2 = :key2;';
$dbi->execute($source, {}, query => 1);
is_deeply($dbi->{_cached}->{$source}, 
          {sql => "select * from table1 where key1 = ? and key2 = ?;", columns => ['key1', 'key2'], tables => []}, "cache");

eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
$dbi->{_cached} = {};
$dbi->cache(0);
$dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
is(scalar keys %{$dbi->{_cached}}, 0, 'not cache');

test 'execute';
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);
{
    local $Carp::Verbose = 0;
    eval{$dbi->execute('select * frm table1')};
    like($@, qr/\Qselect * frm table1;/, "fail prepare");
    like($@, qr/\.t /, "fail : not verbose");
}
{
    local $Carp::Verbose = 1;
    eval{$dbi->execute('select * frm table1')};
    like($@, qr/Custom.*\.t /s, "fail : verbose");
}

eval{$dbi->execute('select * from table1', no_exists => 1)};
like($@, qr/wrong/, "invald SQL");

$query = $dbi->execute('select * from table1 where key1 = :key1', {}, query => 1);
$dbi->dbh->disconnect;
eval{$dbi->execute($query, param => {key1 => {a => 1}})};
ok($@, "execute fail");

{
    local $Carp::Verbose = 0;
    eval{$dbi->execute('select * from table1 where {0 key1}', {}, query => 1)};
    like($@, qr/\Q.t /, "caller spec : not vebose");
}
{
    local $Carp::Verbose = 1;
    eval{$dbi->execute('select * from table1 where {0 key1}', {}, query => 1)};
    like($@, qr/QueryBuilder.*\.t /s, "caller spec : not vebose");
}


test 'transaction';
$dbi = DBIx::Custom->connect;
eval { $dbi->execute('drop table table1') };
$dbi->execute($create_table1);

$dbi->begin_work;

eval {
    $dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
    die "Error";
    $dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
};

$dbi->rollback if $@;

$result = $dbi->select(table => 'table1');
$rows = $result->all;
is_deeply($rows, [], "rollback");

$dbi->begin_work;

eval {
    $dbi->insert(table => 'table1', param => {key1 => 1, key2 => 2});
    $dbi->insert(table => 'table1', param => {key1 => 3, key2 => 4});
};

$dbi->commit unless $@;

$result = $dbi->select(table => 'table1');
$rows = $result->all;
is_deeply($rows, [{key1 => 1, key2 => 2}, {key1 => 3, key2 => 4}], "commit");

$dbi->dbh->{AutoCommit} = 0;
eval{ $dbi->begin_work };
ok($@, "exception");
$dbi->dbh->{AutoCommit} = 1;

1;
