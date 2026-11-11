import pytest

from main import MAX_WORK_MS, app


@pytest.fixture
def client():
    return app.test_client()


def test_index(client):
    response = client.get("/")
    assert response.status_code == 200
    assert "hostname" in response.get_json()


def test_healthz(client):
    assert client.get("/healthz").status_code == 200


def test_metrics_exposes_counters(client):
    client.get("/")
    body = client.get("/metrics").get_data(as_text=True)
    assert "http_requests_total" in body
    assert "http_request_duration_seconds_bucket" in body


def test_work_runs(client):
    assert client.get("/work?ms=10").get_json()["worked_ms"] == 10


def test_work_is_capped(client):
    assert client.get("/work?ms=99999").get_json()["worked_ms"] == MAX_WORK_MS


def test_work_rejects_bad_input(client):
    assert client.get("/work?ms=abc").status_code == 400
