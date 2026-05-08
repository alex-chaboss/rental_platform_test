pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  mapping(address => mapping(address => uint256)) private _allowances;
  mapping(address => uint256) private _withdrawableDividends;
  address[] private _holders;
  mapping(address => uint256) private _holderIndexPlusOne;

  function _addHolderIfNeeded(address account) private {
    if (account == address(0)) {
      return;
    }

    if (balanceOf[account] > 0 && _holderIndexPlusOne[account] == 0) {
      _holders.push(account);
      _holderIndexPlusOne[account] = _holders.length;
    }
  }

  function _removeHolderIfNeeded(address account) private {
    if (account == address(0)) {
      return;
    }

    if (balanceOf[account] == 0) {
      uint256 indexPlusOne = _holderIndexPlusOne[account];
      if (indexPlusOne != 0) {
        uint256 index = indexPlusOne.sub(1);
        uint256 lastIndex = _holders.length.sub(1);

        if (index != lastIndex) {
          address lastHolder = _holders[lastIndex];
          _holders[index] = lastHolder;
          _holderIndexPlusOne[lastHolder] = index.add(1);
        }

        _holders.pop();
        _holderIndexPlusOne[account] = 0;
      }
    }
  }

  function _afterBalanceChange(address account) private {
    _addHolderIfNeeded(account);
    _removeHolderIfNeeded(account);
  }

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(to != address(0), "transfer to zero address");

    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value, "insufficient balance");
    balanceOf[to] = balanceOf[to].add(value);

    _afterBalanceChange(msg.sender);
    _afterBalanceChange(to);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(to != address(0), "transfer to zero address");

    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value, "insufficient allowance");
    balanceOf[from] = balanceOf[from].sub(value, "insufficient balance");
    balanceOf[to] = balanceOf[to].add(value);

    _afterBalanceChange(from);
    _afterBalanceChange(to);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "empty mint");

    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);

    _afterBalanceChange(msg.sender);
  }

  function burn(address payable dest) external override {
    require(dest != address(0), "burn to zero address");

    uint256 amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);

    _afterBalanceChange(msg.sender);

    (bool success, ) = dest.call{value: amount}("");
    require(success, "eth transfer failed");
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > _holders.length) {
      return address(0);
    }

    return _holders[index.sub(1)];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "empty dividend");
    require(totalSupply > 0, "no token supply");

    uint256 holderCount = _holders.length;
    for (uint256 i = 0; i < holderCount; i = i.add(1)) {
      address holder = _holders[i];
      uint256 payout = msg.value.mul(balanceOf[holder]).div(totalSupply);
      _withdrawableDividends[holder] = _withdrawableDividends[holder].add(payout);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    require(dest != address(0), "withdraw to zero address");

    uint256 amount = _withdrawableDividends[msg.sender];
    _withdrawableDividends[msg.sender] = 0;

    (bool success, ) = dest.call{value: amount}("");
    require(success, "eth transfer failed");
  }
}