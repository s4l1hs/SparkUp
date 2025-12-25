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
    User, UserScore, UserStreak, UserSubscription,
    UserAnsweredQuestion, UserAnswerRecord, QuizQuestion, AnswerPayload, AnswerResponse,
    UserScoreHistory, DeviceToken, DeviceTokenPayload, NotificationMetric, UserSeenInfo
)
from .models import UserEnergy
import os
from .config import TRANSLATIONS, MANUAL_INFOS, NOTIFICATION_FREQUENCY, MANUAL_TRUEFALSE, load_manual_truefalse
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

    # energy/session info
    remaining_energy = access.get("remaining_energy")
    session_seconds = access.get("session_seconds")

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
        "remaining_energy": int(remaining_energy) if remaining_energy is not None else None,
        "session_seconds": int(session_seconds) if session_seconds is not None else None,
        "daily_points": int(daily_points),
    }


@router.get("/quiz/", response_model=List[Dict])
def get_quiz_questions(limit: int = 3, lang: Optional[str] = Query(None), preview: bool = Query(False), db_user: User = Depends(get_current_user), session = Depends(get_session)):
    access = _get_user_access_level(db_user, session)
    effective_lang = lang or (db_user.language_code if db_user.language_code else "en")

    # Calculate remaining quizzes for the user
    quiz_limit = access.get("quiz_limit")
    used = access.get("questions_answered")
    remaining = None
    if quiz_limit is not None and quiz_limit != float('inf'):
        remaining = max(0, int(quiz_limit) - int(used))

    # Energy-based access: each non-preview session costs 1 energy
    remaining_energy = access.get("remaining_energy")
    session_seconds = access.get("session_seconds")

    # Daily quota enforcement removed: access gated by `remaining_energy` value in profile only.

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

    # If this is a real session (not preview), persistently consume one energy now.
    if not preview:
        user_energy = session.exec(select(UserEnergy).where(UserEnergy.user_id == db_user.id)).first()
        if not user_energy:
            # create a fallback row using access energy_per_day
            user_energy = UserEnergy(user_id=db_user.id, remaining_energy=access.get("energy_per_day", 3))
            try:
                session.add(user_energy); session.commit(); session.refresh(user_energy)
            except Exception:
                session.rollback()
        if user_energy.remaining_energy <= 0:
            raise HTTPException(status_code=403, detail="Insufficient energy")
        try:
            user_energy.remaining_energy = int(user_energy.remaining_energy) - 1
            session.add(user_energy); session.commit(); session.refresh(user_energy)
        except Exception:
            session.rollback()
    # Server no longer persists per-user daily limits here.

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
    # include session_seconds hint for client
    if session_seconds is not None:
        for r in result:
            r["session_seconds"] = session_seconds

    return result


@router.post("/quiz/answer/", response_model=AnswerResponse)
def submit_quiz_answer(payload: AnswerPayload, db_user: User = Depends(get_current_user), session = Depends(get_session)):
    question = session.get(QuizQuestion, payload.question_id)
    if not question:
        raise HTTPException(status_code=404, detail="Question not found.")
    user_score = session.exec(select(UserScore).where(UserScore.user_id==db_user.id)).first()
    user_streak = session.exec(select(UserStreak).where(UserStreak.user_id==db_user.id)).first()
    if not user_score or not user_streak:
        raise HTTPException(status_code=500, detail="User data missing.")

    access = _get_user_access_level(db_user, session)
    # Daily quiz-count enforcement removed: allow submissions as long as other access checks (energy) permit.

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
            # Quiz questions award double the per-question points compared to True/False.
            score_awarded = (base_score + streak_bonus) * 2
            user_score.score += score_awarded
            user_streak.streak_count += 1
            try:
                session.add(UserScoreHistory(user_id=db_user.id, points=score_awarded))
            except Exception:
                pass
        else:
            user_streak.streak_count = 0

        session.add(UserAnsweredQuestion(user_id=db_user.id, quizquestion_id=payload.question_id))
        # persist answer record for analysis
        try:
            session.add(UserAnswerRecord(user_id=db_user.id, quizquestion_id=payload.question_id, correct=bool(is_correct)))
        except Exception:
            pass
        session.add(user_score); session.add(user_streak)
        session.commit()
        session.refresh(user_score); session.refresh(user_streak)

    return AnswerResponse(correct=is_correct, correct_index=question.correct_answer_index, score_awarded=score_awarded, new_score=user_score.score)


