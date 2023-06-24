import pytest
from fastapi.testclient import TestClient
from icecream import ic

from parse_env import getenv
from src.main import app

client = TestClient(
    app,
    base_url=getenv("FASTAPI_CORS_ORIGINS").split(" ")[0],
)


def test_healthz():
    response = client.get("/healthz/")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.parametrize("ip_address", ["104.244.42.65", "8.8.8.8"])
def test_lookup_user_ip(ip_address):
    headers = {"X-Forwarded-For": ip_address}
    response = client.post("/", json={}, headers=headers)
    assert response.status_code == 200
    assert response.json()["country"]["iso_code"] is not None
    assert response.json()["location"]["latitude"] is not None
    assert response.json()["location"]["longitude"] is not None


@pytest.mark.parametrize("ip_address", ["104.244.42.65", "8.8.8.8"])
def test_lookup_ip_addresses(ip_address):
    response = client.post("/", json={"ip_address": ip_address})
    assert response.status_code == 200
    assert response.json()["country"]["iso_code"] is not None
    assert response.json()["location"]["latitude"] is not None
    assert response.json()["location"]["longitude"] is not None


def test_lookup_pvt_ip_addresses():
    response = client.post("/", json={"ip_address": "192.168.1.2"})
    assert response.status_code == 404


def test_invalid_ip_lookup():
    response = client.post("/", json={"ip_address": "8.8.8.257"})
    assert response.status_code == 422


def test_cors_valid_origin():
    response = client.post(
        "/",
        json={"ip_address": "8.8.8.8"},
        headers={"Origin": getenv("FASTAPI_CORS_ORIGINS").split(" ")[0]},
    )

    assert (
        response.headers["access-control-allow-origin"]
        == getenv("FASTAPI_CORS_ORIGINS").split(" ")[0]
    )
    # assert response.headers["allow"] == "POST"


def test_cors_invalid_origin():
    response = client.post(
        "/",
        json={"ip_address": "8.8.8.8"},
        headers={"Origin": "https://somedomain.com"},
    )
    assert response.headers.get("access-control-allow-origin") is None
    # assert response.headers["allow"] == "POST"
