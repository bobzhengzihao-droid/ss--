#!/usr/bin/env python3
"""部署 index.html 到 GitHub Pages。大文件用 Python 避免 shell 截断。"""
import json, base64, subprocess, sys

REPO = 'bobzhengzihao-droid/ss--'
FILE = 'index.html'

def run(cmd, **kwargs):
    kwargs.setdefault('capture_output', True)
    kwargs.setdefault('text', True)
    r = subprocess.run(cmd, **kwargs)
    if r.returncode != 0:
        print(f'Error: {r.stderr}')
        sys.exit(1)
    return r.stdout.strip()

# 获取当前 SHA
sha = run(['gh', 'api', f'repos/{REPO}/contents/{FILE}', '--jq', '.sha'])

# 编码文件
with open(FILE, 'rb') as f:
    content = base64.b64encode(f.read()).decode()

# 推送
from datetime import datetime
payload = json.dumps({
    'message': f'deploy: {datetime.now().strftime("%Y-%m-%d %H:%M")}',
    'content': content,
    'sha': sha
})

result = run(['gh', 'api', f'repos/{REPO}/contents/{FILE}', '-X', 'PUT', '--input', '-'], input=payload)
print(f'Deployed: {json.loads(result)["content"]["sha"][:7]}')
print('https://www.bobo.run')
