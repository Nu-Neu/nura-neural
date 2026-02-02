#!/usr/bin/env python3
"""Apply MVP database schema to PostgreSQL"""
import psycopg2
import sys
import os
from pathlib import Path

# Connection settings - prefer environment variables
conn_params = {
    "host": os.getenv("PGHOST", "irdecode-prod-psql.postgres.database.azure.com"),
    "port": int(os.getenv("PGPORT", "5432")),
    "database": os.getenv("PGDATABASE", "nura"),
    "user": os.getenv("PGUSER", "pgadmin"),
    "password": os.getenv("PGPASSWORD", "NuraNeural@2026!Pg"),
    "sslmode": "require"
}

def main():
    # Use simplified MVP schema (4 core tables per Technical Decision Meeting)
    schema_file = Path(__file__).parent.parent / "database" / "schema_mvp.sql"
    
    # Fallback to original if MVP doesn't exist
    if not schema_file.exists():
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
        
        # Check for MVP schema marker (trust_signals is unique to MVP)
        if "trust_signals" in existing:
            print("MVP Schema already applied (trust_signals table exists)")
            return
        
        # Check for old complex schema
        if "content" in existing or "claims" in existing:
            print("WARNING: Old complex schema detected!")
            print("Tables found: content, claims - these are not part of MVP")
            print("Consider dropping old schema first or use a fresh database")
            response = input("Continue with MVP schema? (y/N): ")
            if response.lower() != 'y':
                print("Aborted.")
                return
        
        print("Applying MVP schema (4 core tables)...")
        cur.execute(schema_sql)
        print("MVP Schema applied successfully!")
        
        # Verify - check for the 4 core tables
        cur.execute("""
            SELECT table_name FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        tables = [r[0] for r in cur.fetchall()]
        
        core_tables = ['source_profiles', 'items', 'narratives', 'trust_signals']
        missing = [t for t in core_tables if t not in tables]
        
        if missing:
            print(f"WARNING: Missing core tables: {missing}")
        else:
            print(f"✓ All 4 core tables created: {core_tables}")
        
        print(f"Total tables created: {len(tables)}")
        print(f"Tables: {tables}")
        
        cur.close()
        conn.close()
        
    except psycopg2.Error as e:
        print(f"Database error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
