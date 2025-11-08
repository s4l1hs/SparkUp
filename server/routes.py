import random
import json
from datetime import date, timedelta
from typing import List, Dict, Optional
from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.responses import PlainTextResponse
from sqlmodel import select, delete, func

from .auth import get_current_user
from .db import get_session
from .models import (
    User, UserScore, UserStreak, UserSubscription, DailyLimits,
    UserAnsweredQuestion, QuizQuestion, AnswerPayload, AnswerResponse,
    UserScoreHistory, Challenge, UserCompletedChallenge, ChallengeResponse,
    DeviceToken, DeviceTokenPayload, NotificationMetric, UserSeenInfo
)
import os
from .config import TRANSLATIONS, MANUAL_INFOS, NOTIFICATION_FREQUENCY
from .utils import _get_info_text, _select_unseen_info_for_user, _send_notification_to_user, _get_user_access_level, _get_rank_name

router = APIRouter()


@router.put("/user/notifications/")
def set_user_notifications(enabled: bool = Query(...), db_user: User = Depends(get_current_user), session = Depends(get_session)):
    try:
        db_user.notifications_enabled = bool(enabled)
        session.add(db_user)
        session.commit()
        session.refresh(db_user)
        return {"notifications_enabled": db_user.notifications_enabled}
    except Exception as e:
        session.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update notifications setting: {e}")


@router.get("/user/profile/")
def get_user_profile(db_user: User = Depends(get_current_user), session = Depends(get_session)):
    score_obj = session.exec(select(UserScore).where(UserScore.user_id == db_user.id)).first()
    streak_obj = session.exec(select(UserStreak).where(UserStreak.user_id == db_user.id)).first()
    sub_obj = session.exec(select(UserSubscription).where(UserSubscription.user_id == db_user.id)).first()
    score = score_obj.score if score_obj else 0

    access = _get_user_access_level(db_user, session)
    quiz_limit = access["quiz_limit"]
    used = access["questions_answered"]

    today = date.today()
    sum_points = session.exec(select(func.sum(UserScoreHistory.points)).where(UserScoreHistory.user_id == db_user.id, UserScoreHistory.timestamp == today)).one()
    try:
        daily_points = int(sum_points) if sum_points else 0
    except Exception:
        daily_points = int(sum_points[0]) if isinstance(sum_points, (list, tuple)) and sum_points[0] else 0

    remaining = None
    if quiz_limit != float('inf'):
        remaining = max(0, int(quiz_limit) - int(used))

    return {
        "firebase_uid": db_user.firebase_uid,
        "email": db_user.email,
        "score": score,
        "rank_name": _get_rank_name(score),
        "current_streak": streak_obj.streak_count if streak_obj else 0,
        "subscription_level": sub_obj.level if sub_obj else "free",
        "subscription_expires": sub_obj.expires_at.isoformat() if sub_obj and sub_obj.expires_at else None,
        "language_code": db_user.language_code,
        "notifications_enabled": True if getattr(db_user, 'notifications_enabled', True) else False,
        "topic_preferences": [],
        "daily_quiz_limit": None if quiz_limit == float('inf') else int(quiz_limit),
        "daily_quiz_used": int(used),
        "remaining_quizzes": remaining,
        "daily_points": int(daily_points),
    }


