import smtplib

smtpObj = smtplib.SMTP('smtp.gmail.com', 25)
smtpObj.sendmail('fitrohudin@portcities.net', 'fitrohudin05935@gmail.com', 'Check email')