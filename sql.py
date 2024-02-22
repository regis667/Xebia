#!/usr/bin/python
import MySQLdb

db = MySQLdb.connect(host="dwrds.cgpzlgzs9ybi.eu-central-1.rds.amazonaws.com",    # your host, usually localhost
                     user="dw",         # your username
                     passwd="12345678",  # your password
                     db="dw")        # name of the data base

# you must create a Cursor object. It will let
#  you execute all the queries you need
cur = db.cursor()

# Use all the SQL you like
cur.execute("SELECT * FROM YOUR_TABLE_NAME")

# print all the first cell of all the rows
for row in cur.fetchall():
    print row[0]

db.close()
