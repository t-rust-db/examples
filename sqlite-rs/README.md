# sqlite-rs example

A small, runnable tour of [sqlite-rs](https://github.com/t-rust-db/sqlite-rs), the
byte-compatible SQLite clone in the t-rust-db family. A four-table schema --
`directors`, `movies`, `actors`, and a `movie_cast` junction table -- populated
with Quentin Tarantino's and the Coen Brothers' filmographies and their lead
cast, then a query joining all four tables.

## Fixture

One SQLite database file, built with the real `sqlite3` CLI (sqlite-rs has no
API to create a brand-new database from nothing, only to open an
already-valid one):

- `directors` -- 2 rows: `id`, `name`
- `movies` -- 9 rows: `id`, `title`, `year`, `director_id`
- `actors` -- 10 rows: `id`, `name`
- `movie_cast` -- 13 rows: `movie_id`, `actor_id`, `role`, `is_lead`

```bash
./fixture/generate.sh
```

Regenerate any time -- `movies.db` isn't committed.

## Queries

| File | Demonstrates |
|---|---|
| `queries/lead_cast.sql` | 4-table `JOIN`, `WHERE`, `ORDER BY` |

## Running

```bash
./run.sh
```

Generates the fixture if it's missing, then runs every query in `queries/`
against sqlite-rs, printing the SQL and its output. To run it by hand, once
the fixture exists:

```bash
sqlite-rs query fixture/movies.db \
    "SELECT movies.year, movies.title, directors.name, actors.name, movie_cast.role \
     FROM movies JOIN directors ON movies.director_id = directors.id \
     JOIN movie_cast ON movie_cast.movie_id = movies.id \
     JOIN actors ON actors.id = movie_cast.actor_id \
     WHERE movie_cast.is_lead = 1 ORDER BY movies.year"
```

Expected output starts with:

```
1994|Pulp Fiction|Quentin Tarantino|John Travolta|Vincent Vega
1994|Pulp Fiction|Quentin Tarantino|Uma Thurman|Mia Wallace
1996|Fargo|Coen Brothers|Frances McDormand|Marge Gunderson
```

### Finding the sqlite-rs binary

`run.sh` resolves the binary in this order, same as `../column-rs/run.sh`:

1. `$SQLITE_RS` — explicit path, if set
2. `sqlite-rs` on `$PATH` — a globally installed/linked build
3. `../../sqlite-rs/target/release/sqlite-rs` — i.e. `t-rust-db/sqlite-rs`
   built in place, the normal case when this `examples` repo is checked out
   as a sibling of `sqlite-rs` under `t-rust-db/`

It does not build sqlite-rs for you — build it first if needed:

```bash
(cd ../../sqlite-rs && cargo build --release --bin sqlite-rs)
```
