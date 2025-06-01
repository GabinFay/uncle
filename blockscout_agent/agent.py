import os
from contextlib import AsyncExitStack
from google.adk.agents.llm_agent import LlmAgent
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset, StdioServerParameters
# from google.adk.tools.tool import ToolOutput, ToolContext # Removed as it's causing an error and not used here

# print("Inspecting MCPToolset attributes:") # Removed debug print
# print(dir(MCPToolset))

async def get_tools_async() -> tuple[MCPToolset | None, AsyncExitStack | None]:
    blockscout_api_url = os.getenv("BLOCKSCOUT_API_URL")
    if not blockscout_api_url:
        print("Error: BLOCKSCOUT_API_URL environment variable not set.")
        print("Please set it in the .env file (e.g., BLOCKSCOUT_API_URL=\"https://eth.blockscout.com/api\")")
        return None, None

    # The blockscout-mcp-server is installed globally and run via npx
    # It requires BLOCKSCOUT_API_URL to be in its environment
    server_params = StdioServerParameters(
        command="npx",
        args=["-y", "blockscout-mcp"], # -y to auto-confirm npx execution
        env={"BLOCKSCOUT_API_URL": blockscout_api_url}
    )
    
    print(f"Attempting to instantiate MCPToolset with command: npx -y blockscout-mcp and env BLOCKSCOUT_API_URL={blockscout_api_url}")

    exit_stack = AsyncExitStack()
    try:
        # Instantiate MCPToolset and use AsyncExitStack to manage its context
        # This assumes MCPToolset is an async context manager or has async setup
        tools = MCPToolset(connection_params=server_params)
        # If MCPToolset needs an explicit awaitable connect/load method, it would be called here.
        # For now, ADK often handles this within its context management or LlmAgent tool processing.
        # The LlmAgent itself will call methods on the toolset when it needs to use a tool.
        
        # We might need to "enter" the toolset if it manages resources actively from the start
        # await exit_stack.enter_async_context(tools) # This might be needed if tools itself is an async context manager
        # However, typically the agent manages the tool lifecycle calls.
        # The key is that MCPToolset is instantiated here.

        print("MCPToolset instantiated. Tool loading typically happens when agent uses them or on explicit call if available.")
        # Let's try to see if tools are loaded by just instantiating, or if a method needs to be called.
        # For now, let's assume instantiation is enough and agent will handle calls.
        # The `get_tool_names()` method should exist on the instance.
        if hasattr(tools, 'get_tool_names') and callable(getattr(tools, 'get_tool_names')):
            print("Available tools (post-instantiation, if get_tool_names is available):")
            try:
                 # This call might trigger connection/loading if not done yet.
                tool_names = tools.get_tool_names() # This method might be synchronous.
                # If it's async, it would be: tool_names = await tools.get_tool_names()
                for tool_name in tool_names:
                    print(f"- {tool_name}")
            except Exception as e_get_names:
                print(f"Could not call get_tool_names on instantiated MCPToolset: {e_get_names}")
                print("This might be normal if tools are loaded lazily by the agent.")
        else:
            print("get_tool_names method not found on MCPToolset instance immediately after instantiation.")

        return tools, exit_stack # Return the instance and the exit_stack for cleanup
    except Exception as e:
        print(f"Error instantiating or managing MCPToolset: {e}")
        await exit_stack.aclose() # Clean up if error occurs during setup
        # Further error details from original code
        print("Please ensure 'npx' is installed and in your PATH.")
        print("Ensure 'blockscout-mcp' was installed globally.")
        print(f"Also check that BLOCKSCOUT_API_URL='{blockscout_api_url}' is a valid Blockscout API endpoint.")
        return None, None

async def get_agent_async():
    tools, exit_stack = await get_tools_async()
    if not tools:
        print("Agent creation failed because tools could not be loaded.")
        # exit_stack might be None or an already closed one if get_tools_async failed early
        if exit_stack: 
            await exit_stack.aclose() # Ensure cleanup
        return None, None

    # Ensure GOOGLE_API_KEY is set for the LlmAgent
    if not os.getenv("GOOGLE_API_KEY") or os.getenv("GOOGLE_API_KEY") == "YOUR_KEY_HERE":
        print("Error: GOOGLE_API_KEY environment variable not set or is placeholder.")
        print("Please set it in the .env file with your actual Google API Key.")
        if exit_stack:
            await exit_stack.aclose()
        return None, None

    root_agent = LlmAgent(
        model=os.getenv("GEMINI_MODEL", "gemini-2.5-pro-preview-03-25"),
        name='blockscout_analyst_agent',
        instruction='You are an AI assistant that can query blockchain data using Blockscout. Use the available tools to answer user questions about transactions, addresses, blocks, and tokens. Be precise and refer to the tool outputs.',
        # toolsets=tools, # Removed for testing if MCP tools are picked up differently
    )
    print("Blockscout Analyst Agent initialized.")
    return root_agent, exit_stack 