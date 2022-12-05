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


interface VoteEscrow {
    struct LockedBalance {
        uint amount;
        uint end;
    }
    function modify_lock(uint amount, uint unlock_time) external;
    function increase_amount(uint) external;
    function withdraw() external;
    function locked(address user) external view returns (LockedBalance memory);
}

contract WrappedVEYFI {
    
    address constant public YFI = address(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    
    address constant public VEYFI = address(0x90c1f9220d90d3966FbeE24045EDd73E1d588aD5);
    
    address public owner;
    address public conditionContract;
    address public controller;
    
    constructor() {
        owner = msg.sender;
        IERC20(YFI).approve(VEYFI, type(uint).max);
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
    
    function withdraw(bool acceptPenalty) external {
        require(msg.sender == controller || msg.sender == owner, "!authorized");
        uint lockEnd = VoteEscrow(VEYFI).locked(address(this)).end;
        if ((lockEnd > block.timestamp && acceptPenalty) || lockEnd < block.timestamp){
            VoteEscrow(VEYFI).withdraw();
        }
    }
    
    function balanceOfWant() public view returns (uint) {
        return IERC20(YFI).balanceOf(address(this));
    }
    
    function transferOwnership(address _owner, bool keepCondition) external {
        require(msg.sender == owner || msg.sender == conditionContract, "!owner");
        owner = _owner;
        /// @dev reset this after each transfer so that condition becomes unavailable
        if (!keepCondition){
            conditionContract = address(0);
        }
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