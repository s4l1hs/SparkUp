import os
import importlib
import json

# Ensure in-memory sqlite for tests
os.environ['DATABASE_URL'] = 'sqlite:///:memory:'

import main
import pytest
from sqlmodel import Session


class DummyResponse:
    def __init__(self, success: bool, exc: Exception = None):
        self.success = success
        self.exception = exc


class DummyMultiResp:
    def __init__(self, success_count: int, failure_count: int, responses):
        self.success_count = success_count
        self.failure_count = failure_count
        self.responses = responses


@pytest.fixture(autouse=True)
def setup_env():
    # ensure DB tables exist in the current main module
    main.create_db_and_tables()
    # small MANUAL_INFOS
    main.MANUAL_INFOS = [
        {"category": "general", "info_texts": {"en": "Info A"}},
        {"category": "general", "info_texts": {"en": "Info B"}},
        {"category": "general", "info_texts": {"en": "Info C"}},
    ]
    yield


def test_select_unseen_and_cycle():
    with Session(main.engine) as session:
        # create user
        u = main.User(firebase_uid='u1')
        session.add(u); session.commit(); session.refresh(u)

        picked_indices = []
        # monkeypatch messaging to harmless stub
        def fake_send(msg):
            # simulate all success
            responses = [DummyResponse(True) for _ in (msg.tokens or [])]
            return DummyMultiResp(len(responses), 0, responses)
        main.messaging.send_multicast = fake_send

        # pick and send 3 times, should be unique
        for _ in range(3):
            idx, info = main._select_unseen_info_for_user(session, u)
            assert idx not in picked_indices
            picked_indices.append(idx)
            res = main._send_notification_to_user(session, u, idx, info)
            assert res.get('sent') is True

        # now all seen; next pick should reset cycle and return some index from full set
        idx2, info2 = main._select_unseen_info_for_user(session, u)
        assert idx2 in [0,1,2]


def test_invalid_token_removal_and_metrics():
    with Session(main.engine) as session:
        # create user
        u = main.User(firebase_uid='u2')
        session.add(u); session.commit(); session.refresh(u)
        # add device tokens
        t1 = main.DeviceToken(user_id=u.id, token='badtoken')
        t2 = main.DeviceToken(user_id=u.id, token='retrytoken')
        session.add(t1); session.add(t2); session.commit()

        # craft MANUAL_INFOS pick
        idx, info = 0, main.MANUAL_INFOS[0]

        # fake send multicast: first response invalid token, second transient
        def fake_send(msg):
            responses = [
                DummyResponse(False, Exception('registration-token-not-registered')),
                DummyResponse(False, Exception('Some transient network error'))
            ]
            return DummyMultiResp(0, 2, responses)

        # fake retry to succeed for retrytoken
        def fake_send_retry(msg):
            responses = [DummyResponse(True), ]
            return DummyMultiResp(1, 0, responses)

        called = {'count': 0}

        def send_with_retry(msg):
            # first call -> fake_send, second call (retry) -> fake_send_retry
            if called['count'] == 0:
                called['count'] += 1
                return fake_send(msg)
            else:
                return fake_send_retry(msg)

        main.messaging.send_multicast = send_with_retry

        res = main._send_notification_to_user(session, u, idx, info)
        assert res.get('sent') is True
        # badtoken should have been removed from DB
        remaining = session.exec(main.select(main.DeviceToken).where(main.DeviceToken.token == 'badtoken')).all()
        assert len(remaining) == 0
        # metrics entry should exist
        metrics = session.exec(main.select(main.NotificationMetric)).all()
        assert len(metrics) >= 1
    assert metrics[-1].removed_tokens >= 1