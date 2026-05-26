from godot_mcp import GodotMCP
import json

def main():
    godot = GodotMCP()
    print("Fetching runtime logs...")
    logs = godot.get_editor_logs(count=20, source="runtime")
    print(json.dumps(logs, indent=2))

if __name__ == "__main__":
    main()
