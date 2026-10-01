from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "postgresql+psycopg://postgres@127.0.0.1:5432/gaz"
    secret_key: str = "dev-secret-change-me-please-32-chars-min"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7
    otp_ttl_seconds: int = 300
    otp_rate_limit: int = 3
    otp_rate_window_seconds: int = 600
    media_root: str = "./media_store"
    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"
    env: str = "dev"

    default_geofence_radius_m: int = 60
    gps_accuracy_limit_m: int = 50
    credit_aging_days_hard_lock: int = 14
    presigned_ttl_minutes: int = 15

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
