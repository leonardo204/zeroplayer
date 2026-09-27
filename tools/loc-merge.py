# -*- coding: utf-8 -*-
"""컴파일러가 뽑은 문자열을 문자열 카탈로그에 합친다.

`xcodebuild` 는 `.stringsdata` 만 만들고 `Localizable.xcstrings` 에 합치지는 않는다.
그 일은 Xcode 앱이 한다. 우리는 명령줄로 빌드하므로 이 도구가 대신 합친다.

    python3 tools/loc-merge.py /tmp/zpbuild          # 합치고 빠진 번역을 보여준다
    python3 tools/loc-merge.py /tmp/zpbuild --prune  # 소스에 없는 키까지 치운다

`--prune` 은 쓰지 않는 키를 지운다. 문구를 고쳐 옛 키가 남았을 때만 쓴다.
빌드를 한 번 다 돌린 뒤에 해야 한다 — 증분 빌드면 일부 파일의 추출 결과가 없어서
쓰고 있는 키까지 지워진다.
"""
import json, os, re, sys

CATALOG = 'Sources/Resources/Localizable.xcstrings'


def collect(build_dir):
    """빌드 폴더의 모든 `.stringsdata` 에서 Localizable 표의 키를 모은다."""
    keys = set()
    files = 0
    for root, _, names in os.walk(build_dir):
        for name in names:
            if not name.endswith('.stringsdata'):
                continue
            path = os.path.join(root, name)
            try:
                data = json.load(open(path))
            except Exception:
                continue
            table = data.get('tables', {}).get('Localizable')
            if not table:
                continue
            files += 1
            for entry in table:
                key = entry.get('key')
                if key is not None:
                    keys.add(key)
    return keys, files


def dump(catalog):
    """Xcode 와 같은 모양으로 쓴다 — 콜론 앞에 공백이 하나 붙는다."""
    text = json.dumps(catalog, indent=2, ensure_ascii=False)
    # 줄 앞머리의 키에만 적용한다. 값 안의 콜론은 건드리지 않는다.
    return re.sub(r'^(\s*)("(?:[^"\\]|\\.)*")\s*:', r'\1\2 :', text, flags=re.M) + '\n'


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else '/tmp/zpbuild'
    prune = '--prune' in sys.argv

    found, files = collect(build)
    print('추출 파일 %d개에서 키 %d개를 모았다' % (files, len(found)))
    if not found:
        print('빌드 폴더에 추출 결과가 없다:', build)
        return 1

    catalog = json.load(open(CATALOG))
    strings = catalog['strings']

    added = sorted(k for k in found if k not in strings)
    for key in added:
        strings[key] = {'extractionState': 'manual', 'localizations': {}}

    removed = []
    if prune:
        # 포맷 문자열과 빈 키는 소스에서 잡히지 않아도 남겨 둔다.
        removed = sorted(k for k in strings
                         if k not in found and k.strip() and '%' not in k)
        for key in removed:
            del strings[key]

    open(CATALOG, 'w').write(dump(catalog))

    print('더한 키 %d개' % len(added))
    for key in added:
        print('  + %s' % key[:66])
    if prune:
        print('지운 키 %d개' % len(removed))
        for key in removed:
            print('  - %s' % key[:66])

    missing = sorted(k for k, v in strings.items()
                     if 'en' not in v.get('localizations', {}) and k.strip() and '%' not in k)
    print('\n영어 번역이 빠진 키 %d개' % len(missing))
    for key in missing:
        print('  ? %s' % key[:66])
    return 0


if __name__ == '__main__':
    sys.exit(main())
