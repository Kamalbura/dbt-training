from google.cloud import bigquery
import os

PROJECT_ID = "saras-bigquery"
DATASET_ID = "raw_shopify"
TABLE_ID = "orders"
FILE_PATH = os.path.join(os.path.dirname(__file__), "..", "RAW_DATASETS", "bquxjob_12dd921d_19c2829b22b_yourgpt.jsonl")

FILE_PATH = os.path.abspath(FILE_PATH)

if not os.path.exists(FILE_PATH):
    raise SystemExit(f"File not found: {FILE_PATH}")

client = bigquery.Client(project=PROJECT_ID)

# Use DatasetReference to avoid missing projectId issues
dataset_ref = bigquery.DatasetReference(PROJECT_ID, DATASET_ID)
try:
    dataset = client.get_dataset(dataset_ref)
    print(f"Dataset {DATASET_ID} already exists.")
except Exception:
    print(f"Creating dataset {DATASET_ID} in project {PROJECT_ID}...")
    dataset = bigquery.Dataset(dataset_ref)
    dataset.location = "US"
    client.create_dataset(dataset, exists_ok=True)
    print("Dataset created.")


table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
job_config = bigquery.LoadJobConfig(
    source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    autodetect=True,
    write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
)

print(f"Loading {FILE_PATH} into {table_ref} ...")
with open(FILE_PATH, "rb") as source_file:
    job = client.load_table_from_file(source_file, table_ref, job_config=job_config)
    job.result()

print(f"Loaded {job.output_rows} rows into {table_ref}.")
