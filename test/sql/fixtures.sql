create table A
(
  name VARCHAR(60),
  age INTEGER,
  birth DATE
);

create table B
(
  id INTEGER PRIMARY KEY,
  name VARCHAR(60)
);

create index B_idx on B ( name );

create table C
(
  d1 DATE,
  d2 DATETIME,
  d3 TIME,
  r1 DECIMAL,
  r2 FLOAT,
  r3 NUMERIC,
  r4 DOUBLE,
  r5 REAL,
  r6 DEC,
  r7 FIXED,
  i1 INTEGER,
  i2 SMALLINT,
  i3 MEDIUMINT,
  i4 INT,
  i5 BIGINT,
  b1 BIT,
  b2 BOOL,
  b3 BOOLEAN,
  t1 TIMESTAMP,
  t2 TINYINT(1),
  t3 TINYINT(4),
  s1 STRING,
  s2 VARCHAR(15),
  s3 CHAR(15),
  s4 VARCHAR2(15),
  m1 OBJECT,
  n1 STRING,
  n2 DATE,
  n3 BOOLEAN
);

create table D
(
  b_id INTEGER REFERENCES B ( id )
);

create table E
(
  name VARCHAR(20) NOT NULL,
  thing OBJECT
);
