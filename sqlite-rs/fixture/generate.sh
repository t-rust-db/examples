#!/usr/bin/env bash
# Generates the movies.db fixture used by ../queries/*.sql, via the real
# sqlite3 CLI -- sqlite-rs is a byte-compatible file-format clone, but has
# no API to create a brand-new database from nothing (only to open an
# already-valid one). Re-run any time to regenerate -- the .db file is
# gitignored.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

command -v sqlite3 >/dev/null 2>&1 || { echo "error: sqlite3 not found on PATH" >&2; exit 1; }

rm -f movies.db
sqlite3 movies.db <<'SQL'
CREATE TABLE directors(id INTEGER PRIMARY KEY, name TEXT);
CREATE TABLE movies(id INTEGER PRIMARY KEY, title TEXT, year INTEGER, director_id INTEGER);
CREATE TABLE actors(id INTEGER PRIMARY KEY, name TEXT);
CREATE TABLE movie_cast(movie_id INTEGER, actor_id INTEGER, role TEXT, is_lead INTEGER);

INSERT INTO directors(id, name) VALUES (1, 'Quentin Tarantino');
INSERT INTO directors(id, name) VALUES (2, 'Coen Brothers');

INSERT INTO movies(id, title, year, director_id) VALUES (1, 'Pulp Fiction', 1994, 1);
INSERT INTO movies(id, title, year, director_id) VALUES (2, 'Kill Bill: Volume 1', 2003, 1);
INSERT INTO movies(id, title, year, director_id) VALUES (3, 'Inglourious Basterds', 2009, 1);
INSERT INTO movies(id, title, year, director_id) VALUES (4, 'Django Unchained', 2012, 1);
INSERT INTO movies(id, title, year, director_id) VALUES (5, 'Once Upon a Time in Hollywood', 2019, 1);
INSERT INTO movies(id, title, year, director_id) VALUES (6, 'Fargo', 1996, 2);
INSERT INTO movies(id, title, year, director_id) VALUES (7, 'The Big Lebowski', 1998, 2);
INSERT INTO movies(id, title, year, director_id) VALUES (8, 'No Country for Old Men', 2007, 2);
INSERT INTO movies(id, title, year, director_id) VALUES (9, 'True Grit', 2010, 2);

INSERT INTO actors(id, name) VALUES (1, 'John Travolta');
INSERT INTO actors(id, name) VALUES (2, 'Uma Thurman');
INSERT INTO actors(id, name) VALUES (3, 'Brad Pitt');
INSERT INTO actors(id, name) VALUES (4, 'Christoph Waltz');
INSERT INTO actors(id, name) VALUES (5, 'Jamie Foxx');
INSERT INTO actors(id, name) VALUES (6, 'Leonardo DiCaprio');
INSERT INTO actors(id, name) VALUES (7, 'Frances McDormand');
INSERT INTO actors(id, name) VALUES (8, 'Jeff Bridges');
INSERT INTO actors(id, name) VALUES (9, 'Javier Bardem');
INSERT INTO actors(id, name) VALUES (10, 'Hailee Steinfeld');

INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (1, 1, 'Vincent Vega', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (1, 2, 'Mia Wallace', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (2, 2, 'The Bride', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (3, 3, 'Lt. Aldo Raine', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (3, 4, 'Col. Hans Landa', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (4, 5, 'Django', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (4, 4, 'Dr. King Schultz', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (5, 6, 'Rick Dalton', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (5, 3, 'Cliff Booth', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (6, 7, 'Marge Gunderson', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (7, 8, 'The Dude', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (8, 9, 'Anton Chigurh', 1);
INSERT INTO movie_cast(movie_id, actor_id, role, is_lead) VALUES (9, 10, 'Mattie Ross', 1);
SQL

echo "wrote $ROOT/movies.db"