@router.get("/quiz/", response_model=List[Dict])
def get_quiz_questions(limit: int = 3, lang: Optional[str] = Query(None), preview: bool = Query(False), db_user: User = Depends(get_current_user), session = Depends(get_session)):
    access = _get_user_access_level(db_user, session)
    effective_lang = lang or (db_user.language_code if db_user.language_code else "en")

    if access["quiz_limit"] != float('inf'):
        remaining = int(access["quiz_limit"]) - int(access["questions_answered"])
    else:
        remaining = None

    if not preview and remaining is not None and remaining <= 0 and access["level"] != "ultra":
        tpl = TRANSLATIONS.get("daily_quiz_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_quiz_limit_reached"]["en"]
        return PlainTextResponse(tpl.format(limit=access["quiz_limit"]), status_code=429)

    answered_ids_raw = session.exec(select(UserAnsweredQuestion.quizquestion_id).where(UserAnsweredQuestion.user_id == db_user.id)).all()
    answered_ids = []
    for item in answered_ids_raw:
        if isinstance(item, (list, tuple)):
            if item:
                answered_ids.append(item[0])
        else:
            answered_ids.append(item)

    if not answered_ids:
        unanswered = session.exec(select(QuizQuestion)).all()
    else:
        unanswered = session.exec(select(QuizQuestion).where(QuizQuestion.id.notin_(answered_ids))).all()

    actual_limit = limit
    if remaining is not None and remaining < limit:
        actual_limit = max(0, remaining)

    chosen = []
    if actual_limit == 0:
        chosen = []
    elif len(unanswered) >= actual_limit:
        chosen = random.sample(unanswered, actual_limit)
    else:
        if not preview:
            session.exec(delete(UserAnsweredQuestion).where(UserAnsweredQuestion.user_id == db_user.id))
            session.commit()
            all_qs = session.exec(select(QuizQuestion)).all()
            if len(all_qs) < actual_limit:
                raise HTTPException(status_code=404, detail="Not enough new questions.")
            chosen = random.sample(all_qs, actual_limit)
        else:
            all_qs = session.exec(select(QuizQuestion)).all()
            if len(all_qs) < actual_limit:
                raise HTTPException(status_code=404, detail="Not enough questions for preview.")
            chosen = random.sample(all_qs, actual_limit)

    def _get_text(obj_field, q):
        try:
            data = json.loads(getattr(q, obj_field) or "{}")
            return data.get(effective_lang) or data.get("en") or ""
        except Exception:
            return ""

    result = []
    for q in chosen:
        question_text = _get_text("question_texts", q)
        options_raw = _get_text("options_texts", q)
        if isinstance(options_raw, str):
            try:
                options_parsed = json.loads(options_raw)
            except Exception:
                options_parsed = [options_raw]
        else:
            options_parsed = options_raw or []
        result.append({
            "id": q.id,
            "question_text": question_text,
            "options": options_parsed,
            "correct_answer_index": q.correct_answer_index
        })

    return result


@router.post("/quiz/answer/", response_model=AnswerResponse)
def submit_quiz_answer(payload: AnswerPayload, db_user: User = Depends(get_current_user), session = Depends(get_session)):
    question = session.get(QuizQuestion, payload.question_id)
    if not question:
        raise HTTPException(status_code=404, detail="Question not found.")
    user_score = session.exec(select(UserScore).where(UserScore.user_id==db_user.id)).first()
    user_streak = session.exec(select(UserStreak).where(UserStreak.user_id==db_user.id)).first()
    limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
    if not user_score or not user_streak or not limits:
        raise HTTPException(status_code=500, detail="User data missing.")

    access = _get_user_access_level(db_user, session)
    if access["quiz_limit"] != float('inf') and access["questions_answered"] >= access["quiz_limit"] and access["level"] != "ultra":
        tpl = TRANSLATIONS.get("daily_quiz_limit_reached", {}).get(db_user.language_code or "en") or TRANSLATIONS["daily_quiz_limit_reached"]["en"]
        return PlainTextResponse(tpl.format(limit=access["quiz_limit"]), status_code=429)

    already_answered = session.exec(select(UserAnsweredQuestion).where(UserAnsweredQuestion.user_id == db_user.id, UserAnsweredQuestion.quizquestion_id == payload.question_id)).first()
    is_correct = (question.correct_answer_index == payload.answer_index)
    score_awarded = 0
    if not already_answered:
        if is_correct:
            lvl = access.get("level") if isinstance(access, dict) else None
            if lvl == "pro":
                base_score = 15
            elif lvl == "ultra":
                base_score = 20
            else:
                base_score = 10
            streak_bonus = min(user_streak.streak_count, 5) * 2
            score_awarded = base_score + streak_bonus
            user_score.score += score_awarded
            user_streak.streak_count += 1
            try:
                session.add(UserScoreHistory(user_id=db_user.id, points=score_awarded))
            except Exception:
                pass
        else:
            user_streak.streak_count = 0

        session.add(UserAnsweredQuestion(user_id=db_user.id, quizquestion_id=payload.question_id))
        limits.questions_answered = (limits.questions_answered or 0) + 1

        session.add(user_score); session.add(user_streak); session.add(limits)
        session.commit()
        session.refresh(user_score); session.refresh(user_streak); session.refresh(limits)

    return AnswerResponse(correct=is_correct, correct_index=question.correct_answer_index, score_awarded=score_awarded, new_score=user_score.score)


