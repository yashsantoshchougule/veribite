"""Global pytest configuration and fixtures for VeriBite test suites."""

import pytest
from backend.core.rate_limiter import get_rate_limiter


@pytest.fixture(autouse=True)
def reset_rate_limiter():
    """Ensure every unit test starts with a clean rate limiter state."""
    limiter = get_rate_limiter()
    limiter.reset()
    yield
    limiter.reset()

