pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "hashs/SHA3.sol";

contract DeFiPlatform {
    // IERC20 public stablecoin;

    struct User {
        address user_address;
        uint256 credit_score;
        bool is_nid_verified;
        uint256[] loan_id;
        uint256 balance;
    }

    struct Loan {
        uint256 amount;
        address borrower;
        Status status;
        address staker;
        uint256 start_date;
        uint256 vault_id;
        uint256 borrowing_group_id;
        uint256 no_of_installments;
        uint256 no_of_installments_done;
        uint256 each_installment_amount;
        uint256 each_term;
    }

    struct Staker {
        uint256 total_amount_staked;
        uint256 reputation_score;
        bool is_nid_verified;
        address[] referred_borrower;
        uint256 reward;
        uint256 balance;
    }

    struct Vault {
        address vault_owner;
        uint256 total_supply;
        uint256 remaining_supply;
        uint256 interest_rate;
        uint256 interest_earned;
        uint256 creation_date;
        mapping(address => uint256) member_contribution;
        Status status;
    }

    struct Borrowing_group {
        uint256 total_funded;
        mapping(address => mapping(uint256 => uint256)) member_loanId_votes;
        Status status;
    }

    enum Status {
        pending,
        approved,
        cancelled
    }

    mapping(address => User) public address_user;
    mapping(address => Staker) public address_staker;
    mapping(uint256 => Loan) public loanId_loan;
    mapping(uint256 => Vault) public vaultId_vault;
    mapping(uint256 => Borrowing_group) public groupId_borrowingGroup;

    uint256 private last_borrowing_group_id;
    uint256 private last_vault_id;
    uint256 private last_loan_id;
    address owner;

    constructor() {
        //IERC20 _stablecoin
        // stablecoin = _stablecoin;
        owner = payable(msg.sender);
        last_borrowing_group_id = 0;
        last_vault_id = 0;
        last_loan_id = 0;
    }

    function become_staker(bool _is_nid_verified) external {
        address_staker[msg.sender] = Staker({
            total_amount_staked: 0,
            reputation_score: 100,
            is_nid_verified: _is_nid_verified,
            balance: 0,
            reward: 0,
            referred_borrower: new address[](10)
        });
    }

    function stake(uint256 loan_id) external {
        require(
            address_staker[msg.sender].balance > loanId_loan[loan_id].amount,
            "You don't have enough balance"
        );

        loanId_loan[loan_id].staker = msg.sender;
        address_staker[msg.sender].balance -= loanId_loan[loan_id].amount;
        address_staker[msg.sender].total_amount_staked = loanId_loan[loan_id]
            .amount;
        address_staker[msg.sender].referred_borrower.push(
            loanId_loan[loan_id].borrower
        );

        //emit en event to the PM.
    }

    function create_individual_vault(
        uint256 total_amount,
        uint256 interest_rate
    ) external {
        User storage user = address_user[msg.sender];
        require(user.balance >= total_amount, "Insufficient balance");
        require(
            address_user[msg.sender].is_nid_verified == true,
            "NID is not verified"
        );

        user.balance = user.balance - total_amount;

        uint256 vault_id = last_vault_id + 1;
        last_vault_id++;
        // vaultId_vault[vault_id] = Vault({});
        Vault storage vault = vaultId_vault[vault_id];
        vault.vault_owner = msg.sender;
        vault.total_supply = total_amount;
        vault.remaining_supply = total_amount; //remaining balance
        vault.interest_rate = interest_rate;
        vault.status = Status.pending;
        // emit VaultCreated(vaultId, msg.sender, interestRate, isGroupVault);
    }

    function initiate_group_vault(uint256 interest_rate) external {
        // require(
        //     msg.sender == pm_address;
        //     "only pm can initiate a group vault"
        // ); //
        uint256 vault_id = last_vault_id++;
        Vault storage vault = vaultId_vault[vault_id];
        vault.interest_rate = interest_rate;
        vault.status = Status.pending;
    }

    function join_group_vault(uint256 contribution, uint256 vault_id) external {
        require(
            address_user[msg.sender].balance >= contribution,
            "Insufficient balance"
        );
        require(
            address_user[msg.sender].is_nid_verified == true,
            "NID is not verified"
        );

        vaultId_vault[vault_id].total_supply += contribution;
        vaultId_vault[vault_id].member_contribution[msg.sender] = contribution;
    }

    function approve_vault(uint256 vault_id) external {
        //for individual vault
        if (vaultId_vault[vault_id].vault_owner != address(0)) {
            vaultId_vault[vault_id].status = Status.approved;
            vaultId_vault[vault_id].creation_date = block.timestamp;
            vaultId_vault[vault_id].remaining_supply = vaultId_vault[vault_id]
                .total_supply;
        }
    }

    function individual_borrow(
        uint256 _vault_id,
        uint256 _amount,
        uint256 _each_installment_amount,
        uint256 _no_of_installments,
        uint256 _each_term
    ) external {
        require(_amount <= 10000, "exceeded loan limit. Only upto 10000 taka");
        uint256 loan_id = last_loan_id + 1;
        last_loan_id++;

        Loan memory loan = Loan({
            borrower: msg.sender,
            amount: _amount,
            status: Status.pending,
            vault_id: _vault_id,
            no_of_installments: _no_of_installments,
            each_installment_amount: _each_installment_amount,
            each_term: _each_term,
            staker: address(0), // Add a default value or a suitable value for the staker field
            start_date: 0, // Add a default value or a suitable value for the start_date field
            borrowing_group_id: 0, // Add a default value or a suitable value for the borrowing_group_id field
            no_of_installments_done: 0 // Add a default value for the no_of_installments_done field
            // interest_rate: 0 // Add a default value or a suitable value for the interest_rate field
        });
        loanId_loan[loan_id] = loan;
    }

    function approve_loan(uint256 _loan_id) external {
        require(
            vaultId_vault[loanId_loan[_loan_id].vault_id].total_supply >=
                loanId_loan[_loan_id].amount,
            "Not enough fund in the vault"
        );
        require(loanId_loan[_loan_id].staker != address(0), "no staker found");

        User storage user = address_user[loanId_loan[_loan_id].borrower];
        user.balance += loanId_loan[
            _loan_id
        ].amount;
        vaultId_vault[loanId_loan[_loan_id].vault_id]
            .total_supply -= loanId_loan[_loan_id].amount;
    }

    function cashout_loan(uint256 _amount) external {
        // require(msg.sender == owner, "Only the owner can transfer money from contract.");
        require(
            address_user[msg.sender].balance >= _amount,
            "you don't have enough balance"
        );
        require(
            address(this).balance >= _amount,
            "Not enough balance in the contract."
        );
        uint256 cashout_amount = _amount - calculate_fees(_amount);
        payable(msg.sender).transfer(cashout_amount);
        address_user[msg.sender].balance -= _amount;
    }

    function individual_installment_repay_wtih_interest(uint256 _loan_id)
        external
        payable
    {
        uint256 installment_amount = loanId_loan[_loan_id]
            .each_installment_amount;
        uint256 vault_id = loanId_loan[_loan_id].vault_id;
        Vault storage vault = vaultId_vault[vault_id];
        require(
            msg.value >= installment_amount,
            "Amount must be equal or more than each_term"
        );
        loanId_loan[_loan_id].no_of_installments_done += 1;
        // add the interest later. will deal with fixed point number.
        vault.remaining_supply = installment_amount;
        vault.interest_earned = calculate_interest();
        //calculate credit score for borrower, lender, staker
        // give staker the reward
    }

    function calculate_fees(uint256 _amount) internal pure returns (uint256) {
        return 100;
    }

    function calculate_interest() internal pure returns (uint256) {
        return 200;
    }

function add_balance(string memory user_type) external payable {
    string memory user = "user";
    string memory staker = "staker";
    if (keccak256(abi.encodePacked(user_type)) == keccak256(abi.encodePacked(user))) {
        uint256 amount = msg.value;
        address_user[msg.sender].balance =
            address_user[msg.sender].balance +
            amount;
    }
    if(keccak256(abi.encodePacked(user_type)) == keccak256(abi.encodePacked(staker))){
        Staker storage staker = address_staker[msg.sender];
        staker.balance += msg.value;
    }
}

    function add_user() external {
        address_user[msg.sender] = User({
            user_address: msg.sender,
            is_nid_verified: true,
            loan_id: new uint256[](0),
            balance: 0,
            credit_score: 0
        });
    }

    function get_balance() external view returns (uint256) {
        return address_user[msg.sender].balance;
    }

    function show_user() external view returns (User memory) {
        return address_user[msg.sender];
    }

    function show_last_vault_id() external view returns (uint256) {
        return last_vault_id;
    }

    function withdraw_balance(uint256 amount) external {
        User storage user = address_user[msg.sender];
        require(
            amount <= user.balance,
            "withdraw amount is more than your balance"
        );
        payable(msg.sender).transfer(amount);
        user.balance -= amount;
    }

    function show_contract_balance() external view returns (uint256) {
        return address(this).balance;
    }
}
