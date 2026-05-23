import os
import time
import jwt
import requests
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

# In-memory JWKS cache to avoid calling IdP endpoints on every request
jwks_cache = {
    "apple": {"keys": {}, "last_fetched": 0},
    "auth0": {"keys": {}, "last_fetched": 0}
}
CACHE_TTL = 3600  # Refresh cached public keys every 1 hour

security_agent = HTTPBearer()

def fetch_jwks(provider: str, url: str) -> dict:
    now = time.time()
    cache = jwks_cache[provider]
    if cache["keys"] and (now - cache["last_fetched"] < CACHE_TTL):
        return cache["keys"]
    
    try:
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        keys_data = response.json()
        
        # Hash keys by their Key ID (kid) for O(1) lookup
        parsed_keys = {key["kid"]: key for key in keys_data.get("keys", [])}
        jwks_cache[provider] = {
            "keys": parsed_keys,
            "last_fetched": now
        }
        return parsed_keys
    except Exception as e:
        # Fall back to stale cache if IdP goes offline temporarily
        if cache["keys"]:
            return cache["keys"]
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch public keys from identity provider {provider}: {str(e)}"
        )

def verify_jwt(credentials: HTTPAuthorizationCredentials = Depends(security_agent)) -> str:
    """
    Validates the bearer token signature, expiration, audience, and issuer.
    Supports Sign in with Apple and Auth0 identity providers.
    Returns the unique subject identifier (sub) of the authenticated user.
    """
    token = credentials.credentials
    try:
        # Decode without verification first to extract the kid (header) and iss (payload)
        unverified_header = jwt.get_unverified_header(token)
        unverified_claims = jwt.decode(token, options={"verify_signature": False})
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token format")
    
    kid = unverified_header.get("kid")
    iss = unverified_claims.get("iss", "")
    
    if not kid:
        raise HTTPException(status_code=401, detail="Token header missing key identifier ('kid')")

    # Routing based on token issuer
    if "appleid.apple.com" in iss:
        provider = "apple"
        jwks_url = "https://appleid.apple.com/auth/keys"
        # Apple audience matches client ID / Bundle ID
        allowed_audiences = [os.getenv("APPLE_AUDIENCE", "blc.Life-XP-iOS")]
    else:
        # Assume Auth0
        auth0_domain = os.getenv("AUTH0_DOMAIN")
        if not auth0_domain:
            raise HTTPException(status_code=500, detail="Backend configuration error: AUTH0_DOMAIN not set")
        
        if auth0_domain not in iss:
            raise HTTPException(status_code=401, detail="Token issuer does not match configured Auth0 domain")
            
        provider = "auth0"
        jwks_url = f"https://{auth0_domain}/.well-known/jwks.json"
        
        # Audience can be a specific API identifier or Client ID
        auth0_audience = os.getenv("AUTH0_AUDIENCE")
        allowed_audiences = [auth0_audience] if auth0_audience else None
    
    keys = fetch_jwks(provider, jwks_url)
    key_spec = keys.get(kid)
    
    if not key_spec:
        # Force a refresh in case of key rotation on the IdP side
        jwks_cache[provider]["last_fetched"] = 0
        keys = fetch_jwks(provider, jwks_url)
        key_spec = keys.get(kid)
        if not key_spec:
            raise HTTPException(status_code=401, detail="No matching public key found for token signature")
            
    # Construct PEM public key from JWK dictionary
    try:
        public_key = jwt.algorithms.RSAAlgorithm.from_jwk(key_spec)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load key: {str(e)}")
    
    try:
        # Verify the signature, expiration, issuer, and audience
        payload = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=allowed_audiences,
            issuer=iss
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Authentication failed: Token has expired")
    except jwt.InvalidAudienceError:
        raise HTTPException(status_code=401, detail="Authentication failed: Token has invalid audience")
    except jwt.InvalidIssuerError:
        raise HTTPException(status_code=401, detail="Authentication failed: Token has invalid issuer")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: Token verification failed: {str(e)}")
        
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication failed: Token payload missing 'sub' claim")
        
    return user_id