@router.get("/user/analysis/")
def get_user_analysis(db_user: User = Depends(get_current_user), session = Depends(get_session)):
    """Return per-topic correctness percentages for the requesting user."""
    try:
        rows = session.exec(
            select(UserAnswerRecord, QuizQuestion)
            .join(QuizQuestion, UserAnswerRecord.quizquestion_id == QuizQuestion.id)
            .where(UserAnswerRecord.user_id == db_user.id)
        ).all()
        stats: Dict[str, Dict[str, int]] = {}
        for pair in rows:
            # pair is (UserAnswerRecord, QuizQuestion)
            rec = pair[0]
            q = pair[1]
            cat = getattr(q, 'category', 'unknown') or 'unknown'
            if cat not in stats:
                stats[cat] = {'correct': 0, 'total': 0}
            stats[cat]['total'] += 1
            if getattr(rec, 'correct', False):
                stats[cat]['correct'] += 1

        out = []
        for cat, vals in stats.items():
            total = vals['total']
            correct = vals['correct']
            pct = int(round((correct / total) * 100)) if total > 0 else 0
            out.append({'category': cat, 'correct': correct, 'total': total, 'percent': pct})

        # sort descending by percent
        out.sort(key=lambda x: x['percent'], reverse=True)
        return {'analysis': out}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


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


@router.get("/manual/truefalse/")
def get_manual_truefalse(db_user: User = Depends(get_current_user), session = Depends(get_session)):
    """Return the list of manual true/false questions loaded from data/manual_truefalse.json.
    This reads the in-memory `MANUAL_TRUEFALSE` list populated at startup by the server.
    """
    if not MANUAL_TRUEFALSE:
        # Try an on-demand load from the repo-root data path in case startup loading failed.
        try:
            repo_root = os.path.dirname(os.path.dirname(__file__))
            tf_path = os.path.join(repo_root, 'data', 'manual_truefalse.json')
            if tf_path and os.path.exists(tf_path):
                load_manual_truefalse(tf_path)
        except Exception:
            # silent on-demand failure to avoid noisy logs
            pass

    if not MANUAL_TRUEFALSE:
        raise HTTPException(status_code=404, detail="No true/false questions available.")

    # Ensure user has energy for a true/false session (cost 1 energy) and consume it
    access = _get_user_access_level(db_user, session)
    # Persistently decrement energy for a real session
    user_energy = session.exec(select(UserEnergy).where(UserEnergy.user_id == db_user.id)).first()
    if not user_energy:
        user_energy = UserEnergy(user_id=db_user.id, remaining_energy=access.get("energy_per_day", 3))
        try:
            session.add(user_energy); session.commit(); session.refresh(user_energy)
        except Exception:
            session.rollback()
    if user_energy.remaining_energy <= 0:
        raise HTTPException(status_code=403, detail="Insufficient energy")
    try:
        user_energy.remaining_energy = int(user_energy.remaining_energy) - 1
        session.add(user_energy); session.commit(); session.refresh(user_energy)
    except Exception:
        session.rollback()

    # Return questions and include session_seconds hint
    out = []
    for tf in MANUAL_TRUEFALSE:
        item = dict(tf)
        item["session_seconds"] = access.get("session_seconds")
        out.append(item)
    return out


@router.get("/debug/manual_truefalse_status/")
def debug_manual_truefalse_status():
    """Debug endpoint: returns whether manual true/false questions are loaded and a small sample."""
    try:
        loaded = bool(MANUAL_TRUEFALSE)
        count = len(MANUAL_TRUEFALSE) if loaded else 0
        sample = MANUAL_TRUEFALSE[0] if loaded and len(MANUAL_TRUEFALSE) > 0 else None
        return {"loaded": loaded, "count": count, "sample": sample}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/challenges/{challenge_id}/localize/")
def localize_challenge(challenge_id: int, lang: Optional[str] = Query(None), session = Depends(get_session)):
    # Challenge localization removed — this endpoint is deprecated.
    raise HTTPException(status_code=404, detail="Challenges are no longer available.")


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
        # Daily per-user notification limits removed; send based on NOTIFICATION_FREQUENCY not enforced per-user.
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
