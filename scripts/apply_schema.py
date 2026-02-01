#!/usr/bin/env python3
"""Apply database schema to PostgreSQL"""
import psycopg2
import sys
from pathlib import Path

# Connection settings
conn_params = {
    "host": "irdecode-prod-psql.postgres.database.azure.com",
    "port": 5432,
    "database": "nura",
    "user": "pgadmin",
    "password": "NuraNeural@2026!Pg",
    "sslmode": "require"
}

def main():
    schema_file = Path(__file__).parent.parent / "database" / "schema.sql"
    
    if not schema_file.exists():
        print(f"Schema file not found: {schema_file}")
        sys.exit(1)
    
    print(f"Reading schema from: {schema_file}")
    schema_sql = schema_file.read_text(encoding="utf-8")
    
    print(f"Connecting to {conn_params['host']}/{conn_params['database']}...")
    
    try:
        conn = psycopg2.connect(**conn_params)
        conn.autocommit = True
        cur = conn.cursor()
        
        # Check existing tables
        cur.execute("""
            SELECT table_name FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        existing = [r[0] for r in cur.fetchall()]
        print(f"Existing tables: {existing if existing else 'None'}")
        
        if "content" in existing:
            print("Schema already applied (content table exists)")
            return
        
        print("Applying schema...")
        cur.execute(schema_sql)
        print("Schema applied successfully!")
        
        # Verify
        cur.execute("""
            SELECT table_name FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        tables = [r[0] for r in cur.fetchall()]
        print(f"Tables created: {tables}")
        
        cur.close()
        conn.close()
        
    except psycopg2.Error as e:
        print(f"Database error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
