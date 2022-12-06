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
    function balanceOf(address) external view returns (uint);
    function locked(address user) external view returns (LockedBalance memory);
}

interface WrappedVeYFI {
    function transferOwnership(address owner, address newConditionContract, address newController) external;
    function owner() external returns (address);
    function operator() external returns (address);
}

contract VeMarket {
    event Registered(bool indexed forSale, address indexed position);
    event Buy(address indexed position, address indexed buyer, address indexed seller, uint purchasePrice);
    event Debug(uint timeleft, uint ratio);

    uint constant internal WEEK = 7 days;
    IERC20 constant public YFI = IERC20(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    VoteEscrow constant public VEYFI = VoteEscrow(0x90c1f9220d90d3966FbeE24045EDd73E1d588aD5);
    uint constant internal MAX_LOCK_DURATION = 4 * 365 days / WEEK * WEEK; // 4 years
    uint constant internal SCALE = 10 ** 18;
    uint constant internal MAX_PENALTY_RATIO = SCALE * 3 / 4;  // 75% for early exit of max lock
    uint constant public DISCOUNT = 1_000; // 10%
    uint constant internal PRECISION = 10_000;
    address public conditionContract;
    address public controller;
    mapping(address => bool) public forSale;
    
    constructor() {}

    function buy(address position) external noReentry {
        uint amount = VEYFI.locked(position).amount;
        require(amount > 0, 'No balance');
        require(forSale[position],'Not For Sale');
        // DO SOME BYTECODE VALIDATION ON THE WRAPPER HERE TO PROTECT AGAINST SPOOF WRAPPERS

        address seller = WrappedVeYFI(position).owner();
        uint purchasePrice = _getPurchasePrice(position, amount);
        require(purchasePrice > 0);
        YFI.transferFrom(msg.sender, seller, purchasePrice);
        WrappedVeYFI(position).transferOwnership(msg.sender, address(0), address(0));
        require(WrappedVeYFI(position).owner() == msg.sender);
        forSale[position] = false;
        emit Buy(position, msg.sender, seller, purchasePrice);
        emit Registered(false, msg.sender);
    }

    function getPurchasePrice(address position) public view returns (uint) {
        uint amount = VEYFI.locked(position).amount;
        if (amount == 0) return 0;
        if (!forSale[position]) return 0;
        return _getPurchasePrice(position, amount);
    }
    
    function _getPurchasePrice(address position, uint amount) internal view returns (uint) {
        uint expectedPenalty = calculatePenalty(position);
        return (
            amount -
            expectedPenalty + 
            (expectedPenalty * DISCOUNT / PRECISION)
        );
    }

    function register() external {
        // DO SOME BYTECODE VALIDATION ON THE WRAPPER HERE TO PROTECT AGAINST SPOOF WRAPPERS
        require(VEYFI.locked(msg.sender).end > 0);
        if (!forSale[msg.sender]){
            forSale[msg.sender] = true;
            emit Registered(true, msg.sender);
        }
    }

    function unregister() external {
        // DO SOME BYTECODE VALIDATION ON THE WRAPPER HERE TO PROTECT AGAINST SPOOF WRAPPERS
        require(VEYFI.locked(msg.sender).end > 0);
        if (forSale[msg.sender]){
            forSale[msg.sender] = false;
            emit Registered(false, msg.sender);
        }
    }

    function calculatePenalty(address user) public view returns (uint) {
        VoteEscrow.LockedBalance memory lockInfo = VEYFI.locked(user);
        if (lockInfo.amount == 0) return 0;
        if (lockInfo.end > block.timestamp){
            uint timeLeft = min(lockInfo.end - block.timestamp, MAX_LOCK_DURATION);
            uint penaltyRatio = min(timeLeft * SCALE / MAX_LOCK_DURATION, MAX_PENALTY_RATIO);
            return lockInfo.amount * penaltyRatio / SCALE;
        }
        return 0;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    bool private lock = false;
    modifier noReentry() {
        require(lock == false);
        lock = true;
        _;
        lock = false;
    }
}