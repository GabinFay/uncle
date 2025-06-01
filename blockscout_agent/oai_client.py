import asyncio
import os
import logging
import argparse # Added for command-line arguments
from dotenv import load_dotenv

from agents import Agent, Runner #, gen_trace_id, trace # Tracing might require more setup
from agents.mcp import MCPServer, MCPServerStdio

# Load environment variables from .env file
# This script is in blockscout_agent, so .env should be in the same directory
dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path=dotenv_path, override=True)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Deployed contract addresses on Flow EVM Testnet (after --slow deployment 2025-05-31)
USER_REGISTRY_ADDRESS = "0xa69F055d1A40938CcB4A76fc0b958E8A1cd376f6"
REPUTATION_ADDRESS = "0xcef24c74B23C6257bf7C72528885100f8946EA80"
P2P_LENDING_ADDRESS = "0x4c5B41AE6a549DF120DDdAfaC6F227BE23B9885E"
MDR_TOKEN_ADDRESS = "0xc9F0D37b20Ff5430BC8d5758b93A854Fcf39a4C2" # MockDollar

# Test User Addresses (ensure these are funded with testnet currency and MDR if needed for tests)
# USER_A_ADDRESS (Deployer) - From contracts/.env DEPLOYER_ADDRESS
USER_A_ADDRESS = "0xc15f5700cC83830139440eE7B7f96662128405B3"
# USER_B_ADDRESS (Borrower) - From contracts/.env BORROWER_ADDRESS_STR
USER_B_ADDRESS = "0x4ddB3e81434cb130512edaa04092E5b17297f1c5"

LOAN_AGREEMENT_ID_EXAMPLE = "0x0000000000000000000000000000000000000000000000000000000000000000" # Placeholder, needs actual ID from testing

# --- P2P Contract Interaction Test Cases ---
# These queries are designed to test the P2P contracts deployed on Flow EVM Testnet.
# They assume the contracts have been deployed and addresses are correctly set above.
# They also assume USER_A_ADDRESS is the deployer/owner and USER_B_ADDRESS is a test borrower.

p2p_test_cases = [
    {
        "name": "UserRegistry: Check registration status of USER_A on Flow EVM Testnet",
        "query_text": f"Has address {USER_A_ADDRESS} been registered in the UserRegistry contract at {USER_REGISTRY_ADDRESS} on the Flow EVM Testnet? If so, what is their World ID Nullifier Hash according to the 'UserRegistered' events? Only use the get_address_logs tool."
    },
    {
        "name": "Reputation: Get recent reputation updates for USER_B on Flow EVM Testnet",
        "query_text": f"Show the recent 'ReputationUpdated' event logs for address {USER_B_ADDRESS} from the Reputation contract at {REPUTATION_ADDRESS} on the Flow EVM Testnet. What were the reasons and new scores? Only use the get_address_logs tool."
    },
    {
        "name": "Reputation: List vouches given by VOUCHER_A (USER_A) on Flow EVM Testnet",
        "query_text": f"List the 'VouchAdded' event logs where {USER_A_ADDRESS} is the voucher, from the Reputation contract at {REPUTATION_ADDRESS} on the Flow EVM Testnet. Who did they vouch for and with what tokens/amounts? Only use the get_address_logs tool."
    },
    {
        "name": "P2PLending: List recent LoanOfferCreated events on Flow EVM Testnet",
        "query_text": f"List the 5 most recent 'LoanOfferCreated' event logs from the P2PLending contract at {P2P_LENDING_ADDRESS} on the Flow EVM Testnet. For each offer, state the lender, amount, token (should be MDR: {MDR_TOKEN_ADDRESS}), interest rate, and duration. Only use the get_address_logs tool."
    },
    {
        "name": "P2PLending: Find LoanAgreementFormed events for BORROWER_A (USER_B) on Flow EVM Testnet",
        "query_text": f"Search for 'LoanAgreementFormed' event logs where {USER_B_ADDRESS} is the borrower, from the P2PLending contract at {P2P_LENDING_ADDRESS} on the Flow EVM Testnet. List any agreements found. Only use the get_address_logs tool."
    },
    {
        "name": "P2PLending: Check status of a specific loan agreement via LoanRepaymentMade or LoanAgreementDefaulted on Flow EVM Testnet",
        "query_text": f"For loan agreement ID 0x0000000000000000000000000000000000000000000000000000000000000000 from the P2PLending contract at {P2P_LENDING_ADDRESS} on the Flow EVM Testnet, check for 'LoanRepaymentMade' or 'LoanAgreementDefaulted' events. Summarize its repayment or default status based on these events. Only use the get_address_logs tool."
    },
    {
        "name": "Combined: BORROWER_A (USER_B)'s reputation and P2P loan default status on Flow EVM Testnet",
        "query_text": f"First, get 'ReputationUpdated' events for user {USER_B_ADDRESS} from the Reputation contract at {REPUTATION_ADDRESS} on the Flow EVM Testnet to understand their latest reputation score. Second, get 'LoanAgreementDefaulted' events where {USER_B_ADDRESS} is the borrower from the P2PLending contract at {P2P_LENDING_ADDRESS} on the Flow EVM Testnet. Based on these, what is {USER_B_ADDRESS}'s latest known reputation score and do they have any recorded defaulted loans? Use only the get_address_logs tool for each contract, and call it only once per contract."
    }
]

