import urllib.request
import urllib.error

def test_connection():
    url = "http://localhost:9080"
    try:
        print(f"Attempting to connect to {url}...")
        with urllib.request.urlopen(url, timeout=5) as response:
            status = response.getcode()
            body = response.read().decode('utf-8')
            print(f"Status Code: {status}")
            print(f"Response Body (first 500 chars):")
            print(body[:500])
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} {e.reason}")
        try:
            print(f"Error Body: {e.read().decode('utf-8')[:500]}")
        except:
            pass
    except urllib.error.URLError as e:
        print(f"URL Error: {e.reason}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    test_connection()
