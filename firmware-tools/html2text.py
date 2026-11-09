import sys, re, html
raw = open(sys.argv[1], encoding='utf-8', errors='replace').read()
raw = re.sub(r'(?is)<(script|style|noscript)[^>]*>.*?</\1>', ' ', raw)
raw = re.sub(r'(?i)<br\s*/?>|</p>|</div>|</li>|</tr>|</h\d>', '\n', raw)
txt = html.unescape(re.sub(r'<[^>]+>', ' ', raw))
txt = re.sub(r'[ \t\r\f\v]+', ' ', txt)
txt = re.sub(r'\n\s*\n+', '\n', txt)
start = int(sys.argv[2]) if len(sys.argv) > 2 else 0
length = int(sys.argv[3]) if len(sys.argv) > 3 else 20000
sys.stdout.write(txt[start:start+length])
