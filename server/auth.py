from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from .db import get_session
from .models import User, UserScore, UserStreak, UserSubscription
from firebase_admin import auth
from sqlmodel import select
from sqlalchemy.exc import IntegrityError

token_auth_scheme = HTTPBearer()

def get_current_user(token: HTTPAuthorizationCredentials = Depends(token_auth_scheme), session = Depends(get_session)) -> User:
    try:
        decoded_token = auth.verify_id_token(token.credentials)
        uid = decoded_token['uid']
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid Firebase token: {e}")
    db_user = session.exec(select(User).where(User.firebase_uid == uid)).first()
    if db_user:
        return db_user
    else:
        try:
            new_user = User(
                firebase_uid=uid, email=decoded_token.get('email'),
                score=UserScore(), streak=UserStreak(),
                subscription=UserSubscription()
            )
            session.add(new_user); session.commit(); session.refresh(new_user)
            return new_user
        except IntegrityError:
            session.rollback()
            db_user = session.exec(select(User).where(User.firebase_uid == uid)).first()
            if not db_user: raise HTTPException(status_code=500, detail="Could not retrieve user after race condition.")
            return db_user
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to create new user: {e}")
