import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

# --- Налаштування підключення ---
CONN = dict(
    host="localhost",
    port=5432,
    dbname="bo_test",
    user="postgres",
    password="postgres"
)

XLSX = "BO Test - SQL.xlsx"  # шлях до файлу — поклади поруч зі скриптом

def run():
    conn = psycopg2.connect(**CONN)
    cur = conn.cursor()

    # ── 1. psp ──────────────────────────────────────────────────────────────
    cur.execute("""
        CREATE TABLE IF NOT EXISTS psp (
            id               INTEGER PRIMARY KEY,
            psp_merchant_id  TEXT,
            name             TEXT
        );
    """)

    # ── 2. currencies ────────────────────────────────────────────────────────
    cur.execute("""
        CREATE TABLE IF NOT EXISTS currencies (
            id           INTEGER PRIMARY KEY,
            iso_code     TEXT,
            rate_to_usd  NUMERIC
        );
    """)

    # ── 3. payment_credentials ───────────────────────────────────────────────
    cur.execute("""
        CREATE TABLE IF NOT EXISTS payment_credentials (
            id           INTEGER PRIMARY KEY,
            bin_country  TEXT,
            bin          TEXT,
            card_brand   TEXT
        );
    """)

    # ── 4. transactions ──────────────────────────────────────────────────────
    cur.execute("""
        CREATE TABLE IF NOT EXISTS transactions (
            id                      INTEGER PRIMARY KEY,
            psp_id                  INTEGER REFERENCES psp(id),
            amount                  NUMERIC,
            currency_id             INTEGER REFERENCES currencies(id),
            payment_credentials_id  INTEGER REFERENCES payment_credentials(id),
            status                  TEXT
        );
    """)

    # ── 5. refunds ───────────────────────────────────────────────────────────
    cur.execute("""
        CREATE TABLE IF NOT EXISTS refunds (
            id              INTEGER PRIMARY KEY,
            transaction_id  INTEGER REFERENCES transactions(id),
            amount          NUMERIC,
            currency_id     INTEGER REFERENCES currencies(id)
        );
    """)

    # ── 6. chargebacks ───────────────────────────────────────────────────────
    cur.execute("""
        CREATE TABLE IF NOT EXISTS chargebacks (
            id              INTEGER PRIMARY KEY,
            transaction_id  INTEGER REFERENCES transactions(id),
            amount          NUMERIC,
            currency_id     INTEGER REFERENCES currencies(id)
        );
    """)

    conn.commit()
    print("✅ Таблиці створено")

    # ── Завантаження даних ───────────────────────────────────────────────────
    sheets = {
        "psp":                 ("psp",                 ["id", "psp_merchant_id", "name"]),
        "currencies":          ("currencies",          ["id", "iso_code", "rate_to_USD"]),
        "payment_credentials": ("payment_credentials", ["id", "bin_country", "bin", "card_brand"]),
        "transactions":        ("transactions",        ["id", "psp_id", "amount", "currency_id", "payment_credentials_id", "status"]),
        "refunds":             ("refunds",             ["id", "transaction_id", "amount", "currency_id"]),
        "chargebacks":         ("chargebacks",         ["id", "transaction_id", "amount", "currency_id"]),
    }

    for sheet_name, (table, cols) in sheets.items():
        df = pd.read_excel(XLSX, sheet_name=sheet_name)
        df = df[cols].copy()

        # Приводимо id-колонки до int там де немає NaN
        for c in df.columns:
            if c in ("id", "psp_id", "currency_id", "payment_credentials_id", "transaction_id"):
                df[c] = pd.to_numeric(df[c], errors="coerce").astype("Int64")

        # Замінюємо NaN на None (щоб psycopg2 записав NULL)
        rows = [
            tuple(None if pd.isna(v) else v.item() if hasattr(v, 'item') else v for v in row)
            for row in df.itertuples(index=False, name=None)
        ]

        placeholders = ",".join(["%s"] * len(cols))
        sql = f"INSERT INTO {table} ({','.join(cols)}) VALUES %s ON CONFLICT DO NOTHING"
        execute_values(cur, sql, rows)
        conn.commit()
        print(f"✅ {table}: {len(rows)} рядків завантажено")

    cur.close()
    conn.close()
    print("\n🎉 Готово! Всі дані в базі bo_test.")

if __name__ == "__main__":
    run()