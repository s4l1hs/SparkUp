"""Simple migration helper to add `energy_used` column to the DailyLimits table.

Usage:
  python server/migrations/add_energy_used.py

It will read DATABASE_URL from environment or fall back to a local sqlite file `maindb.db` in the project root.
This script is idempotent: it will skip if the column already exists.
"""
import os
import sqlite3
import urllib.parse

DB_ENV = os.getenv('DATABASE_URL')

# Support a simple sqlite:///<path> or sqlite:///absolute/path
def get_sqlite_path(db_url: str):
    if not db_url:
        return os.path.join(os.path.dirname(os.path.dirname(__file__)), 'maindb.db')
    if db_url.startswith('sqlite'):
        # remove prefix sqlite:///
        parts = db_url.split(':///')
        if len(parts) == 2:
            return parts[1]
    return None

def main():
    db_path = get_sqlite_path(DB_ENV)
    if not db_path:
        print('DATABASE_URL not SQLite or not set. Please run a migration appropriate for your DB.')
        return
    db_path = os.path.abspath(db_path)
    if not os.path.exists(db_path):
        print(f'Database file not found: {db_path}')
        return
    print(f'Using SQLite DB: {db_path}')
    conn = sqlite3.connect(db_path)
    try:
        cur = conn.cursor()
        # check if column exists
        cur.execute("PRAGMA table_info(dailylimits);")
        cols = [r[1] for r in cur.fetchall()]
        if 'energy_used' in cols:
            print('Column energy_used already exists; nothing to do.')
            return
        # add column
        print('Adding column energy_used to dailylimits...')
        cur.execute('ALTER TABLE dailylimits ADD COLUMN energy_used INTEGER DEFAULT 0;')
        conn.commit()
        print('Migration completed successfully.')
    except Exception as e:
        print('Migration failed:', e)
    finally:
        conn.close()

if __name__ == '__main__':
    main()
