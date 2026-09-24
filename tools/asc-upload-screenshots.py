#!/usr/bin/env python3
"""스크린샷을 App Store Connect API 로 직접 올린다.

웹 화면이 '업로드가 진행 중' 에서 안 풀릴 때 쓴다. 브라우저를 거치지 않으므로
어느 파일이 어디서 막히는지가 그대로 보인다.

    export ASC_KEY_ID=725K7F28QD
    export ASC_ISSUER_ID=<사용자 및 액세스 → 통합 의 UUID>
    export ASC_KEY_PATH=~/Downloads/AuthKey_725K7F28QD.p8

    python3 tools/asc-upload-screenshots.py 2.0 ko APP_IPHONE_67 Screenshots/jpg-ko
    python3 tools/asc-upload-screenshots.py 2.0 ko APP_IPAD_PRO_3GEN_129 Screenshots/jpg-ipad-ko

올리는 순서는 파일 이름 순서다. 이미 같은 이름이 올라가 있으면 건너뛴다.

세 단계로 올린다 — 자리를 예약해 업로드 주소를 받고(POST), 그 주소로 파일을 보내고(PUT),
다 보냈다고 알린다(PATCH). 두 번째 단계에는 ASC 인증 헤더를 붙이지 않는다. 붙이면 막힌다.
"""
import base64, hashlib, json, os, subprocess, sys, time, urllib.request, urllib.error

BASE = "https://api.appstoreconnect.apple.com/v1"


def b64u(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        ln = der[i + 1]
        out += der[i + 2 : i + 2 + ln].lstrip(b"\x00").rjust(32, b"\x00")
        i += 2 + ln
    return out


def token() -> str:
    head = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    body = {"iss": os.environ["ASC_ISSUER_ID"], "iat": int(time.time()) - 60,
            "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"}
    signing = f"{b64u(json.dumps(head).encode())}.{b64u(json.dumps(body).encode())}"
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign",
                          os.path.expanduser(os.environ["ASC_KEY_PATH"])],
                         input=signing.encode(), capture_output=True, check=True).stdout
    return f"{signing}.{b64u(der_to_raw(der))}"


def api(path: str, method: str = "GET", body=None):
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token())
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as res:
            raw = res.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode()[:400]
        raise SystemExit(f"{method} {url} → {e.code}\n{detail}")


def put_chunk(op, blob: bytes) -> None:
    piece = blob[op["offset"] : op["offset"] + op["length"]]
    req = urllib.request.Request(op["url"], data=piece, method=op["method"])
    for h in op.get("requestHeaders") or []:
        req.add_header(h["name"], h["value"])
    with urllib.request.urlopen(req) as res:
        res.read()


def main() -> None:
    for var in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"):
        if not os.environ.get(var):
            sys.exit(f"{var} 가 없다.")
    if len(sys.argv) < 5:
        sys.exit("쓰는 법: <버전> <언어> <디스플레이타입> <폴더>")
    version, locale, display, folder = sys.argv[1:5]

    app = api("/apps?filter[bundleId]=com.zerolive.cloudRadioN")["data"][0]
    vers = api(f"/apps/{app['id']}/appStoreVersions?limit=10")["data"]
    ver = next((v for v in vers if v["attributes"]["versionString"] == version), None)
    if not ver:
        sys.exit(f"{version} 버전이 없다.")

    locs = api(f"/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"]
    loc = next((l for l in locs if l["attributes"]["locale"].startswith(locale)), None)
    if not loc:
        sys.exit(f"{locale} 현지화가 없다. 있는 것: "
                 + ", ".join(l["attributes"]["locale"] for l in locs))

    sets = api(f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
    target = next((s for s in sets
                   if s["attributes"]["screenshotDisplayType"] == display), None)
    if target:
        print(f"기존 세트를 쓴다 {display} ({target['id']})")
    else:
        target = api("/appScreenshotSets", "POST", {"data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display},
            "relationships": {"appStoreVersionLocalization": {
                "data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}},
        }})["data"]
        print(f"세트를 새로 만들었다 {display} ({target['id']})")

    have = {s["attributes"]["fileName"]
            for s in api(f"/appScreenshotSets/{target['id']}/appScreenshots?limit=20")["data"]}

    names = sorted(n for n in os.listdir(folder) if n.lower().endswith((".png", ".jpg")))
    for name in names:
        if name in have:
            print(f"  건너뜀 {name} (이미 있다)")
            continue
        path = os.path.join(folder, name)
        blob = open(path, "rb").read()

        shot = api("/appScreenshots", "POST", {"data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(blob), "fileName": name},
            "relationships": {"appScreenshotSet": {
                "data": {"type": "appScreenshotSets", "id": target["id"]}}},
        }})["data"]

        for op in shot["attributes"]["uploadOperations"]:
            put_chunk(op, blob)

        done = api(f"/appScreenshots/{shot['id']}", "PATCH", {"data": {
            "type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True,
                           "sourceFileChecksum": hashlib.md5(blob).hexdigest()},
        }})["data"]
        st = (done["attributes"].get("assetDeliveryState") or {}).get("state", "?")
        print(f"  올림 {name}  {len(blob)//1024}KB  → {st}")

    print("\n처리 상태를 확인한다 (COMPLETE 가 되면 끝난 것이다)")
    time.sleep(6)
    for s in api(f"/appScreenshotSets/{target['id']}/appScreenshots?limit=20")["data"]:
        a = s["attributes"]
        d = a.get("assetDeliveryState") or {}
        errs = d.get("errors") or []
        print(f"  {d.get('state','?'):16} {a.get('fileName')}"
              + (f"  오류 {errs}" if errs else ""))


if __name__ == "__main__":
    main()
