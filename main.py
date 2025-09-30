import os
from typing import List, Optional
from sqlmodel import Field, SQLModel, create_engine, Session
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

engine = create_engine(DATABASE_URL, echo=True)


class DailyWord(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    word: str = Field(index=True, unique=True)
    meaning: str
    example_sentence: Optional[str] = None

class QuizQuestion(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    question_text: str
    options: str 
    correct_answer_index: int
    category: Optional[str] = Field(default="general", index=True)

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

app = FastAPI(title="SparkUp Backend")

@app.on_event("startup")
def on_startup():
    create_db_and_tables()


@app.get("/")
def read_root():
    return {"message": "SparkUp Backend'e Hoş Geldiniz!"}