import urllib.request
import json
import sys

class GodotMCP:
    def __init__(self, base_url="http://localhost:9080/mcp"):
        self.url = base_url

    def _call(self, method, params=None):
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params or {}
        }
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(self.url, data=data, headers={'Content-Type': 'application/json'})
        
        try:
            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode('utf-8'))
                if "error" in result:
                    return {"error": result["error"]}
                return result.get("result")
        except Exception as e:
            return {"error": str(e)}

    def call_tool(self, tool_name, **kwargs):
        """Calls a tool using the tools/call method."""
        # The MCP server expects 'name' and 'arguments' inside the params for tools/call
        # Based on previous test: call_mcp("tools/call", {"name": "list_nodes"})
        # Wait, the test showed: call_mcp("tools/call", {"name": "list_nodes"}) 
        # and it worked. Let's check if it needs 'arguments'.
        # Actually, the test result showed:
        # "result": { "content": [...], "structuredContent": {...} }
        # It seems 'name' is the key.
        return self._call("tools/call", {"name": tool_name, "arguments": kwargs})

    # --- Scene & Node Tools ---

    def list_nodes(self, parent_path=None, recursive=True):
        return self.call_tool("list_nodes", parent_path=parent_path, recursive=recursive)

    def get_scene_tree(self, max_depth=-1):
        return self.call_tool("get_scene_tree", max_depth=max_depth)

    def get_scene_structure(self, max_depth=-1):
        return self.call_tool("get_scene_structure", max_depth=max_depth)

    def create_node(self, node_name, node_type, parent_path="/root"):
        return self.call_tool("create_node", node_name=node_name, node_type=node_type, parent_path=parent_path)

    def delete_node(self, node_path):
        return self.call_tool("delete_node", node_path=node_path)

    def update_node_property(self, node_path, property_name, property_value):
        return self.call_tool("update_node_property", node_path=node_path, property_name=property_name, property_value=property_value)

    def get_node_properties(self, node_path):
        return self.call_tool("get_node_properties", node_path=node_path)

    # --- Script Tools ---

    def list_project_scripts(self, search_path="res://"):
        return self.call_tool("list_project_scripts", search_path=search_path)

    def read_script(self, script_path):
        return self.call_tool("read_script", script_path=script_path)

    def create_script(self, script_path, content="", template="empty", attach_to_node=None):
        params = {"script_path": script_path, "content": content, "template": template}
        if attach_to_node:
            params["attach_to_node"] = attach_to_node
        return self.call_tool("create_script", **params)

    def modify_script(self, script_path, content, line_number=None):
        params = {"script_path": script_path, "content": content}
        if line_number is not None:
            params["line_number"] = line_number
        return self.call_tool("modify_script", **params)

    def analyze_script(self, script_path):
        return self.call_tool("analyze_script", script_path=script_path)

    def get_current_script(self):
        return self.call_tool("get_current_script")

    # --- Scene Management ---

    def get_current_scene(self):
        return self.call_tool("get_current_scene")

    def get_current_scene_info(self):
        # This might be get_current_scene or get_editor_state
        return self.call_tool("get_current_scene")

    def open_scene(self, scene_path):
        return self.call_tool("open_scene", scene_path=scene_path)

    def save_scene(self, file_path=None):
        params = {}
        if file_path:
            params["file_path"] = file_path
        return self.call_tool("save_scene", **params)

    def create_scene(self, scene_path, root_node_type="Node"):
        return self.call_tool("create_scene", scene_path=scene_path, root_node_type=root_node_type)

    # --- Editor & Project Tools ---

    def get_editor_state(self):
        return self.call_tool("get_editor_state")

    def get_project_info(self):
        return self.call_tool("get_project_info")

    def get_project_settings(self, filter_prefix=None):
        params = {}
        if filter_prefix:
            params["filter"] = filter_prefix
        return self.call_tool("get_project_settings", **params)

    def get_project_structure(self, max_depth=3):
        return self.call_tool("get_project_structure", max_depth=max_depth)

    def list_project_scenes(self, search_path="res://"):
        return self.call_tool("list_project_scenes", search_path=search_path)

    def list_project_resources(self, search_path="res://", resource_types=None):
        params = {"search_path": search_path}
        if resource_types:
            params["resource_types"] = resource_types
        return self.call_tool("list_project_resources", **params)

    # --- Execution & Debugging ---

    def run_project(self, scene_path=None):
        params = {}
        if scene_path:
            params["scene_path"] = scene_path
        return self.call_tool("run_project", **params)

    def stop_project(self):
        return self.call_tool("stop_project")

    def execute_script(self, code, bind_objects=None):
        params = {"code": code}
        if bind_objects:
            params["bind_objects"] = bind_objects
        return self.call_tool("execute_script", **params)

    def execute_editor_script(self, code):
        return self.call_tool("execute_editor_script", code=code)

    def debug_print(self, message, category=None):
        params = {"message": message}
        if category:
            params["category"] = category
        return self.call_tool("debug_print", **params)

    def get_editor_logs(self, count=100, offset=0, order="desc", source="mcp", type_filter=None):
        params = {
            "count": count,
            "offset": offset,
            "order": order,
            "source": source
        }
        if type_filter is not None:
            params["type"] = type_filter
        return self.call_tool("get_editor_logs", **params)

    def get_performance_metrics(self):
        return self.call_tool("get_performance_metrics")

    def set_editor_setting(self, setting_name, setting_value):
        return self.call_tool("set_editor_setting", setting_name=setting_name, setting_value=setting_value)

    def get_selected_nodes(self):
        return self.call_tool("get_selected_nodes")

if __name__ == "__main__":
    # Quick test
    godot = GodotMCP()
    print("Testing list_nodes...")
    print(godot.list_nodes())
    print("\nTesting get_editor_state...")
    print(godot.get_editor_state())