@router.put("/user/language/")
def set_user_language(language_code: str = Query(...), db_user: User = Depends(get_current_user), session = Depends(get_session)):
    try:
        db_user.language_code = language_code
        session.add(db_user)
        session.commit()
        session.refresh(db_user)
        return {"language_code": db_user.language_code}
    except Exception as e:
        session.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update language: {e}")


@router.get("/challenges/random/", response_model=ChallengeResponse)
def get_random_challenge(lang: Optional[str] = Query(None), preview: bool = Query(False), consume: bool = Query(True), db_user: User = Depends(get_current_user), session = Depends(get_session)):
    effective_lang = lang or (db_user.language_code if db_user.language_code else "en")
    access = _get_user_access_level(db_user, session)

    if not preview:
        fresh_limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
        cur_count = fresh_limits.challenge_count if fresh_limits else 0
        if access["challenge_limit"] != float('inf') and cur_count >= access["challenge_limit"] and access["level"] != "ultra":
            tpl = TRANSLATIONS.get("daily_challenge_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_challenge_limit_reached"]["en"]
            return PlainTextResponse(tpl.format(limit=access["challenge_limit"]), status_code=429)

    if preview:
        all_ch = session.exec(select(Challenge)).all()
        if not all_ch:
            raise HTTPException(status_code=404, detail="No challenges available.")
        chosen_challenge = random.choice(all_ch)
        texts = {}
        try:
            texts = json.loads(chosen_challenge.challenge_texts or "{}")
        except Exception:
            texts = {}
        challenge_text = texts.get(effective_lang) or texts.get("en") or ""
        return ChallengeResponse(id=chosen_challenge.id, challenge_text=challenge_text, category=chosen_challenge.category)

    completed_ids_raw = session.exec(select(UserCompletedChallenge.challenge_id).where(UserCompletedChallenge.user_id == db_user.id)).all()
    completed_ids = []
    for item in completed_ids_raw:
        if isinstance(item, (list, tuple)):
            if item:
                completed_ids.append(item[0])
        else:
            completed_ids.append(item)

    unanswered = session.exec(select(Challenge).where(Challenge.id.notin_(completed_ids))).all()

    if not unanswered:
        fresh_limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
        cur_count = fresh_limits.challenge_count if fresh_limits else 0
        if access["challenge_limit"] != float('inf') and cur_count >= access["challenge_limit"] and access["level"] != "ultra":
            tpl = TRANSLATIONS.get("daily_challenge_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_challenge_limit_reached"]["en"]
            return PlainTextResponse(tpl.format(limit=access["challenge_limit"]), status_code=429)

        if consume:
            session.exec(delete(UserCompletedChallenge).where(UserCompletedChallenge.user_id == db_user.id))
            session.commit()
            unanswered = session.exec(select(Challenge)).all()
            if not unanswered:
                raise HTTPException(status_code=404, detail="No challenges available.")
        else:
            all_ch = session.exec(select(Challenge)).all()
            if not all_ch:
                raise HTTPException(status_code=404, detail="No challenges available.")
            chosen_challenge = random.choice(all_ch)
            texts = {}
            try:
                texts = json.loads(chosen_challenge.challenge_texts or "{}")
            except Exception:
                texts = {}
            challenge_text = texts.get(effective_lang) or texts.get("en") or ""
            return ChallengeResponse(id=chosen_challenge.id, challenge_text=challenge_text, category=chosen_challenge.category)

    chosen_challenge = random.choice(unanswered)

    if consume:
        fresh_limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
        cur_count = fresh_limits.challenge_count if fresh_limits else 0
        if access["challenge_limit"] != float('inf') and cur_count >= access["challenge_limit"] and access["level"] != "ultra":
            tpl = TRANSLATIONS.get("daily_challenge_limit_reached", {}).get(effective_lang) or TRANSLATIONS["daily_challenge_limit_reached"]["en"]
            return PlainTextResponse(tpl.format(limit=access["challenge_limit"]), status_code=429)

        session.add(UserCompletedChallenge(user_id=db_user.id, challenge_id=chosen_challenge.id))
        if fresh_limits:
            fresh_limits.challenge_count = (fresh_limits.challenge_count or 0) + 1
            session.add(fresh_limits)
        else:
            new_limits = DailyLimits(user_id=db_user.id, challenge_count=1)
            session.add(new_limits)
        session.commit()

    texts = {}
    try:
        texts = json.loads(chosen_challenge.challenge_texts or "{}")
    except Exception:
        texts = {}
    challenge_text = texts.get(effective_lang) or texts.get("en") or ""
    return ChallengeResponse(id=chosen_challenge.id, challenge_text=challenge_text, category=chosen_challenge.category)


