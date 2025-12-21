from typing import Optional
from datetime import date
from sqlmodel import Field, SQLModel, Relationship


class UserSubscription(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    level: str = Field(default="free")
    expires_at: Optional[date] = Field(default=None)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="subscription")


class DailyLimits(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    quiz_count: int = Field(default=0)
    challenge_count: int = Field(default=0)
    questions_answered: int = Field(default=0)
    last_reset: date = Field(default_factory=date.today)
    notifications_sent: int = Field(default=0)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="daily_limits")


class UserStreak(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    streak_count: int = Field(default=0)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="streak")


class UserScore(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    score: int = Field(default=0)
    user_id: int = Field(foreign_key="user.id", unique=True)
    user: "User" = Relationship(back_populates="score")


class UserScoreHistory(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    points: int = Field(default=0)
    timestamp: Optional[date] = Field(default_factory=date.today)


class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    firebase_uid: str = Field(unique=True, index=True)
    email: Optional[str] = None
    language_code: str = Field(default="en")
    username: Optional[str] = Field(default=None, index=True)
    notifications_enabled: bool = Field(default=True)
    score: Optional[UserScore] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})
    streak: Optional[UserStreak] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})
    subscription: Optional[UserSubscription] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})
    daily_limits: Optional[DailyLimits] = Relationship(back_populates="user", sa_relationship_kwargs={"cascade": "all, delete-orphan"})


class QuizQuestion(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    question_texts: str
    options_texts: str
    correct_answer_index: int
    category: str = Field(index=True)


# DailyInfo modeli eklendi (seed_manual.py ile uyumlu)
class DailyInfo(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    info_texts: str
    category: str = Field(index=True)
    source: Optional[str] = None


class Challenge(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    challenge_texts: str
    category: str = Field(default="fun", index=True)


class UserAnsweredQuestion(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True)
    quizquestion_id: int = Field(foreign_key="quizquestion.id", primary_key=True)


class UserCompletedChallenge(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True)
    challenge_id: int = Field(foreign_key="challenge.id", primary_key=True)


class AnswerPayload(SQLModel):
    question_id: int
    answer_index: int


class AnswerResponse(SQLModel):
    correct: bool
    correct_index: int
    score_awarded: int
    new_score: int


class ChallengeResponse(SQLModel):
    id: int
    challenge_text: str
    category: str


class DeviceToken(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    token: str = Field(index=True, unique=True)
    platform: Optional[str] = Field(default=None)
    created_at: Optional[date] = Field(default_factory=date.today)
    last_seen: Optional[date] = Field(default=None)


class UserSeenInfo(SQLModel, table=True):
    user_id: int = Field(foreign_key="user.id", primary_key=True)
    info_index: int = Field(primary_key=True)
    shown_at: Optional[date] = Field(default_factory=date.today)


class NotificationMetric(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    metric_date: date = Field(default_factory=date.today)
    removed_tokens: int = Field(default=0)
    attempts: int = Field(default=0)


class DeviceTokenPayload(SQLModel):
    token: str
    platform: Optional[str] = None
