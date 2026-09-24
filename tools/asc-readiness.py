#!/usr/bin/env python3
"""2.0 이 왜 심사에 못 들어가는지 App Store Connect 에 직접 물어본다.

웹 화면의 '심사에 추가할 수 없음' 문구는 실제 원인과 다를 때가 있다. 2026-09-24 에
"아직 스크린샷 업로드가 진행 중입니다" 가 떴지만 API 로 보니 스크린샷은 16장 모두
COMPLETE 였다. 이 스크립트는 빌드·앱 정보·카테고리·개인정보처리방침 URL·부가 자원을
한 번에 찍어 준다.

    export ASC_KEY_ID=725K7F28QD
    export ASC_ISSUER_ID=<사용자 및 액세스 → 통합 의 UUID>
    export ASC_KEY_PATH=~/Downloads/AuthKey_725K7F28QD.p8
    python3 tools/asc-readiness.py

**앱 개인정보(App Privacy)는 이 API 로 읽을 수 없다.** 여기 나오는 것이 전부
정상인데도 막혀 있으면 그 페이지를 웹에서 직접 확인한다 — 답을 채우고 '게시'를
누르지 않으면 초안으로 남고, 그 상태로는 심사에 들어가지 않는다.
"""

import base64, json, os, subprocess, time, urllib.request, urllib.error
BASE="https://api.appstoreconnect.apple.com/v1"
def b64u(r): return base64.urlsafe_b64encode(r).rstrip(b"=").decode()
def d2r(d):
    i=2 if d[1]<0x80 else 2+(d[1]&0x7F); o=b""
    for _ in range(2):
        ln=d[i+1]; o+=d[i+2:i+2+ln].lstrip(b"\x00").rjust(32,b"\x00"); i+=2+ln
    return o
def tok():
    h={"alg":"ES256","kid":os.environ["ASC_KEY_ID"],"typ":"JWT"}
    p={"iss":os.environ["ASC_ISSUER_ID"],"iat":int(time.time())-60,"exp":int(time.time())+900,"aud":"appstoreconnect-v1"}
    s=f"{b64u(json.dumps(h).encode())}.{b64u(json.dumps(p).encode())}"
    der=subprocess.run(["openssl","dgst","-sha256","-sign",os.path.expanduser(os.environ["ASC_KEY_PATH"])],input=s.encode(),capture_output=True,check=True).stdout
    return f"{s}.{b64u(d2r(der))}"
J=tok()
def call(p):
    u=p if p.startswith("http") else BASE+p
    r=urllib.request.Request(u); r.add_header("Authorization","Bearer "+J)
    try:
        with urllib.request.urlopen(r) as x:
            b=x.read(); return json.loads(b) if b else {}
    except urllib.error.HTTPError as e: return {"__err":f"{e.code}", "__body":e.read().decode()[:400]}
AID=call("/apps?filter[bundleId]=com.zerolive.cloudRadioN")["data"][0]["id"]
VID=[v for v in call(f"/apps/{AID}/appStoreVersions?limit=5")["data"] if v["attributes"]["appStoreState"]=="PREPARE_FOR_SUBMISSION"][0]["id"]

print("=== 붙은 빌드")
b=call(f"/appStoreVersions/{VID}/build")
if b.get("data"):
    a=b["data"]["attributes"]
    print("  ", a.get("version"), "처리", a.get("processingState"), "만료", a.get("expired"),
          "업로드", a.get("uploadedDate"))
    bid=b["data"]["id"]
    enc=call(f"/builds/{bid}?fields[builds]=usesNonExemptEncryption,lsMinimumSystemVersion,iconAssetToken")
    print("   usesNonExemptEncryption", (enc.get("data") or {}).get("attributes",{}).get("usesNonExemptEncryption"))
    bb=call(f"/builds/{bid}/betaAppReviewSubmission")
    icon=call(f"/builds/{bid}/icons")
    print("   아이콘", len(icon.get("data",[])), icon.get("__err",""))
else:
    print("   빌드 없음!", b.get("__err",""), b.get("__body",""))

print("\n=== appInfo (앱 단위 필수 칸)")
for info in call(f"/apps/{AID}/appInfos")["data"]:
    at=info["attributes"]
    if at.get("appStoreState")!="PREPARE_FOR_SUBMISSION": continue
    print("   id", info["id"], at)
    for rel in ("primaryCategory","secondaryCategory"):
        c=call(f"/appInfos/{info['id']}/{rel}")
        print(f"   {rel}", (c.get("data") or {}).get("id"), c.get("__err",""))
    locs=call(f"/appInfos/{info['id']}/appInfoLocalizations")
    for l in locs.get("data",[]):
        la=l["attributes"]
        print("   로케일", la.get("locale"), "name",la.get("name"), "subtitle",la.get("subtitle"),
              "privacyPolicyUrl",la.get("privacyPolicyUrl"))

print("\n=== 버전 부가 자원")
for rel in ("appStoreVersionPhasedRelease","routingAppCoverage","ageRatingDeclaration","appStoreVersionSubmission","appClipDefaultExperience"):
    r=call(f"/appStoreVersions/{VID}/{rel}")
    print(f"   {rel:32}", (r.get("data") or {}).get("id") if r.get("data") is not None else r.get("__err",""), r.get("__body","")[:120])
