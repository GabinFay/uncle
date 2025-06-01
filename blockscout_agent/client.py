import asyncio
import os
import logging
from dotenv import load_dotenv
from google.genai import types
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService

# Load environment variables from .env file in the current directory (blockscout_agent)
# This ensures that agent.py (which is in the same dir) also picks up these vars when imported.
dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path=dotenv_path)

# Now import agent now that .env is loaded for it
from agent import get_agent_async, MCPToolset

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# --- Deployed Contract Addresses on WorldChain Sepolia Testnet ---
USER_REGISTRY_CONTRACT = "0x7D6183146cdc682E004A1dad84636c1ccd892EcC"
REPUTATION_CONTRACT = "0xef9a0281DBFE7eb05710640d94d18C91480b47f3"
P2P_LENDING_CONTRACT = "0x4491eCbe72569f718977C7cDee251237152bd4A0"
# MOCK_REPUTATION_OAPP_CONTRACT = "0x1A22Bd93d7569785f40f75cf8bE41b0469c0C816" # Not directly queried by agent

# User addresses for testing queries on WorldChain Sepolia
# USER_A is the deployer address
USER_A = "0xc15f5700cC83830139440eE7B7f96662128405B3"
# USER_B is the BORROWER_ADDRESS provided by the user
USER_B = "0x4ddB3e81434cb130512edaa04092E5b17297f1c5"
# VOUCHER_A can be the same as USER_A (deployer) for initial tests
VOUCHER_A = "0xc15f5700cC83830139440eE7B7f96662128405B3"
# BORROWER_A is the BORROWER_ADDRESS provided by user
BORROWER_A = "0x4ddB3e81434cb130512edaa04092E5b17297f1c5"

# Placeholder for a loan agreement ID - will need to be obtained from actual contract interaction
LOAN_AGREEMENT_ID_EXAMPLE = "0x0000000000000000000000000000000000000000000000000000000000000000" # Update after creating an agreement

