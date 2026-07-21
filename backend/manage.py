"""Django management entrypoint for the MED AGENT backend."""

import os
import sys

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "medagent_backend.settings")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Install dependencies with: pip install -r backend/requirements.txt"
        ) from exc
    execute_from_command_line(sys.argv)
