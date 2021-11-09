import psycopg2
import logging
import datetime
from flask import Flask
from flask_restful import Resource, Api, reqparse
from psycopg2 import Error
import parameters

logging.basicConfig(format='%(asctime)s - %(message)s', level=logging.DEBUG)

class Database():
    def __init__(self, db="helloworld", user="app", password=parameters.DB_PASSWORD, host=parameters.PRIMARY_PRIVATE_IP, port="5432"):
        try:
            logging.debug("Connecting to database: %s@%s:%s/%s", user, host, port, db)
            self.conn = psycopg2.connect(user=user,
                                    password=password,
                                    host=host,
                                    port=port,
                                    database=db)
            self.cur = self.conn.cursor()

            if not self.table_exists('api'):
                self.create_app_table()

        except (Exception, Error) as error:
            logging.error("Error while connecting to PostgreSQL", error)

    def table_exists(self, table_str):
        exists = False
        self.cur.execute("select exists(select relname from pg_class where relname='" + table_str + "')")
        exists = self.cur.fetchone()[0]
        logging.debug('Table %s exists: %s', table_str, exists)
        return exists
    
    def create_app_table(self):
        create_table_query = '''CREATE TABLE api(
                                username char(80),
                                birthday date,
                                PRIMARY KEY( username )
                                );'''
        self.cur.execute(create_table_query)
        self.conn.commit()
        logging.info('App table created successfully')
    
    def db_query(self, query,tuples):
        try:
            self.cur.execute(query,tuples)
        except (Exception, Error) as error:
            logging.error("Error while executing query: ", error)
        self.conn.commit()

    def db_fetchone(self, query,tuples):
        try:
            self.cur.execute(query,tuples)
        except (Exception, Error) as error:
            logging.error("Error while executing query: ", error)
        return self.cur.fetchone()

    def close(self):
        self.cur.close()
        self.conn.close()
        logging.info("PostgreSQL connection is closed")

    def __del__(self):
        self.close()

class DBrecord:
    db = Database()

    def __init__(self, name = None, birthday = None):
        if name is not None:
            self.name = name
        if birthday is not None:
            date_format = "%d/%m/%Y"
            self.birthday = datetime.datetime.strptime(birthday, date_format)

    def __str__(self):
        return f'DBrecord({self.name})'

    def __repr__(self):
        return f"DBrecord(name='{self.name}', birthday={self.birthday})"
    
    def store(self):
        logging.debug("Inserting record %s", self)
        insert_query = """INSERT INTO api (username, birthday) VALUES (%s, %s)"""
        item_tuple = (self.name.lower(), self.birthday)
        DBrecord.db.db_query(insert_query, item_tuple)
    
    def get(self, username):
        logging.debug("Getting record for user name %s", username)
        select_query = """SELECT username, birthday from api where username = %s"""
        fetch = DBrecord.db.db_fetchone(select_query, (username.lower(),))
        self.name, self.birthday = fetch

    def how_long_to_birthday(self):
        logging.debug("Calculating days to birthday for %s", self.name)
        today = datetime.date.today()
        next_birthday = datetime.date(today.year, self.birthday.month, self.birthday.day)
        if (next_birthday - today).days >= 0:
            return (next_birthday - today).days
        else:
            return (next_birthday.replace(next_birthday.year + 1) - today).days

app = Flask(__name__)
api = Api(app)

class Hello(Resource):
    parser = reqparse.RequestParser()
    parser.add_argument('birthday')

    def get(self, user_id):
        record = DBrecord()
        record.get(user_id)
        days_till_bday = record.how_long_to_birthday()
        if days_till_bday == 0:
            message = "Hello, {}! Happy birthday!".format(user_id)
        else:
            message = "Hello, {}! Your birthday is in {} day(s)".format(user_id,days_till_bday)
        return {"message": message}, 200


    def put(self, user_id):
        args = Hello.parser.parse_args()
        record = DBrecord(user_id, args['birthday'])
        record.store()
        return '', 204

class Health(Resource):
    def get(self):
        return {"health": "healthy"}, 200

api.add_resource(Hello, '/hello/<string:user_id>')
api.add_resource(Health, '/health')

if __name__ == '__main__':
    app.run(host='0.0.0.0',debug=True)

