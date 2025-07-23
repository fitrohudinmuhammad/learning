import asyncpg
async def cek():
    conn = await asyncpg.connect(user='postgres', password='postgres', database='store_0227',host='localhost', port='5432')
    await conn.execute("""SELECT set_asn_moves_as_cancel($1)""", '0227');
    await conn.close()

cek()