from fastapi import FastAPI
import asyncpg
import os

app = FastAPI()

# get database url
DATABASE_URL = os.getenv("DATABASE_URL")

@app.get("/mini-test")
async def mini_test():
    try:
        # Debug: toon de DATABASE_URL (zonder wachtwoord)
        db_url_safe = DATABASE_URL.replace(DATABASE_URL.split('@')[0].split(':')[-1], "****") if DATABASE_URL else "NIET INGESTELD"

        if not DATABASE_URL:
            return {"test": "Mislukt", "foutmelding": "DATABASE_URL is niet ingesteld"}

        # 1. Verbinden
        conn = await asyncpg.connect(DATABASE_URL)

        # 2. create test table
        await conn.execute("CREATE TABLE IF NOT EXISTS mini_check (tekst text)")
        await conn.execute("INSERT INTO mini_check (tekst) VALUES ('Supabase verbinding werkt!')")

        # 3. read
        waarde = await conn.fetchval("SELECT tekst FROM mini_check LIMIT 1")

        await conn.close()

        # 4. show results
        return {"test": "Geslaagd", "database_zegt": waarde}

    except Exception as e:
        import traceback
        return {
            "test": "Mislukt",
            "foutmelding": str(e),
            "type": type(e).__name__,
            "traceback": traceback.format_exc()
        }