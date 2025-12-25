"""Deprecated migration helper.

DailyLimits and its columns have been removed from the application.
This script is intentionally a no-op to avoid touching historical DBs.
If you need to migrate data from an existing `dailylimits` table, please
export the data manually and perform a custom migration.
"""

def main():
    print("add_energy_used migration deprecated — no action taken.")


if __name__ == '__main__':
    main()
