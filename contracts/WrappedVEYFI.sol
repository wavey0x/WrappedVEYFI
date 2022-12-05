pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }
    function toPayable(address account) internal pure returns (address payable) {
        return payable(address(uint160(account)));
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


interface VoteEscrow {
    function modify_lock(uint amount, uint unlock_time) external;
    function increase_amount(uint) external;
    function withdraw() external;
}

contract WrappedVEYFI {
    using SafeERC20 for IERC20;
    using Address for address;
    
    address constant public YFI = address(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    
    address constant public VEYFI = address(0x90c1f9220d90d3966FbeE24045EDd73E1d588aD5);
    
    address public owner;
    address public conditionContract;
    address public controller;
    
    constructor() {
        owner = msg.sender;
        IERC20(YFI).safeApprove(VEYFI, type(uint).max);
    }
    
    function getName() external pure returns (string memory) {
        return "VEYFIWrapper";
    }
    
    function setController(address _controller) external {
        require(msg.sender == owner, "!owner");
        controller = _controller;
    }
    
    function modifyLock(uint _amount, uint _unlockTime) external {
        require(msg.sender == controller || msg.sender == owner, "!authorized");
        VoteEscrow(VEYFI).modify_lock(_amount, _unlockTime);
    }
    
    function increaseAmount(uint _value) external {
        require(msg.sender == controller || msg.sender == owner, "!authorized");
        VoteEscrow(VEYFI).increase_amount(_value);
    }
    
    function release() external {
        require(msg.sender == controller || msg.sender == owner, "!authorized");
        VoteEscrow(VEYFI).withdraw();
    }
    
    function balanceOfWant() public view returns (uint) {
        return IERC20(YFI).balanceOf(address(this));
    }
    
    function transferOwnership(address _owner) external {
        require(msg.sender == owner || msg.sender == conditionContract, "!owner");
        owner = _owner;
    }

    function setTransferCondition(address _conditionContract) external {
        require(msg.sender == owner, "!owner");
        conditionContract = _conditionContract;
    }
    
    function execute(address to, uint value, bytes calldata data) external returns (bool, bytes memory) {
        require(msg.sender == controller || msg.sender == owner, "!authorized");
        (bool success, bytes memory result) = to.call{value: value}(data);
        
        return (success, result);
    }
}