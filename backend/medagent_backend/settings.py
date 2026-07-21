"""Django settings for the MED AGENT backend.

The ai_pipeline package (medagent) lives one level up; we add its parent to the path so
`from medagent.pipeline import run_pipeline` works from within Django.
"""

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
# Make the medagent ai_pipeline package importable (it sits in the project root).
import sys
sys.path.insert(0, str(BASE_DIR.parent))

SECRET_KEY = "CHANGE-ME-in-production-use-env-var"  # TODO: load from env in real deploys
DEBUG = True
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "rest_framework.authtoken",
    "accounts",
    "pipeline",
    "records",
    "reports",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "medagent_backend.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {"context_processors": [
            "django.template.context_processors.debug",
            "django.template.context_processors.request",
            "django.contrib.auth.context_processors.auth",
            "django.contrib.messages.context_processors.messages",
        ]},
    },
]

WSGI_APPLICATION = "medagent_backend.wsgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# Token auth (DRF built-in, no extra dependency).
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
}

# Where Ollama is running; override via env if needed.
OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_EXTRACT_MODEL = "qwen2.5:1.5b"
DEFAULT_ANALYZER_MODEL = "qwen2.5:1.5b"

# CORS: the Flutter web build is served from a different origin (e.g. localhost:8080)
# than Django. Allow browser cross-origin calls for local demos. In production,
# restrict CORS_ALLOWED_ORIGINS to your real frontend domain instead.
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True

# Encryption key for at-rest medical-record fields.
# DEV KEY below is committed only so encryption works out of the box locally.
# IN PRODUCTION load this from a secrets manager / env var and rotate it:
#   RECORD_ENCRYPTION_KEY = os.environ["RECORD_ENCRYPTION_KEY"].encode()
RECORD_ENCRYPTION_KEY = b"LzVIE39yrypwvZkNdVMq48bPOQ2oHoKDNwYPsBVBzvo="

AUTH_USER_MODEL = "accounts.User"

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