async def run_test_queries(runner, session, agent_name):
    # p2p_contract_queries = [
    #     {
    #         "description": "WorldChain Sepolia: Get details for the latest block (SIMPLE TEST)",
    #         "query_text": "Get details for the latest block on the current network (WorldChain Sepolia)."
    #     },
    #     # --- UserRegistry.sol Queries ---
    #     {
    #         "description": "UserRegistry: Check registration status of USER_A on WorldChain Sepolia",
    #         "query_text": f"Has address {USER_A} been registered in the UserRegistry contract at {USER_REGISTRY_CONTRACT} on the WorldChain Sepolia testnet? If so, what is their World ID Nullifier Hash according to the 'UserRegistered' events? Only use the get_address_logs tool."
    #     },
    #     # --- Reputation.sol Queries ---
    #     {
    #         "description": "Reputation: Get recent reputation updates for USER_B on WorldChain Sepolia",
    #         "query_text": f"Show the recent 'ReputationUpdated' event logs for address {USER_B} from the Reputation contract at {REPUTATION_CONTRACT} on the WorldChain Sepolia testnet. What were the reasons and new scores? Only use the get_address_logs tool."
    #     },
    #     {
    #         "description": "Reputation: List vouches given by VOUCHER_A on WorldChain Sepolia",
    #         "query_text": f"List the 'VouchAdded' event logs where {VOUCHER_A} is the voucher, from the Reputation contract at {REPUTATION_CONTRACT} on the WorldChain Sepolia testnet. Who did they vouch for and with what tokens/amounts? Only use the get_address_logs tool."
    #     },
    #     # --- P2PLending.sol Queries ---
    #     {
    #         "description": "P2PLending: List recent LoanOfferCreated events on WorldChain Sepolia",
    #         "query_text": f"List the 5 most recent 'LoanOfferCreated' event logs from the P2PLending contract at {P2P_LENDING_CONTRACT} on the WorldChain Sepolia testnet. For each offer, state the lender, amount, token, interest rate, and duration. Only use the get_address_logs tool."
    #     },
    #     {
    #         "description": "P2PLending: Find LoanAgreementFormed events for BORROWER_A on WorldChain Sepolia",
    #         "query_text": f"Search for 'LoanAgreementFormed' event logs where {BORROWER_A} is the borrower, from the P2PLending contract at {P2P_LENDING_CONTRACT} on the WorldChain Sepolia testnet. List any agreements found. Only use the get_address_logs tool."
    #     },
    #     {
    #         "description": "P2PLending: Check status of a specific loan agreement via LoanRepaymentMade or LoanAgreementDefaulted on WorldChain Sepolia",
    #         "query_text": f"For loan agreement ID {LOAN_AGREEMENT_ID_EXAMPLE} from the P2PLending contract at {P2P_LENDING_CONTRACT} on the WorldChain Sepolia testnet, check for 'LoanRepaymentMade' or 'LoanAgreementDefaulted' events. Summarize its repayment or default status based on these events. Only use the get_address_logs tool."
    #     },
    #     # --- Combined/Complex Query Example ---
    #     {
    #         "description": "Combined: BORROWER_A's reputation and P2P loan default status on WorldChain Sepolia",
    #         "query_text": (
    #             f"First, get 'ReputationUpdated' events for user {BORROWER_A} from the Reputation contract at {REPUTATION_CONTRACT} on the WorldChain Sepolia testnet to understand their latest reputation score. "
    #             f"Second, get 'LoanAgreementDefaulted' events where {BORROWER_A} is the borrower from the P2PLending contract at {P2P_LENDING_CONTRACT} on the WorldChain Sepolia testnet. "
    #             f"Based on these, what is {BORROWER_A}'s latest known reputation score and do they have any recorded defaulted loans? Use only the get_address_logs tool for each contract, and call it only once per contract."
    #         )
    #     }
    # ]
    
    flow_evm_test_queries = [
        {
            "description": "Flow EVM Testnet: Get details for the latest block",
            "query_text": "Get details for the latest block on the current network."
        }
    ]

    # Select which set of queries to run
    # active_queries = p2p_contract_queries # To run P2P tests on WorldChain Sepolia
    active_queries = flow_evm_test_queries
    # active_queries = queries # To run old general tests

    for i, test_case in enumerate(active_queries):
        logging.info(f"\n--- Running Test Query {i+1}: {test_case['description']} ---")
        print(f"\n--- Running Test Query {i+1}: {test_case['description']} ---")
        print(f"Query: {test_case['query_text']}")
        
        content = types.Content(role='user', parts=[types.Part(text=test_case['query_text'])])

        logging.info("Running agent with test query...")
        events_async = runner.run_async(
            session_id=session.id, 
            user_id=session.user_id, 
            new_message=content
        )

        final_response_text = ""
        async for event in events_async:
            logging.info(f"Event received from author: {event.author}")
            print(f"Event from: {event.author}")

            function_calls = event.get_function_calls()
            if function_calls:
                print(f"  Type: Tool Call Request")
                for call in function_calls:
                    tool_name = call.name
                    tool_args = call.args
                    print(f"    Tool: {tool_name}, Args: {tool_args}")
                    logging.info(f"Agent requests tool call: {tool_name} with args: {tool_args}")
            
            function_responses = event.get_function_responses()
            if function_responses:
                print(f"  Type: Tool Execution Result")
                for resp in function_responses:
                    tool_name = resp.name
                    print(f"    Tool: {tool_name}, Output: (Output logged)")
                    logging.info(f"Tool output ({tool_name}): {resp.response}")

            if event.author == agent_name and not function_calls and not function_responses:
                if event.content and event.content.parts:
                    print(f"  Type: LLM Text Response")
                    current_response_part = ""
                    for part in event.content.parts:
                        if hasattr(part, 'text') and part.text:
                            print(f"    LLM Response Part: {part.text}")
                            current_response_part += part.text
                    final_response_text += current_response_part
                    logging.info(f"LLM Response part from {agent_name}: {current_response_part}")
                else:
                    logging.info(f"Event from {agent_name} without function calls/responses or text parts: {event}")

        print(f"\nFinal Agent Response to query '{test_case['description']}':\n{final_response_text}")
        logging.info(f"Final Agent Response to query '{test_case['description']}': {final_response_text}")
        print("-----------------------------------------------------")
        if i < len(active_queries) - 1:
            print("Pausing for a few seconds before next query...")
            await asyncio.sleep(5) # Pause to allow MCP server to reset or handle back-to-back calls gracefully

