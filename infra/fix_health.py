import os

path = os.path.expanduser('~/scoutcloud/scoutcloud.dev/infra/alb.tf')
with open(path, 'r') as f:
    content = f.read()

old = 'def health():\n    return jsonify(status="ok", host=HOST, version="ch5-asg")'

new = '''def health():
    import datetime
    try:
        import urllib.request
        instance_id = urllib.request.urlopen(
            "http://169.254.169.254/latest/meta-data/instance-id", timeout=2
        ).read().decode()
    except:
        instance_id = HOST
    with open("/proc/uptime") as f:
        uptime_seconds = int(float(f.read().split()[0]))
    return jsonify(
        status="ok",
        instance_id=instance_id,
        current_time=datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        uptime_seconds=uptime_seconds
    )'''

if old in content:
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)
    print("Done!")
else:
    print("No match found!")
