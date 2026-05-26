import urllib.request
import json

def call_mcp(method, params=None):
    url = "http://localhost:9080/mcp"
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params or {}
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
    
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    print("Listing tools...")
    tools = call_mcp("tools/list")
    print(json.dumps(tools, indent=2))