async def async_main():
    google_api_key = os.getenv("GOOGLE_API_KEY")
    if not google_api_key or google_api_key == "YOUR_KEY_HERE":
        logging.error("CRITICAL: GOOGLE_API_KEY environment variable not set or is a placeholder.")
        logging.error("Please create/update 'blockscout_agent/.env' with your actual Google API Key.")
        print("\nExiting: GOOGLE_API_KEY is missing or invalid. Please set it in blockscout_agent/.env")
        return

    blockscout_url = os.getenv("BLOCKSCOUT_API_URL")
    if not blockscout_url:
        logging.error("CRITICAL: BLOCKSCOUT_API_URL environment variable not set.")
        logging.error("Please create/update 'blockscout_agent/.env' with a valid Blockscout API URL (e.g., https://eth.blockscout.com/api).")
        print("\nExiting: BLOCKSCOUT_API_URL is missing. Please set it in blockscout_agent/.env")
        return

    logging.info(f"Using GOOGLE_API_KEY: ...{google_api_key[-4:] if google_api_key else 'Not Set'}")
    logging.info(f"Using BLOCKSCOUT_API_URL: {blockscout_url}")
    logging.info("IMPORTANT: If testing with contracts on a testnet (e.g., Sepolia), ensure BLOCKSCOUT_API_URL in .env points to the correct Blockscout API for that testnet (e.g., https://eth-sepolia.blockscout.com/api).")
    logging.info(f"IMPORTANT: Contract addresses in client.py are set for WorldChain Sepolia: UR: {USER_REGISTRY_CONTRACT}, Rep: {REPUTATION_CONTRACT}, P2P: {P2P_LENDING_CONTRACT}")

    session_service = InMemorySessionService()
    session = session_service.create_session(
        state={}, app_name='blockscout_agent_app', user_id='user_blockscout'
    )
    
    root_agent, exit_stack = await get_agent_async()

    if not root_agent:
        logging.error("Agent could not be initialized. Check previous logs for errors (e.g., MCP server connection, API keys).")
        if exit_stack: # Should be None if agent is None, but just in case
            await exit_stack.aclose()
        return

    agent_name = root_agent.name # Get the agent's name for identifying its responses

    runner = Runner(
        app_name='blockscout_agent_app',
        agent=root_agent,
        session_service=session_service,
    )

    logging.info("Blockscout AI Agent is ready for non-interactive test.")
    print("\nBlockscout AI Agent starting non-interactive test...")

    try:
        await run_test_queries(runner, session, agent_name)
    except KeyboardInterrupt:
        logging.info("User interrupted the session (Ctrl+C).")
    except Exception as e:
        logging.error(f"An unexpected error occurred in the client: {e}", exc_info=True)
    finally:
        if exit_stack:
            logging.info("Closing MCP server connection and cleaning up resources...")
            await exit_stack.aclose()
            logging.info("Cleanup complete.")
        else:
            logging.info("No active MCP connection to close.")
        print("\nSession ended.")

if __name__ == "__main__":
    # Ensure the .env file is in the same directory as this client.py for execution.
    # If you run this from the root of the workspace, adjust path or ensure .env is also in root.
    print(f"Current working directory: {os.getcwd()}")
    print(f"Dotenv path being loaded: {dotenv_path}")
    print("Starting Blockscout AI Agent client...")
    
    # Check for GOOGLE_API_KEY before even starting asyncio loop, as agent.py will also check
    # This provides an earlier, more user-friendly exit if keys are missing.
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key or api_key == "YOUR_KEY_HERE":
        print("CRITICAL: GOOGLE_API_KEY environment variable not set or is a placeholder.")
        print(f"Please create/update '{dotenv_path}' with your actual Google API Key.")
        print("You can obtain a Google API Key from Google AI Studio: https://aistudio.google.com/app/apikey")
        print("\nIMPORTANT: Remember to also update placeholder contract addresses at the top of this script with your deployed P2P contract addresses.")
    else:
        # Also check BLOCKSCOUT_API_URL before running
        blockscout_api = os.getenv("BLOCKSCOUT_API_URL")
        if not blockscout_api:
            print("CRITICAL: BLOCKSCOUT_API_URL environment variable not set.")
            print(f"Please create/update '{dotenv_path}' with a valid Blockscout API URL (e.g., https://eth.blockscout.com/api).")
        else:
            print("\nIMPORTANT: Remember to update placeholder contract addresses at the top of this script (client.py) with your deployed P2P contract addresses.")
            print(f"IMPORTANT: BLOCKSCOUT_API_URL in .env is set to: {blockscout_api}")
            print(f"IMPORTANT: Contract addresses in client.py are now set for WorldChain Sepolia testnet.")
            print(f"  UserRegistry: {USER_REGISTRY_CONTRACT}")
            print(f"  Reputation: {REPUTATION_CONTRACT}")
            print(f"  P2PLending: {P2P_LENDING_CONTRACT}")
            print(f"  Test User A (Deployer/Voucher): {USER_A}")
            print(f"  Test User B (Borrower): {USER_B}")
            print("Ensure these test users have test ETH on WorldChain Sepolia if they need to interact with contracts for your queries to yield results (e.g., creating offers, loans).")
            asyncio.run(async_main()) 