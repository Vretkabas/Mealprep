from fastapi import Header, HTTPException
from jose import jwt, jwk
from jose.exceptions import JWTError
import requests
import os

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

# Haal 1 keer JWKS op bij module load
SUPABASE_JWKS_URL = f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json"

_jwks_keys = {}

def _load_jwks():
    global _jwks_keys
    try:
        resp = requests.get(SUPABASE_JWKS_URL)
        print("JWKS STATUS:", resp.status_code)

        if resp.status_code == 200:
            jwks = resp.json()
            _jwks_keys = {
                key["kid"]: key
                for key in jwks.get("keys", [])
            }
        else:
            print("JWKS BODY:", resp.text[:200])

    except Exception as e:
        print("JWKS LOAD FOUT:", e)

def get_current_user(authorization: str | None = Header(default=None)):
    if authorization is None:
        raise HTTPException(status_code=401, detail="Missing token")

    try:
        token = authorization.split(" ")[1]
        header = jwt.get_unverified_header(token)
        alg = header.get("alg")
        kid = header.get("kid")

        if alg == "ES256":
            # Gebruik JWKS publieke key
            if kid not in _jwks_keys:
                print("KID NIET GEVONDEN, JWKS HERLADEN...")
                _load_jwks()  # probeer opnieuw bij key rotation

            if kid not in _jwks_keys:
                raise HTTPException(status_code=401, detail="Unknown key ID")

            public_key = jwk.construct(_jwks_keys[kid], algorithm="ES256")
            payload = jwt.decode(
                token,
                public_key,
                algorithms=["ES256"],
                audience="authenticated",
            )

        print("AUTH OK")
        return payload["sub"]

    except HTTPException:
        raise
    except JWTError as e:
        print("JWT ERROR:", e)
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")
    except Exception as e:
        print("AUTH ERROR:", type(e).__name__, e)
        raise HTTPException(status_code=401, detail=f"Auth error: {e}")