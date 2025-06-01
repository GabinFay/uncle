import asyncio
import argparse
import os
from dotenv import load_dotenv
import agents # openai-agents
from agents.tools import mcp

# Assuming your oai_client.py structure is similar and can be adapted
# This will be a simplified version focusing on the query logic

async def get_p2p_user_activity_summary(user_address: str, user_registry_address: str, reputation_address: str, p2p_lending_address: str) -> str:
    """ 
    Instructs the AI agent to fetch, analyze, and summarize P2P activity for a user.
    """
    print(f"Analyzing P2P activity for user: {user_address}")
    print(f"P2P Contracts: UserRegistry={user_registry_address}, Reputation={reputation_address}, P2PLending={p2p_lending_address}")

    # 1. Initialize MCP Toolset (pointing to blockscout-mcp-server)
    blockscout_mcp_command = os.getenv("BLOCKSCOUT_MCP_COMMAND", "npx -y blockscout-mcp")
    mcp_server_params = mcp.StdioServerParameters(
        command=blockscout_mcp_command.split()[0],
        args=blockscout_mcp_command.split()[1:],
        env={"BLOCKSCOUT_API_URL": os.getenv("BLOCKSCOUT_API_URL")}
    )
    mcp_toolset = mcp.MCPToolset(name="blockscout_mcp", server_params=mcp_server_params)
    await mcp_toolset.start()
    print(f"Blockscout MCP Toolset started. Available tools: {await mcp_toolset.get_tools_json()}")

    # 2. Initialize Agent
    # Ensure OPENAI_API_KEY is in .env or environment
    llm_agent = agents.Agent(
        tools=[mcp_toolset],
        model="gpt-4-turbo", # or your preferred model
        # temperature=0.7,
    )

    # 3. Construct the complex query for the agent
    query = f"""
    Analyze the P2P lending activity for user address {user_address} 
    interacting with the following smart contracts:
    - UserRegistry: {user_registry_address}
    - Reputation: {reputation_address}
    - P2PLending: {p2p_lending_address}

    Follow these steps:
    1. Get all transactions for {user_address} using the get_address_transactions tool.
    2. From these transactions, identify those where the 'to' address is one of the P2P contract addresses listed above, or where {user_address} is the 'from' address and the 'to' address is one of the P2P contracts.
    3. For each of these relevant P2P transactions, get its event logs using the get_transaction_logs tool.
    4. Based on the decoded event logs (e.g., UserRegistered, LoanOfferCreated, LoanVouched, LoanRepaid, LoanDefaulted, ReputationUpdated from the P2P contracts), provide a concise summary of the user's lifecycle and key activities within this P2P system. Highlight how many loans they've created, participated in as a borrower or lender/voucher, and their repayment status if discernible.
    5. If no relevant P2P activity is found, state that clearly.
    Provide only the summary of activities.
    """

    print(f"\n--- Sending Query to Agent ---\n{query}
-----------------------------\n")

    # 4. Run the agent
    response_stream = llm_agent.arun(query)
    final_response = ""
    async for event in response_stream:
        if event.type == agents.events. pensiero.Text:
            print(event.text, end="", flush=True)
            final_response += event.text
        elif event.type == agents.events.tool.Call:
            print(f"\nTool Call: {event.tool_name} with args {event.arguments}")
        elif event.type == agents.events.tool.Result:
            print(f"\nTool Result for {event.tool_name}: {event.result}")
        elif event.type == agents.events.tool.Error:
            print(f"\nTool Error for {event.tool_name}: {event.error}")
        elif event.type == agents.events.Error:
            print(f"\nAgent Error: {event.error}")
            await mcp_toolset.stop()
            return f"Agent Error: {event.error}"
        elif event.type == agents.events.Final:
            print("\n--- Agent run completed ---")

    await mcp_toolset.stop()
    return final_response

async def main():
    parser = argparse.ArgumentParser(description="Analyze P2P user activity using Blockscout AI agent.")
    parser.add_argument("--user_address", required=True, help="The user's wallet address.")
    parser.add_argument("--user_registry_address", required=True, help="Deployed UserRegistry contract address.")
    parser.add_argument("--reputation_address", required=True, help="Deployed Reputation contract address.")
    parser.add_argument("--p2p_lending_address", required=True, help="Deployed P2PLending contract address.")

    args = parser.parse_args()

    load_dotenv(dotenv_path="../../.env") # Load from root .env
    # Ensure BLOCKSCOUT_API_URL and OPENAI_API_KEY are set
    if not os.getenv("OPENAI_API_KEY"):
        print("Error: OPENAI_API_KEY not found in environment or .env file.")
        return
    if not os.getenv("BLOCKSCOUT_API_URL"):
        print("Error: BLOCKSCOUT_API_URL not found in environment or .env file. Please set it to e.g. https://evm-testnet.flowscan.io/api")
        return

    summary = await get_p2p_user_activity_summary(
        args.user_address,
        args.user_registry_address,
        args.reputation_address,
        args.p2p_lending_address
    )
    print("\n--- P2P Activity Summary ---")
    print(summary)

if __name__ == "__main__":
    asyncio.run(main()) 