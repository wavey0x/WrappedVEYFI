import math, time, brownie
from brownie import Contract, web3, ZERO_ADDRESS


def test_sale(yfi, veyfi, user, buyer, wrapper, market):
    # Prepare seller
    tx = wrapper.setTransferCondition(market, {'from':user})
    assert tx.events['Registered']['forSale'] == True

    # Prepare buyer
    yfi.approve(market, 2**256-1, {'from':buyer})
    tx = market.buy(wrapper, {'from':buyer})

    # Outputs
    price = tx.events['Buy']['purchasePrice']
    locked_amount = veyfi.locked(wrapper)['amount']
    tx = veyfi.withdraw({'from':wrapper})
    withdrawable = tx.events['Withdraw']['amount']

    # Compare
    print(f'Total locked amount: {locked_amount/1e18}')
    print(f'Purchase Price: {price/1e18}')
    print(f'Withdrawable after penalty: {withdrawable/1e18}')