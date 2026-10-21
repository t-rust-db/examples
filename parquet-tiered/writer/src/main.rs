//! Writes a striped (tiered) db-core table: events over two days, each
//! closed hour flushed to `live/` as one file sorted by `session_id` and
//! cut into row groups, then day 0 merged into `archive/`. Every page is
//! zstd at its fastest level. The table's clock is the events' own time,
//! so hours and days close as the data says, not as the wall clock does.
//!
//!     parquet-tiered-writer <table-dir>

use std::path::Path;
use std::sync::atomic::{AtomicI64, Ordering};

use db_core::storage::ingest::layout::{DAY_NS, HOUR_NS};
use db_core::storage::ingest::wal::Ack;
use db_core::storage::ingest::{Layout, RecordValue, TableOptions, TableWriter, TierOptions};
use db_core::storage::parquet::writer::{ColumnSpec, ColumnType, Compression, WriterOptions};

/// 2026-10-21 00:00 UTC.
const BASE_NS: i64 = 20_747 * DAY_NS;
/// Events per hour, and the hours of each day that have events.
const PER_HOUR: i64 = 2_000;
const HOURS: [i64; 6] = [8, 9, 10, 11, 12, 13];
const KINDS: [&str; 5] = ["login", "search", "view", "checkout", "logout"];

static NOW: AtomicI64 = AtomicI64::new(BASE_NS);

fn clock() -> i64 {
    NOW.load(Ordering::SeqCst)
}

fn options() -> TableOptions {
    TableOptions {
        schema: Some(vec![
            ColumnSpec::new("session_id", ColumnType::UInt64, false),
            ColumnSpec::new("ts", ColumnType::TimestampNanos, false),
            ColumnSpec::new("kind", ColumnType::Utf8, false),
            ColumnSpec::new("amount", ColumnType::Int64, true),
        ]),
        layout: Layout::Tiered(TierOptions {
            sort_key: vec!["session_id".into()],
            row_group_max_rows: 500,
            // Replaced hour files go at the next flush, so the directory
            // holds only what the manifest lists.
            delete_grace_ns: 0,
            ..TierOptions::default()
        }),
        parquet: WriterOptions {
            compression: Compression::Zstd,
            ..WriterOptions::default()
        },
        clock,
        ..TableOptions::default()
    }
}

/// Event `n` of `day`'s hour `hour`: sessions overlap hours, so a session's
/// events land in neighbouring hour files.
fn event(day: i64, hour: i64, n: i64) -> Vec<RecordValue> {
    let at = BASE_NS + day * DAY_NS + hour * HOUR_NS + n * (HOUR_NS / PER_HOUR);
    let session = (day * 24 + hour) * 100 + n % 300;
    let kind = KINDS[(n % 5) as usize];
    vec![
        RecordValue::UInt(session as u64),
        RecordValue::Int(at),
        RecordValue::Str(kind.to_string()),
        if kind == "checkout" {
            RecordValue::Int(n % 997)
        } else {
            RecordValue::Null
        },
    ]
}

fn main() {
    let Some(dir) = std::env::args().nth(1) else {
        eprintln!("usage: parquet-tiered-writer <table-dir>");
        std::process::exit(2);
    };
    let dir = Path::new(&dir);
    std::fs::remove_dir_all(dir).ok();
    let mut table = TableWriter::open(dir, options()).expect("open");
    for day in 0..2 {
        for hour in HOURS {
            NOW.store(BASE_NS + day * DAY_NS + hour * HOUR_NS, Ordering::SeqCst);
            for n in 0..PER_HOUR {
                table.append_row(event(day, hour, n), Ack::Memory).expect("append");
            }
            // The next hour starts: this one closes into live/.
            NOW.fetch_add(HOUR_NS, Ordering::SeqCst);
            table.flush().expect("flush");
        }
    }
    // Day 1 is still open, so only day 0 merges into archive/.
    table.compact().expect("compact");
    table.flush().expect("flush");
    table.close().expect("close");
}