async def run_single_query(agent: Agent, query_text: str, query_name: str = "Single Query"):
    logging.info(f"\n--- Running OpenAI Single Query: {query_name} ---")
    print(f"\n--- Running OpenAI Single Query: {query_name} ---")
    print(f"Query: {query_text}")
    try:
        result = await Runner.run(starting_agent=agent, input=query_text)
        logging.info(f"OpenAI Agent final output for query '{query_name}': {result.final_output}")
        print(f"\nFinal Agent Response to query '{query_name}':\n{result.final_output}")
    except Exception as e:
        logging.error(f"Error during OpenAI Agent run for query '{query_name}': {e}", exc_info=True)
        print(f"\nError during OpenAI Agent run for query '{query_name}': {e}")
    print("-----------------------------------------------------")

async def run_openai_agent_tests(blockscout_mcp_server: MCPServer, single_query: str | None = None): # Modified
    agent = Agent(
        name="BlockscoutOpenAIAgent",
        instructions="You are an AI assistant that can query blockchain data using Blockscout. Use the available tools to answer user questions about transactions, addresses, blocks, and tokens. Be precise and refer to the tool outputs. When asked for a specific field from an event log (e.g. offerId), provide only that value if found, otherwise state it's not found.", # Added instruction for specific field
        mcp_servers=[blockscout_mcp_server],
        model="gpt-4-turbo"
    )

    if single_query: # Added condition
        await run_single_query(agent, single_query, "CLI Specified Query")
    else:
        for i, test_case in enumerate(p2p_test_cases):
            await run_single_query(agent, test_case['query_text'], test_case['name'])
            if i < len(p2p_test_cases) - 1:
                logging.info("Pausing for 5 seconds before next query...")
                print("Pausing for 5 seconds before next query...")
                await asyncio.sleep(5)

async def main():
    parser = argparse.ArgumentParser(description="Run Blockscout OpenAI Agent tests.") # Added argument parser
    parser.add_argument("--single-query", type=str, help="Run a single query string instead of all test cases.")
    args = parser.parse_args()

    openai_api_key = os.getenv("OPENAI_API_KEY")
    if not openai_api_key or not openai_api_key.startswith("sk-"):
        logging.error("CRITICAL: OPENAI_API_KEY environment variable not set correctly or is not a secret key.")
        print("\nExiting: OPENAI_API_KEY is missing or invalid. Please set it in blockscout_agent/.env")
        return

    blockscout_api_url = os.getenv("BLOCKSCOUT_API_URL")
    if not blockscout_api_url:
        logging.error("CRITICAL: BLOCKSCOUT_API_URL environment variable not set.")
        print("\nExiting: BLOCKSCOUT_API_URL is missing. Please set it in blockscout_agent/.env")
        return

    logging.info(f"Using OPENAI_API_KEY: ...{openai_api_key[-4:] if openai_api_key else 'Not Set'}")
    logging.info(f"Using BLOCKSCOUT_API_URL (from os.getenv after dotenv.load_dotenv): {blockscout_api_url}")
    # logging.info(f"Targeting Blockscout at: {blockscout_api_url} for P2P queries.") # Redundant

    # Ensure the correct, most recently loaded blockscout_api_url is passed to the subprocess env
    mcp_env = os.environ.copy() # Start with current environment that includes .env variables
    mcp_env["BLOCKSCOUT_API_URL"] = blockscout_api_url # Explicitly set/override for clarity and safety

    print(f"BLOCKSCOUT_API_URL that will be passed to MCPServerStdio env: {mcp_env.get('BLOCKSCOUT_API_URL')}")

    blockscout_server = MCPServerStdio(
        name="BlockscoutMCPviaNPX",
        params={
            "command": "npx",
            "args": ["-y", "blockscout-mcp"],
            # "command": command_str, # Use the full command string with env var
            # "args": [], # Args are now part of the command string
            "cwd": os.path.dirname(os.path.abspath(__file__)), # Run npx from blockscout_agent dir
            "env": mcp_env # Pass the modified environment
        },
    )

    async with blockscout_server as bs_server:
        # trace_id = gen_trace_id() # Tracing requires OpenAI platform setup
        # with trace(workflow_name="Blockscout OpenAI Agent MCP Test", trace_id=trace_id):
        # print(f"View trace (if configured): https://platform.openai.com/traces/trace?trace_id={trace_id}\n")
        logging.info("Blockscout OpenAI Agent with MCP server is ready for P2P queries.")
        print("\nBlockscout OpenAI Agent starting P2P contract queries...")
        await run_openai_agent_tests(bs_server, args.single_query) # Pass single_query arg

if __name__ == "__main__":
    print(f"Current working directory: {os.getcwd()}")
    print(f"Dotenv path being loaded: {dotenv_path}")
    print("Starting Blockscout OpenAI Agent client for P2P queries...")
    asyncio.run(main()) 