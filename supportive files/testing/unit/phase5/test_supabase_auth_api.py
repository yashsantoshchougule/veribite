"""Unit tests for FastAPI Supabase Authentication endpoints."""

from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient
import pytest

from backend.main import app

client = TestClient(app)


def test_auth_verify_token_fallback():
    """Verify mock token verification fallback for offline testing."""
    response = client.post("/api/v1/auth/verify-token", json={"token": "mock_valid_token"})
    assert response.status_code == 200
    data = response.json()
    assert data["valid"] is True
    assert data["user"]["email"] == "user@example.com"
    assert data["user"]["username"] == "testuser"


def test_auth_me_missing_bearer_header():
    """Verify endpoint rejects requests without Bearer authorization header."""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
    assert "Missing or malformed Authorization header" in response.json()["detail"]


def test_auth_me_with_mock_token():
    """Verify /me endpoint extracts user with Bearer token."""
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer mock_valid_token"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["valid"] is True
    assert data["user"]["id"] == "mock-user-123"


def test_auth_verify_token_with_mocked_supabase():
    """Verify token verification with mocked Supabase client."""
    mock_supabase = MagicMock()
    mock_user = MagicMock()
    mock_user.id = "supa-123"
    mock_user.email = "test@veribite.app"
    mock_user.user_metadata = {"full_name": "Test User", "username": "veribite_tester"}
    mock_supabase.auth.get_user.return_value = MagicMock(user=mock_user)

    with patch("backend.api.auth.get_supabase_client", return_value=mock_supabase):
        response = client.post("/api/v1/auth/verify-token", json={"token": "real_or_mock_jwt"})
        assert response.status_code == 200
        data = response.json()
        assert data["valid"] is True
        assert data["user"]["id"] == "supa-123"
        assert data["user"]["email"] == "test@veribite.app"
        assert data["user"]["username"] == "veribite_tester"

