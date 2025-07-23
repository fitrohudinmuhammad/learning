import asyncpg

async def koneksi():
    conn = await asyncpg.connect(user='postgres', 
                        password='postgres', 
                        database='usmh_dev', 
                        host='localhost', 
                        port='5432')
    await asyncpg.
    await conn.execute("")
    