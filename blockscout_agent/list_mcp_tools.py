import asyncio
import os
import json
from dotenv import load_dotenv
from contextlib import AsyncExitStack
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset, StdioServerParameters

# Load environment variables from .env file in the current directory
# __file__ will be blockscout_agent/list_mcp_tools.py
dotenv_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env')
load_dotenv(dotenv_path=dotenv_path)

output_file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'listtools.txt')

async def fetch_and_save_blockscout_tool_definitions():
    """
    Connects to the Blockscout MCP server, fetches tool definitions,
    and saves them to listtools.txt.
    """
    blockscout_api_url = os.getenv("BLOCKSCOUT_API_URL")
    if not blockscout_api_url:
        print(f"CRITICAL: BLOCKSCOUT_API_URL environment variable not set in {dotenv_path}")
        print("Please set it (e.g., BLOCKSCOUT_API_URL=\"https://eth.blockscout.com/api\")")
        return

    server_params = StdioServerParameters(
        command="npx",
        args=["-y", "blockscout-mcp"], # -y to auto-confirm npx execution
        env={"BLOCKSCOUT_API_URL": blockscout_api_url}
    )

    print(f"Attempting to connect to MCP server: npx -y blockscout-mcp with BLOCKSCOUT_API_URL={blockscout_api_url}")

    tool_definitions_content = []
    exit_stack = AsyncExitStack()
    mcp_toolset = None

    try:
        mcp_toolset = MCPToolset(connection_params=server_params)
        # Register the close method to be called when the exit_stack is closed
        exit_stack.push_async_callback(mcp_toolset.close)

        print("MCPToolset instantiated. Attempting to fetch tool definitions...")
        
        # Get the list of BaseTool objects. This should trigger connection and tool discovery.
        tools = await mcp_toolset.get_tools()
        
        if not tools:
            print("No tools found. The MCP server might not have returned any tools or failed to connect properly.")
            tool_definitions_content.append("No tools found or MCP server did not return any tools.\n")
        else:
            print(f"Successfully fetched {len(tools)} tools. Extracting definitions...")
            tool_definitions_content.append(f"Found {len(tools)} tools from Blockscout MCP Server:\n\n")
            for i, tool_obj in enumerate(tools): # Renamed tool to tool_obj to avoid confusion with internal _mcp_tool
                # --- Debug: Inspect the tool object (can be removed after confirming) ---
                if i == 0:
                    print("\n--- Debug: Inspecting first tool object ---")
                    print(f"Tool type: {type(tool_obj)}")
                    print(f"dir(tool_obj): {dir(tool_obj)}")
                    try:
                        print(f"vars(tool_obj): {vars(tool_obj)}")
                    except TypeError:
                        print("vars(tool_obj): Not applicable")
                    if hasattr(tool_obj, '_mcp_tool'):
                        print(f"vars(tool_obj._mcp_tool): {vars(tool_obj._mcp_tool) if hasattr(tool_obj._mcp_tool, '__dict__') else 'N/A or slots'}")
                        print(f"tool_obj._mcp_tool.inputSchema: {tool_obj._mcp_tool.inputSchema}") # Direct access
                    print("--- End Debug ---\n")
                # --- End Debug ---

                definition = {}
                actual_mcp_data = getattr(tool_obj, '_mcp_tool', None)

                if actual_mcp_data:
                    tool_name = getattr(actual_mcp_data, 'name', f'Unknown Tool {i+1}')
                    description = getattr(actual_mcp_data, 'description', 'No description available.')
                    input_schema = getattr(actual_mcp_data, 'inputSchema', {})
                    
                    definition = {
                        "name": tool_name,
                        "description": description,
                        "parameters": input_schema # This should be a JSON schema dict
                    }
                else:
                    tool_name = f'Unknown Tool {i+1}'
                    definition = {"error": f"Could not extract MCP data for tool {i+1}"}
                
                print(f"  - Processing tool: {tool_name}")
                
                tool_definitions_content.append(f"Tool {i+1}: {tool_name}\n")
                tool_definitions_content.append("Definition:\n")
                tool_definitions_content.append(json.dumps(definition, indent=2))
                tool_definitions_content.append("\n\n" + "="*80 + "\n\n")
        
        with open(output_file_path, "w") as f:
            f.writelines(tool_definitions_content)
        print(f"Tool definitions successfully saved to {output_file_path}")

    except Exception as e:
        print(f"An error occurred while fetching or saving tool definitions: {e}")
        import traceback
        traceback.print_exc()
        if mcp_toolset:
             try:
                # Attempt to log tool names if MCPToolset was instantiated
                names = mcp_toolset.get_tool_names()
                print(f"Tool names available on MCPToolset instance at time of error: {names}")
             except AttributeError:
                 print("get_tool_names method not found on MCPToolset instance during error handling.")
             except Exception as e_names:
                print(f"Could not get tool names from MCPToolset instance during error handling: {e_names}")
    finally:
        print("Closing resources and MCP server connection (if active)...")
        await exit_stack.aclose() # This will call mcp_toolset.close()
        print("Cleanup complete.")

if __name__ == "__main__":
    print(f"Executing: {os.path.abspath(__file__)}")
    print(f"Current working directory: {os.getcwd()}")
    print(f"Attempting to load .env from: {dotenv_path}")
    
    # Pre-flight check for BLOCKSCOUT_API_URL
    if not os.getenv("BLOCKSCOUT_API_URL"):
        print(f"CRITICAL: BLOCKSCOUT_API_URL not found in environment after attempting to load {dotenv_path}.")
        print("Please ensure it is set in 'blockscout_agent/.env'. Example: BLOCKSCOUT_API_URL=\"https://eth.blockscout.com/api\"")
    else:
        print(f"BLOCKSCOUT_API_URL found: {os.getenv('BLOCKSCOUT_API_URL')}")
        print("Starting tool definition fetching process...")
        asyncio.run(fetch_and_save_blockscout_tool_definitions()) 