@router.get("/leaderboard/")
def get_leaderboard(limit: int = 100, session = Depends(get_session)):
    rows = session.exec(
        select(User, UserScore)
        .join(UserScore, User.id == UserScore.user_id, isouter=True)
        .order_by(UserScore.score.desc().nullslast())
        .limit(limit)
    ).all()

    result = []
    rank = 1
    for pair in rows:
        user = pair[0]
        score_obj = pair[1] if len(pair) > 1 else None
        score = score_obj.score if score_obj else 0
        username = getattr(user, "username", None) or getattr(user, "display_name", None)
        if not username and getattr(user, "email", None):
            username = user.email.split("@", 1)[0]
        result.append({"rank": rank, "email": user.email, "username": username, "score": score})
        rank += 1
    return result


@router.get("/user/rank/")
def get_user_rank(db_user: User = Depends(get_current_user), session = Depends(get_session)):
    user_score_obj = session.exec(select(UserScore).where(UserScore.user_id == db_user.id)).first()
    user_score = user_score_obj.score if user_score_obj else 0

    higher_count = session.exec(
        select(func.count()).select_from(UserScore).where(UserScore.score > user_score)
    ).one()
    try:
        higher_count_val = int(higher_count)
    except Exception:
        higher_count_val = int(higher_count[0]) if isinstance(higher_count, (list, tuple)) else 0

    rank = higher_count_val + 1
    username = getattr(db_user, "username", None) or getattr(db_user, "display_name", None)
    if not username and getattr(db_user, "email", None):
        username = db_user.email.split("@", 1)[0]
    return {"rank": rank, "email": db_user.email, "username": username, "score": user_score}


@router.get("/quiz/localize/")
def localize_quiz(ids: str = Query(..., description="Comma separated quiz ids"), lang: Optional[str] = Query(None), session = Depends(get_session)):
    effective_lang = lang or "en"
    try:
        id_list = [int(s.strip()) for s in ids.split(",") if s.strip()]
        if not id_list:
            raise ValueError("no ids")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid ids parameter")

    qs = session.exec(select(QuizQuestion).where(QuizQuestion.id.in_(id_list))).all()

    def _get_text(obj_field, q):
        try:
            data = json.loads(getattr(q, obj_field) or "{}")
            return data.get(effective_lang) or data.get("en") or ""
        except Exception:
            return ""

    result = []
    for q in qs:
        question_text = _get_text("question_texts", q)
        options_raw = _get_text("options_texts", q)
        options_parsed = []
        if isinstance(options_raw, str):
            try:
                options_parsed = json.loads(options_raw)
            except Exception:
                options_parsed = [options_raw]
        else:
            options_parsed = options_raw or []
        result.append({
            "id": q.id,
            "question_text": question_text,
            "options": options_parsed,
            "correct_answer_index": q.correct_answer_index
        })
    return result


@router.get("/challenges/{challenge_id}/localize/", response_model=ChallengeResponse)
def localize_challenge(challenge_id: int, lang: Optional[str] = Query(None), session = Depends(get_session)):
    effective_lang = lang or "en"
    ch = session.get(Challenge, challenge_id)
    if not ch:
        raise HTTPException(status_code=404, detail="Challenge not found.")
    texts = {}
    try:
        texts = json.loads(ch.challenge_texts or "{}")
    except Exception:
        texts = {}
    challenge_text = texts.get(effective_lang) or texts.get("en") or ""
    return ChallengeResponse(id=ch.id, challenge_text=challenge_text, category=ch.category)


@router.get("/info/random/")
def get_random_info(category: Optional[str] = Query(None), db_user: User = Depends(get_current_user), session = Depends(get_session)):
    if not MANUAL_INFOS:
        raise HTTPException(status_code=404, detail="No infos available.")
    candidates = [ (i, it) for i, it in enumerate(MANUAL_INFOS) if (category is None or it.get("category") == category) ]
    if not candidates:
        raise HTTPException(status_code=404, detail="No infos match the category.")
    idx, info = random.choice(candidates)
    text = _get_info_text(info, db_user.language_code or "en")
    return {
        "info_index": idx,
        "category": info.get("category"),
        "text": text,
        "source": info.get("source")
    }


