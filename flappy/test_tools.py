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
    print("--- Testing list_nodes ---")
    print(json.dumps(call_mcp("list_nodes"), indent=2))
    
    print("\n--- Testing get_editor_state ---")
    print(json.dumps(call_mcp("get_editor_state"), indent=2))
