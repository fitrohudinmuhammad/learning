import asyncpg, pathlib, asyncio

async def main():
    conn = await asyncpg.connect(user='postgres',password='postgres',database='usmh_dev',host='localhost',port='5432')
    sqls_file = pathlib.Path('/opt/process_collect_old_data.sql')
    await conn.execute(sqls_file.read_text())
    await conn.close()

if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    result = loop.run_until_complete(main())
    loop.close()
    
