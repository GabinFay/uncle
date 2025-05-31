# frontend/app.py
import streamlit as st
import os
from dotenv import load_dotenv
from web3 import Web3

# Load environment variables from .env file
load_dotenv()

RPC_URL = os.getenv("RPC_URL")
# WARNING: Never commit actual private keys. This is for local testing only.
# For a real application, use a more secure key management solution.
DEPLOYER_PRIVATE_KEY = os.getenv("DEPLOYER_PRIVATE_KEY") 

# --- Contract Addresses (Replace with your actual deployed addresses) ---
# These would ideally be loaded from a config file or environment variables as well
USER_REGISTRY_ADDRESS = os.getenv("USER_REGISTRY_ADDRESS", "YOUR_USER_REGISTRY_CONTRACT_ADDRESS")
# P2P_LENDING_ADDRESS = os.getenv("P2P_LENDING_ADDRESS", "YOUR_P2P_LENDING_CONTRACT_ADDRESS")
# REPUTATION_ADDRESS = os.getenv("REPUTATION_ADDRESS", "YOUR_REPUTATION_CONTRACT_ADDRESS")

# --- Web3 Setup ---
try:
    if not RPC_URL:
        st.error("RPC_URL not found in .env file. Please set it.")
        st.stop()
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        st.error(f"Failed to connect to Ethereum node at {RPC_URL}. Please check the RPC_URL.")
        st.stop()
except Exception as e:
    st.error(f"Error connecting to Ethereum node: {e}")
    st.stop()

# --- Load Contract ABIs ---
# For simplicity, ABIs can be stored in files or defined directly as strings.
# In a larger project, you might have a script to copy ABIs from your contracts build directory.

USER_REGISTRY_ABI = """
[{"type":"constructor","inputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"getUserProfile","inputs":[{"name":"userAddress","type":"address","internalType":"address"}],"outputs":[{"name":"profile","type":"tuple","internalType":"struct UserRegistry.UserProfile","components":[{"name":"isWorldIdVerified","type":"bool","internalType":"bool"},{"name":"worldIdNullifierHash","type":"bytes32","internalType":"bytes32"},{"name":"reputationScore","type":"uint256","internalType":"uint256"},{"name":"filecoinDataPointer","type":"string","internalType":"string"}]}],"stateMutability":"view"},{"type":"function","name":"isUserWorldIdVerified","inputs":[{"name":"userAddress","type":"address","internalType":"address"}],"outputs":[{"name":"isVerified","type":"bool","internalType":"bool"}],"stateMutability":"view"},{"type":"function","name":"owner","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},{"type":"function","name":"registerOrUpdateUser","inputs":[{"name":"userAddress","type":"address","internalType":"address"},{"name":"worldIdNullifierHash_","type":"bytes32","internalType":"bytes32"}],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"renounceOwnership","inputs":[],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"transferOwnership","inputs":[{"name":"newOwner","type":"address","internalType":"address"}],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"updateFilecoinDataPointer","inputs":[{"name":"userAddress","type":"address","internalType":"address"},{"name":"filecoinDataPointer_","type":"string","internalType":"string"}],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"updateReputationScore","inputs":[{"name":"userAddress","type":"address","internalType":"address"},{"name":"newReputationScore","type":"uint256","internalType":"uint256"}],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"userProfiles","inputs":[{"name":"","type":"address","internalType":"address"}],"outputs":[{"name":"isWorldIdVerified","type":"bool","internalType":"bool"},{"name":"worldIdNullifierHash","type":"bytes32","internalType":"bytes32"},{"name":"reputationScore","type":"uint256","internalType":"uint256"},{"name":"filecoinDataPointer","type":"string","internalType":"string"}],"stateMutability":"view"},{"type":"function","name":"worldIdNullifierToAddress","inputs":[{"name":"","type":"bytes32","internalType":"bytes32"}],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},{"type":"event","name":"OwnershipTransferred","inputs":[{"name":"previousOwner","type":"address","indexed":true,"internalType":"address"},{"name":"newOwner","type":"address","indexed":true,"internalType":"address"}],"anonymous":false},{"type":"event","name":"UserProfileUpdated","inputs":[{"name":"userAddress","type":"address","indexed":true,"internalType":"address"}],"anonymous":false},{"type":"event","name":"UserRegistered","inputs":[{"name":"userAddress","type":"address","indexed":true,"internalType":"address"},{"name":"worldIdNullifierHash","type":"bytes32","indexed":true,"internalType":"bytes32"}],"anonymous":false},{"type":"error","name":"OwnableInvalidOwner","inputs":[{"name":"owner","type":"address","internalType":"address"}]},{"type":"error","name":"OwnableUnauthorizedAccount","inputs":[{"name":"account","type":"address","internalType":"address"}]}]
"""
# P2P_LENDING_ABI = """[YOUR_P2P_LENDING_ABI_JSON_STRING_HERE]"""
# REPUTATION_ABI = """[YOUR_REPUTATION_ABI_JSON_STRING_HERE]"""

