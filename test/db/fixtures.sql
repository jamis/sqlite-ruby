create table A
(
  name VARCHAR(60),
  age INTEGER
);

insert into A values ( 'Zephyr', 1 );
insert into A values ( 'Timothy', 2 );
insert into A values ( 'Juniper', 3 );
insert into A values ( 'Cinnamon', 4 );
insert into A values ( 'Amber', 5 );
insert into A values ( NULL, 6 );

create table B
(
  id INTEGER PRIMARY KEY,
  name VARCHAR(60)
);

create index B_idx on B ( name );

create table D
(
  b_id INTEGER REFERENCES B ( id )
);
