"""Manual HTTP smoke test against a running AI service using the public fixture."""
import json
import sys
from pathlib import Path
from urllib.request import Request, urlopen


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8001'
    boundary = 'nail-virtual-smoke-boundary'
    image = Path(__file__).with_name('hand_example.jpg').read_bytes()
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
            'filename="hand.jpg"\r\nContent-Type: image/jpeg\r\n\r\n').encode() + image + f'\r\n--{boundary}--\r\n'.encode()
    for route in ['/detect-hand', '/extract-nail-design']:
        request = Request(base + route, data=body,
            headers={'Content-Type': 'multipart/form-data; boundary=' + boundary})
        with urlopen(request, timeout=60) as response:
            result = json.load(response)
        assert result['success']
        if route == '/detect-hand':
            assert result['segmented_count'] == 5
        else:
            assert len(result['designs']) == 5
        print(route + ': PASS')


if __name__ == '__main__':
    main()
