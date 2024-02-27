#!/usr/bin/python
import mysql.connector
from flask import Flask
import requests

def add_print_sql():
    db = mysql.connector.connect(host="dwrds.cgpzlgzs9ybi.eu-central-1.rds.amazonaws.com",    # your host, usually localhost
                     user="dw",         # your username
                     passwd="12345678",  # your password
                     db="mydb")        # name of the data base

    # you must create a Cursor object. It will let
    #  you execute all the queries you need
    cur = db.cursor()
    #sqldel = "DROP TABLE dominiks"

    #cur.execute(sqldel)
    #cur.execute("CREATE DATABASE dwdb")

    #cur.execute("CREATE TABLE dominiks (name VARCHAR(255), address VARCHAR(255))")
    sql = "INSERT INTO dominiks (name, address) VALUES (%s, %s)"
    val = [
      ('Peter', 'Lowstreet 4'),
      ('Amy', 'Apple st 652'),
      ('Hannah', 'Mountain 21'),
      ('Michael', 'Valley 345'),
      ('Sandy', 'Ocean blvd 2'),
      ('Betty', 'Green Grass 1'),
      ('Richard', 'Sky st 331'),
      ('Susan', 'One way 98'),
      ('Vicky', 'Yellow Garden 2'),
      ('Ben', 'Park Lane 38'),
      ('William', 'Central st 954'),
      ('Chuck', 'Main Road 989'),
      ('Viola', 'Sideway 1633')
    ]
    cur.executemany(sql, val)

    # Use all the SQL you like
    cur.execute("SELECT * FROM dominiks")
    list=[]
    myresult = cur.fetchall()
    # print all the first cell of all the rows
    #for row in cur.fetchall():
    #    print ("row[0]")
    for x in myresult:
      list.append(x)
    db.close()
    return list


app = Flask(__name__)

@app.route('/')
def home ():
    a=add_print_sql()
    return a
app.run()                                                                                                                                                                                    16,0-1        Top