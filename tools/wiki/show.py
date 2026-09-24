import json, re, sys
d = json.load(open(__file__.rsplit('/',1)[0] + '/chars.json'))
for c in sys.argv[1:]:
    p = d['chars'][c]
    print('#####', c, p['info'].get('hp'), '|', [ (g['label'], [m[0]+':'+m[1] for m in g['moves']]) for g in d['roster'][c] if g['moves']])
    for t, abs in p['tabs'].items():
        print('--', t)
        for a in abs:
            desc = a['desc'].replace('\n', ' ')
            sents = re.findall(r'[^.!?]+[.!?]', desc)
            short = ' '.join(sents[:3]) if sents else desc
            print('[%s] %s | %s | %s | %s\n    %s' % (a['type'] or 'MOVE', a['name'], ','.join(a['dmg']), ','.join(a['flags']), '; '.join(k+'='+v.replace('\n',' ') for k,v in a['stats']), short[:420]))
