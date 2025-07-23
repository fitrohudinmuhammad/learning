import calendar, datetime, pytz
tz_tokyo = pytz.timezone('Asia/Jakarta')
last_day = datetime.datetime.now(tz=tz_tokyo).strftime('%d')
time = datetime.datetime.now(tz=tz_tokyo).strftime('%H:%M:%S')
print (last_day, time)