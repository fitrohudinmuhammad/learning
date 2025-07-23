from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql:///usmh_dev'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = True
db = SQLAlchemy(app,)

class ecommerce_order_notify(db.Model):
    __tablename__ = 'ecommerce_order_notify'
    id = db.Column(db.BigInteger, primary_key=True)
    filename = db.Column(db.String)
    businessdate = db.Column(db.DateTime)
    stage = db.Column(db.SmallInteger, default=1)
    created = db.Column(db.DateTime, default=datetime.now)

datas = ecommerce_order_notify.query.filter_by(stage=1).order_by(ecommerce_order_notify.created.desc()).all()
for data in datas:
    if data.filename == 'string':
        data.query.filter_by(filename = data.filename).first().stage = 2
    db.session.commit()