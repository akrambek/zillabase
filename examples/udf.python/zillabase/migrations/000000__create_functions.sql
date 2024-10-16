-- create_functions

CREATE FUNCTION gcd(int, int) RETURNS int
LANGUAGE python AS gcd;

CREATE FUNCTION blocking(int) RETURNS int
LANGUAGE python AS blocking;

CREATE FUNCTION key_value(varchar) RETURNS struct<key varchar, value varchar>
LANGUAGE python AS key_value;

CREATE FUNCTION series(int) RETURNS TABLE (x int)
LANGUAGE python AS series;

CREATE FUNCTION sum_csv_column(varchar) RETURNS int
LANGUAGE python AS sum_csv_column;
