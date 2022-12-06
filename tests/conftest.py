import pytest, requests
from brownie import ZERO_ADDRESS, accounts, config, Contract, interface, WrappedVEYFI, VeMarket, web3, chain

# This causes test not to re-run fixtures on each run
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

@pytest.fixture
def gov(accounts):
    yield accounts.at("0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52", force=True)
    #yield accounts.at("0x6AFB7c9a6E8F34a3E0eC6b734942a5589A84F44C", force=True)

@pytest.fixture
def yfi():
    yield Contract("0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e")

@pytest.fixture
def veyfi():
    yield interface.IVEYFI('0x90c1f9220d90d3966FbeE24045EDd73E1d588aD5')

@pytest.fixture
def user(accounts, yfi):
    user = accounts[0]
    yield user

@pytest.fixture
def wrapper(user, yfi):
    wrapper = user.deploy(WrappedVEYFI)
    # Create lock
    whale = accounts.at('0xF977814e90dA44bFA03b6295A0616a897441aceC', force=True)
    yfi.transfer(wrapper,10e18,{'from':whale})
    time = chain.time() + (60 * 60 * 24 * 365 * 1)
    wrapper.modifyLock(10e18, time, {'from': user})
    yield wrapper

@pytest.fixture
def market(user):
    yield user.deploy(VeMarket)

@pytest.fixture
def buyer(accounts, yfi):
    buyer = accounts[1]
    whale = accounts.at('0xF977814e90dA44bFA03b6295A0616a897441aceC', force=True)
    yfi.transfer(buyer,50e18,{'from':whale})
    yield buyer