# --- Helper Functions to Load Contracts (Add error handling) ---
def load_contract(address, abi):
    if not address or not abi or address.startswith("YOUR_") or abi.startswith("[YOUR") or abi == "[{\"type\":\"constructor\",\"inputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getUserProfile\",\"inputs\":[{\"name\":\"userAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"profile\",\"type\":\"tuple\",\"internalType\":\"struct UserRegistry.UserProfile\",\"components\":[{\"name\":\"isWorldIdVerified\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"worldIdNullifierHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"reputationScore\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"filecoinDataPointer\",\"type\":\"string\",\"internalType\":\"string\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isUserWorldIdVerified\",\"inputs\":[{\"name\":\"userAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isVerified\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"registerOrUpdateUser\",\"inputs\":[{\"name\":\"userAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"worldIdNullifierHash_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"updateFilecoinDataPointer\",\"inputs\":[{\"name\":\"userAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"filecoinDataPointer_\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"updateReputationScore\",\"inputs\":[{\"name\":\"userAddress\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"newReputationScore\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"userProfiles\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isWorldIdVerified\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"worldIdNullifierHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"reputationScore\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"filecoinDataPointer\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"worldIdNullifierToAddress\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UserProfileUpdated\",\"inputs\":[{\"name\":\"userAddress\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"UserRegistered\",\"inputs\":[{\"name\":\"userAddress\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"worldIdNullifierHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"OwnableInvalidOwner\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OwnableUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}]}]": # Check for placeholder ABI
        # st.warning(f"Contract address or ABI for {address} is not properly set.")
        return None
    try:
        return w3.eth.contract(address=address, abi=abi)
    except Exception as e:
        st.error(f"Error loading contract at {address}: {e}")
        return None

user_registry_contract = load_contract(USER_REGISTRY_ADDRESS, USER_REGISTRY_ABI)
# p2p_lending_contract = load_contract(P2P_LENDING_ADDRESS, P2P_LENDING_ABI)
# reputation_contract = load_contract(REPUTATION_ADDRESS, REPUTATION_ABI)

# --- Streamlit App Layout ---
st.set_page_config(layout="wide", page_title="CreditInclusion P2P Platform")
st.title("Decentralized Credit Inclusion Platform")
st.markdown("--- Manage Users, P2P Loans, and Reputation ---")

# --- User Registry Section ---
st.header("User Registry")

if user_registry_contract:
    st.subheader("Register User (Owner/World ID Sim)")
    reg_user_address = st.text_input("User Address to Register", key="reg_user_addr")
    reg_world_id_nullifier = st.text_input("World ID Nullifier Hash (Hex)", key="reg_world_id", value="0x" + "a"*64) # Example

    if st.button("Register/Update User"):
        if not DEPLOYER_PRIVATE_KEY:
            st.error("DEPLOYER_PRIVATE_KEY not set in .env. Cannot send transaction.")
        elif not Web3.is_address(reg_user_address):
            st.error("Invalid user address for registration.")
        elif not (reg_world_id_nullifier.startswith("0x") and len(reg_world_id_nullifier) == 66):
             st.error("Invalid World ID Nullifier Hash format. Must be 0x followed by 64 hex chars.")
        else:
            try:
                account = w3.eth.account.from_key(DEPLOYER_PRIVATE_KEY)
                nonce = w3.eth.get_transaction_count(account.address)
                world_id_bytes = Web3.to_bytes(hexstr=reg_world_id_nullifier)
                
                tx_hash = user_registry_contract.functions.registerOrUpdateUser(
                    reg_user_address, world_id_bytes
                ).transact({
                    'from': account.address,
                    'nonce': nonce,
                    'gas': 500000, # Adjust gas as needed
                    'gasPrice': w3.eth.gas_price
                })
                st.success(f"User registration transaction sent! Hash: {tx_hash.hex()}")
                st.info("Waiting for transaction receipt...")
                receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
                st.success(f"User registered/updated successfully! Block: {receipt.blockNumber}")
            except Exception as e:
                st.error(f"Error registering user: {e}")

    st.subheader("Check User Verification Status")
    check_user_address = st.text_input("User Address to Check", key="check_user_addr")
    if st.button("Check Status"):
        if Web3.is_address(check_user_address):
            try:
                is_verified = user_registry_contract.functions.isUserWorldIdVerified(check_user_address).call()
                profile = user_registry_contract.functions.getUserProfile(check_user_address).call()
                st.write(f"Is Verified: {is_verified}")
                st.write(f"Profile (Raw): {profile}") 
                # Profile fields: [isWorldIdVerified, worldIdNullifierHash, reputationScore, filecoinDataPointer]
                st.write(f"  World ID Verified in profile: {profile[0]}")
                st.write(f"  Nullifier Hash in profile: {profile[1].hex() if isinstance(profile[1], bytes) else profile[1]}")

            except Exception as e:
                st.error(f"Error checking user status: {e}")
        else:
            st.warning("Please enter a valid Ethereum address.")
else:
    st.warning("UserRegistry contract not loaded. Please check address and ABI in app.py and ensure ABI is valid JSON.")

# --- P2P Lending Section (Placeholder) ---
# st.header("P2P Lending")
# if p2p_lending_contract:
#     st.write("P2P Lending interactions here...")
# else:
#     st.warning("P2PLending contract not loaded. Please check address and ABI.")

# --- Reputation Section (Placeholder) ---
# st.header("Reputation System")
# if reputation_contract:
#     st.write("Reputation System interactions here...")
# else:
#     st.warning("Reputation contract not loaded. Please check address and ABI.")


st.sidebar.header("Connection Info")
st.sidebar.text(f"RPC URL: {RPC_URL}")
st.sidebar.text(f"Connected: {w3.is_connected() if 'w3' in locals() else False}")
if 'w3' in locals() and w3.is_connected():
    st.sidebar.text(f"Chain ID: {w3.eth.chain_id}")
    if DEPLOYER_PRIVATE_KEY:
        st.sidebar.text(f"Signer Address: {w3.eth.account.from_key(DEPLOYER_PRIVATE_KEY).address}")
    else:
        st.sidebar.warning("DEPLOYER_PRIVATE_KEY not set.")

st.sidebar.header("Contract Addresses")
st.sidebar.caption(f"UserRegistry: {USER_REGISTRY_ADDRESS}")
# st.sidebar.caption(f"P2PLending: {P2P_LENDING_ADDRESS}")
# st.sidebar.caption(f"Reputation: {REPUTATION_ADDRESS}") 