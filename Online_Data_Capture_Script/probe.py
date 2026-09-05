import requests

for name, url in {
    "DISPATCHIS": "https://www.nemweb.com.au/Reports/CURRENT/DispatchIS_Reports/",
    "PREDISPATCHIS": "https://www.nemweb.com.au/Reports/CURRENT/PredispatchIS_Reports/",
    "P5MIN": "https://www.nemweb.com.au/Reports/CURRENT/P5_Reports/",
}.items():
    r = requests.get(url, timeout=60, headers={"User-Agent": "Mozilla/5.0"})
    print("=" * 60)
    print(name, r.status_code, "len=", len(r.text))
    print(r.text[:800])