@router.post("/user/device-token/")
def register_device_token(payload: DeviceTokenPayload, db_user: User = Depends(get_current_user), session = Depends(get_session)):
    if not payload.token:
        raise HTTPException(status_code=400, detail="token required")
    existing = session.exec(select(DeviceToken).where(DeviceToken.token == payload.token)).first()
    if existing:
        if existing.user_id != db_user.id:
            existing.user_id = db_user.id
            existing.platform = payload.platform
            session.add(existing); session.commit()
            return {"status": "reassigned"}
        else:
            return {"status": "ok"}
    else:
        dt = DeviceToken(user_id=db_user.id, token=payload.token, platform=payload.platform)
        session.add(dt); session.commit()
        return {"status": "created"}


@router.delete("/user/device-token/")
def unregister_device_token(token: str = Query(...), db_user: User = Depends(get_current_user), session = Depends(get_session)):
    session.exec(delete(DeviceToken).where(DeviceToken.token == token, DeviceToken.user_id == db_user.id))
    session.commit()
    return {"status": "deleted"}


@router.post("/notifications/send_for_user/{user_id}")
def send_for_user(user_id: int, db_user: User = Depends(get_current_user), session = Depends(get_session)):
    if db_user.id != user_id:
        raise HTTPException(status_code=403, detail="Can only trigger notifications for yourself via this endpoint.")
    picked = _select_unseen_info_for_user(session, db_user)
    if not picked:
        raise HTTPException(status_code=404, detail="No info available to send.")
    idx, info = picked
    result = _send_notification_to_user(session, db_user, idx, info)
    return {"info_index": idx, "result": result}


@router.post("/notifications/run-scan/")
def run_scan(internal_secret: Optional[str] = Query(None), session = Depends(get_session)):
    secret = os.getenv("INTERNAL_CRON_SECRET")
    if secret:
        if not internal_secret or internal_secret != secret:
            raise HTTPException(status_code=403, detail="Forbidden")

    results = []
    users = session.exec(select(User)).all()
    for u in users:
        if not getattr(u, "notifications_enabled", True):
            continue
        sub = session.exec(select(UserSubscription).where(UserSubscription.user_id == u.id)).first()
        level = sub.level if sub else "free"
        allowed = NOTIFICATION_FREQUENCY.get(level, 1)
        limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == u.id)).first()
        sent_today = limits.notifications_sent if limits else 0
        if sent_today >= allowed:
            continue
        picked = _select_unseen_info_for_user(session, u)
        if not picked:
            results.append({"user_id": u.id, "status": "no_info"})
            continue
        idx, info = picked
        res = _send_notification_to_user(session, u, idx, info)
        results.append({"user_id": u.id, "info_index": idx, "send": res})
    return {"results_count": len(results), "results": results}


@router.post("/notifications/cleanup/")
def cleanup_tokens(tokens: Optional[List[str]] = None, session = Depends(get_session)):
    if not tokens:
        raise HTTPException(status_code=400, detail="tokens list required")
    try:
        session.exec(delete(DeviceToken).where(DeviceToken.token.in_(tokens)))
        session.commit()
        return {"removed": len(tokens)}
    except Exception as e:
        session.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/notifications/cleanup-old/")
def cleanup_old_tokens(days: int = 90, session = Depends(get_session)):
    cutoff = date.today() - timedelta(days=days)
    try:
        stmt = delete(DeviceToken).where(
            ((DeviceToken.last_seen != None) & (DeviceToken.last_seen < cutoff)) |
            ((DeviceToken.last_seen == None) & (DeviceToken.created_at < cutoff))
        )
        session.exec(stmt)
        session.commit()
        return {"removed_cutoff_days": days}
    except Exception as e:
        session.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/notifications/metrics/")
def get_notification_metrics(days: int = 7, session = Depends(get_session)):
    try:
        rows = session.exec(select(NotificationMetric).order_by(NotificationMetric.metric_date.desc()).limit(days)).all()
        out = []
        for r in rows:
            out.append({"date": r.metric_date.isoformat() if r.metric_date else None, "removed_tokens": r.removed_tokens, "attempts": r.attempts})
        return {"metrics": out}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
