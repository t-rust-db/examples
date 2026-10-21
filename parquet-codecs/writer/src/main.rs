//! Writes the example's event rows with db-core's Parquet writer, once
//! per codec: `<out>/db_core_uncompressed.parquet`, `db_core_snappy` and
//! `db_core_zstd`. The rows follow the same formulas as `run.sh`'s DuckDB
//! `COPY`, so both writers write the same table.
//!
//!     parquet-codecs-writer <out-dir> <rows>

use std::fs::File;
use std::io::BufWriter;
use std::path::Path;

use db_core::storage::parquet::writer::{
    ColumnSpec, ColumnType, ColumnValues, Compression, ParquetWriter, WriterOptions,
};

/// 2026-10-21 00:00:00 UTC, in microseconds.
const BASE_US: i64 = 1_792_540_800_000_000;
const KINDS: [&str; 5] = ["login", "search", "view", "checkout", "logout"];

fn schema() -> Vec<ColumnSpec> {
    vec![
        ColumnSpec::new("id", ColumnType::Int64, false),
        ColumnSpec::new("ts", ColumnType::TimestampMicros, false),
        ColumnSpec::new("kind", ColumnType::Utf8, false),
        ColumnSpec::new("user_name", ColumnType::Utf8, false),
        ColumnSpec::new("amount", ColumnType::Int64, true),
        ColumnSpec::new("note", ColumnType::Utf8, true),
    ]
}

/// Rows `lo..hi` as columns.
fn rows(lo: i64, hi: i64) -> Vec<ColumnValues> {
    let r = || lo..hi;
    vec![
        ColumnValues::Int64(r().map(Some).collect()),
        ColumnValues::TimestampMicros(r().map(|i| Some(BASE_US + i * 1_000_000)).collect()),
        ColumnValues::Utf8(r().map(|i| Some(KINDS[(i % 5) as usize].to_string())).collect()),
        ColumnValues::Utf8(r().map(|i| Some(format!("user-{}", i * 7919 % 10007))).collect()),
        ColumnValues::Int64(r().map(|i| (i % 3 != 0).then_some(i * 37 % 1000)).collect()),
        ColumnValues::Utf8(
            r().map(|i| (i % 4 != 0).then(|| format!("request {i} from host {}", i % 97)))
                .collect(),
        ),
    ]
}

fn write(path: &Path, compression: Compression, total: i64) {
    let file = BufWriter::new(File::create(path).expect("create"));
    let options = WriterOptions {
        compression,
        ..WriterOptions::default()
    };
    let mut writer = ParquetWriter::new(file, schema(), options).expect("writer");
    let mut lo = 0;
    while lo < total {
        let hi = (lo + 50_000).min(total);
        writer.write_columns(rows(lo, hi)).expect("write");
        lo = hi;
    }
    writer.finish().expect("finish");
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (Some(out), Some(total)) = (args.get(1), args.get(2).and_then(|n| n.parse().ok())) else {
        eprintln!("usage: parquet-codecs-writer <out-dir> <rows>");
        std::process::exit(2);
    };
    for (name, compression) in [
        ("uncompressed", Compression::Uncompressed),
        ("snappy", Compression::Snappy),
        ("zstd", Compression::Zstd),
    ] {
        write(&Path::new(out).join(format!("db_core_{name}.parquet")), compression, total);
    }
}
