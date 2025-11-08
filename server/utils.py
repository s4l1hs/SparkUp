import json
import random
from datetime import date
from typing import Optional, Dict
from .config import MANUAL_INFOS, TRANSLATIONS, NOTIFICATION_FREQUENCY, load_manual_infos, SUBSCRIPTION_LIMITS
from .models import (
    UserSeenInfo, DeviceToken, DailyLimits, NotificationMetric, UserScoreHistory,
    UserSubscription, UserScore, UserStreak
)
from sqlmodel import select, delete
from firebase_admin import messaging


def _get_rank_name(score: int) -> str:
    if score >= 10000: return 'Üstad'
    if score >= 5000: return 'Elmas'
    if score >= 2000: return 'Altın'
    if score >= 1000: return 'Gümüş'
    if score >= 500: return 'Bronz'
    return 'Demir'


def _get_user_access_level(db_user, session) -> Dict:
    today = date.today()
    limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
    if not limits:
        limits = DailyLimits(user_id=db_user.id)
        session.add(limits); session.commit(); session.refresh(limits)
    sub = session.exec(select(UserSubscription).where(UserSubscription.user_id == db_user.id)).first()
    if not sub:
        sub = UserSubscription(user_id=db_user.id)
        session.add(sub); session.commit(); session.refresh(sub)
    if sub.expires_at and sub.expires_at < today:
        sub.level, sub.expires_at = "free", None
        session.add(sub); session.commit()
    if limits.last_reset < today:
        limits.quiz_count = 0
        limits.challenge_count = 0
        limits.questions_answered = 0
        limits.notifications_sent = 0
        limits.last_reset = today
        session.add(limits); session.commit()
    level = sub.level
    return {
        "level": level,
        "quiz_count": limits.quiz_count,
        "challenge_count": limits.challenge_count,
        "questions_answered": limits.questions_answered,
        "quiz_limit": SUBSCRIPTION_LIMITS[level]["quiz_limit"],
        "challenge_limit": SUBSCRIPTION_LIMITS[level]["challenge_limit"],
        "daily_limits_obj": limits
    }


def _get_info_text(info_obj: Dict, lang: str) -> str:
    try:
        texts = info_obj.get("info_texts") or {}
        return texts.get(lang) or texts.get("en") or ""
    except Exception:
        return ""


def _select_unseen_info_for_user(session, db_user, category: Optional[str] = None):
    if not MANUAL_INFOS:
        return None
    candidate_indices = [i for i, it in enumerate(MANUAL_INFOS) if (category is None or it.get("category") == category)]
    if not candidate_indices:
        return None

    seen_rows = session.exec(select(UserSeenInfo.info_index).where(UserSeenInfo.user_id == db_user.id)).all()
    seen_set = set()
    for item in seen_rows:
        if isinstance(item, (list, tuple)):
            if item:
                seen_set.add(item[0])
        else:
            seen_set.add(item)

    unseen = [i for i in candidate_indices if i not in seen_set]
    if not unseen:
        session.exec(delete(UserSeenInfo).where(UserSeenInfo.user_id == db_user.id))
        session.commit()
        unseen = candidate_indices.copy()

    chosen_idx = random.choice(unseen)
    return (chosen_idx, MANUAL_INFOS[chosen_idx])


def _send_notification_to_user(session, db_user, info_idx: int, info_obj: Dict) -> Dict:
    lang = db_user.language_code or "en"
    body = _get_info_text(info_obj, lang)
    title = info_obj.get("category", "SparkUp")

    tokens = session.exec(select(DeviceToken).where(DeviceToken.user_id == db_user.id)).all()
    token_list = [t.token for t in tokens] if tokens else []

    send_result = {"sent": False, "tokens_targeted": len(token_list)}
    try:
        if token_list:
            message = messaging.MulticastMessage(
                tokens=token_list,
                notification=messaging.Notification(title=title, body=body),
                data={"type": "info", "info_index": str(info_idx)}
            )
            resp = messaging.send_multicast(message)
            send_result.update({"success_count": resp.success_count, "failure_count": resp.failure_count})

            bad_tokens = []
            retry_tokens = []
            for i, r in enumerate(resp.responses):
                if not getattr(r, 'success', False):
                    tok = token_list[i]
                    exc = getattr(r, 'exception', None)
                    exc_text = str(exc).lower() if exc else ''
                    if any(x in exc_text for x in ["not-registered", "registration-token-not-registered", "invalid-registration-token", "invalid-argument"]):
                        bad_tokens.append(tok)
                    else:
                        retry_tokens.append(tok)
                else:
                    try:
                        session.exec(
                            select(DeviceToken).where(DeviceToken.token == token_list[i])
                        ).one()
                        session.exec((DeviceToken.__table__.update().where(DeviceToken.token == token_list[i]).values(last_seen=date.today())))
                        session.commit()
                    except Exception:
                        session.rollback()

            removed = []
            if bad_tokens:
                try:
                    session.exec(delete(DeviceToken).where(DeviceToken.token.in_(bad_tokens)))
                    session.commit()
                    removed = bad_tokens
                except Exception:
                    session.rollback()

            try:
                metric = NotificationMetric(metric_date=date.today(), removed_tokens=len(removed), attempts=len(token_list))
                session.add(metric)
                session.commit()
            except Exception:
                session.rollback()

            retry_result = None
            if retry_tokens:
                try:
                    retry_msg = messaging.MulticastMessage(
                        tokens=retry_tokens,
                        notification=messaging.Notification(title=title, body=body),
                        data={"type": "info", "info_index": str(info_idx)}
                    )
                    retry_resp = messaging.send_multicast(retry_msg)
                    retry_result = {"success_count": retry_resp.success_count, "failure_count": retry_resp.failure_count}
                except Exception as e:
                    retry_result = {"error": str(e)}

            send_result.update({"removed_tokens": removed, "retry": retry_result})
        else:
            send_result.update({"note": "no_device_tokens"})
    except Exception as e:
        send_result.update({"error": str(e)})

    try:
        session.add(UserSeenInfo(user_id=db_user.id, info_index=info_idx))
        limits = session.exec(select(DailyLimits).where(DailyLimits.user_id == db_user.id)).first()
        if not limits:
            limits = DailyLimits(user_id=db_user.id, notifications_sent=1)
        else:
            limits.notifications_sent = (limits.notifications_sent or 0) + 1
        session.add(limits)
        session.commit()
    except Exception as e:
        session.rollback()
        send_result.update({"persist_error": str(e)})

    send_result["sent"] = True
    return send_result
