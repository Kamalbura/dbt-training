"""Export BigQuery tables to local CSV files.

Exports all tables from the dbt marts dataset into exports/.
"""
from __future__ import annotations

import csv
from pathlib import Path

from google.cloud import bigquery

PROJECT_ID = "saras-bigquery"
DATASET_ID = "dbt_training_marts"
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "exports" / DATASET_ID


def export_table(client: bigquery.Client, table_ref: bigquery.TableReference) -> Path:
    table = client.get_table(table_ref)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    output_path = OUTPUT_DIR / f"{table.table_id}.csv"
    fieldnames = [field.name for field in table.schema]

    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(fieldnames)

        rows = client.list_rows(table)
        for row in rows:
            writer.writerow([row.get(name) for name in fieldnames])

    return output_path


def main() -> None:
    client = bigquery.Client(project=PROJECT_ID)
    dataset_ref = bigquery.DatasetReference(PROJECT_ID, DATASET_ID)

    tables = list(client.list_tables(dataset_ref))
    if not tables:
        raise SystemExit(f"No tables found in {PROJECT_ID}.{DATASET_ID}")

    print(f"Found {len(tables)} tables in {PROJECT_ID}.{DATASET_ID}.")
    for t in tables:
        path = export_table(client, t.reference)
        print(f"Exported {t.table_id} -> {path}")


if __name__ == "__main__":
    main()
