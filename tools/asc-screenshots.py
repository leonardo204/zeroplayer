#!/usr/bin/env python3
"""App Store Connect 에 실제로 올라가 있는 스크린샷 상태를 보고, 걸린 것을 지운다.

웹 화면이 '업로드가 진행 중' 에서 안 풀릴 때 쓴다. 화면에 안 보이는 자산도
API 로는 보이고 지울 수 있다.

    export ASC_KEY_ID=P3F7A7RBL5
    export ASC_ISSUER_ID=<App Store Connect → 사용자 및 액세스 → 통합 에 있는 UUID>
    export ASC_KEY_PATH=~/Downloads/AuthKey_P3F7A7RBL5.p8

    python3 tools/asc-screenshots.py list          # 상태만 본다
    python3 tools/asc-screenshots.py clean         # COMPLETE 아닌 것을 지운다
    python3 tools/asc-screenshots.py clean --all   # 전부 지운다

JWT 서명은 openssl 로 한다 — 이 맥에 cryptography·pyjwt 가 없다.
"""
import base64, json, os, subprocess, sys, time, urllib.request, urllib.error

BUNDLE_ID = "com.zerolive.cloudRadioN"
BASE = "https://api.appstoreconnect.apple.com/v1"


def b64u(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """openssl 이 내는 DER 서명을 JWT 가 요구하는 r||s 64바이트로 바꾼다."""
    assert der[0] == 0x30
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        assert der[i] == 0x02
        ln = der[i + 1]
        val = der[i + 2 : i + 2 + ln].lstrip(b"\x00")
        out += val.rjust(32, b"\x00")
        i += 2 + ln
    return out


def token() -> str:
    key_id = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    key_path = os.path.expanduser(os.environ["ASC_KEY_PATH"])
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {"iss": issuer, "iat": int(time.time()) - 60,
               "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"}
    signing = f"{b64u(json.dumps(header).encode())}.{b64u(json.dumps(payload).encode())}"
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path],
                         input=signing.encode(), capture_output=True, check=True).stdout
    return f"{signing}.{b64u(der_to_raw(der))}"


JWT = None


def call(path: str, method: str = "GET"):
    url = path if path.startswith("http") else BASE + path
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", "Bearer " + JWT)
    try:
        with urllib.request.urlopen(req) as res:
            body = res.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        print(f"  ! {method} {url} → {e.code} {e.read().decode()[:300]}")
        return None


def main() -> None:
    global JWT
    for var in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"):
        if not os.environ.get(var):
            sys.exit(f"{var} 가 없다. 파일 맨 위 주석을 본다.")
    JWT = token()

    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    wipe_all = "--all" in sys.argv

    apps = call(f"/apps?filter[bundleId]={BUNDLE_ID}")
    if not apps or not apps["data"]:
        sys.exit("그 번들 ID 의 앱을 못 찾았다.")
    app = apps["data"][0]
    print(f"앱 {app['attributes']['name']} ({app['id']})\n")

    versions = call(f"/apps/{app['id']}/appStoreVersions?limit=5")
    stuck = []
    for ver in versions["data"]:
        va = ver["attributes"]
        if va["appStoreState"] in ("READY_FOR_SALE", "REMOVED_FROM_SALE"):
            continue
        print(f"=== 버전 {va['versionString']} · {va['appStoreState']}")

        locs = call(f"/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")
        for loc in locs["data"]:
            lang = loc["attributes"]["locale"]
            sets = call(f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")
            if not sets or not sets["data"]:
                print(f"  [{lang}] 스크린샷 없음")
                continue
            for s in sets["data"]:
                kind = s["attributes"]["screenshotDisplayType"]
                shots = call(f"/appScreenshotSets/{s['id']}/appScreenshots?limit=20")
                rows = shots["data"] if shots else []
                print(f"  [{lang}] {kind} — {len(rows)}장")
                for sh in rows:
                    a = sh["attributes"]
                    st = (a.get("assetDeliveryState") or {}).get("state", "?")
                    warn = "" if st == "COMPLETE" else "   ← 걸림"
                    print(f"        {st:16} {a.get('fileName')}{warn}")
                    if wipe_all or st != "COMPLETE":
                        stuck.append((sh["id"], lang, kind, a.get("fileName"), st))
        print()

    if cmd != "clean":
        print(f"지울 대상 {len(stuck)}건. 지우려면 clean 으로 다시 돌린다.")
        return

    if not stuck:
        print("지울 것이 없다.")
        return
    for sid, lang, kind, name, st in stuck:
        print(f"지움 [{lang}] {kind} {name} ({st})")
        call(f"/appScreenshots/{sid}", method="DELETE")
    print(f"\n{len(stuck)}건 지웠다. 웹 화면을 강제 새로고침한다.")


if __name__ == "__main__":
    main()
