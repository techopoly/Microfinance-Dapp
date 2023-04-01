pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DeFiPlatform is Ownable, IERC20 {
    IERC20 public stablecoin;

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
        uint256 interest_rate;
        uint256 each_term;
    }

    struct Staker {
        uint256 total_amount_staked;
        uint256 reputation_score;
        bool is_nid_verified;
        address[] referred_borrower;
        uint256 balance;
    }

    struct Vault {
        address vault_owner;
        uint256 total_supply;
        uint256 remaining_supply;
        uint256 interest_rate;
        uint interest_earned;
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
        Pending,
        approved,
        Cancelled
    }

    mapping(address => User) public address_user;
    mapping(address => Staker) public address_staker;
    mapping(uint256 => Loan) public loanId_loan;
    mapping(uint256 => Vault) public vaultId_vault;
    mapping(uint256 => Borrowing_group) public groupId_borrowingGroup;

    uint256 private last_borrowing_group_id;
    uint256 private last_vault_id;
    uint256 private last_loan_id;


    constructor(IERC20 _stablecoin) {
        stablecoin = _stablecoin;
        owner = payable(msg.sender);
        last_borrowing_group_id = 0;
        last_vault_id = 0;
        last_loan_id = 0;
    }

    function payable become_staker(
        bool _is_nid_verified,
    ){
        address_staker[msg.sender] = Staker({
        reputation_score: 100;
        is_nid_verified = _is_nid_verified;
        balance = msg.value;
        })
    }

    function stake(uint256 loan_id) external {
        require(loanId_loan[loan_id].amount > address_staker[msg.sender].balance, "You don't have sufficient balance");

        loanId_loan[loan_id].staker = msg.sender;
        address_staker[msg.sender].balance -= loanId_loan[loan_id].amount;
        address_staker[msg.sender].total_amount_staked = loanId_loan[loan_id].amount;
        address_staker[msg.sender].referred_borrower.push(loanId_loan[loan_id].borrower);

        //emit en event to the PM.
    }

    function create_individual_vault(
        uint256 total_amount,
        uint256 interest_rate
    ) external {
        require(
            address_user[msg.sender].balance >= amount,
            "Insufficient balance"
        );
        require(
            address_user[msg.sender].is_nid_verified == true,
            "NID is not verified"
        );

        uint256 vault_id = last_vault_id++;
        vaultId_vault[vault_id] = Vault({
                vault_owner : msg.sender;
                total_supply : total_amount;
                remaining_supply : total_amount; //remaining balance
                interest_rate : interest_rate;
                status : Status.pending;
        });

        // emit VaultCreated(vaultId, msg.sender, interestRate, isGroupVault);
    }

    function initiate_group_vault(
        uint256 interest_rate
    ) external {
        // require(
        //     msg.sender == pm_address;
        //     "only pm can initiate a group vault"
        // ); //
                uint256 vault_id = last_vault_id++;
                vaultId_vault[vault_id] = Vault({
                interest_rate : interest_rate;
                status : Status.pending;
        });
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
        vaultId_vault[vault_id].member_contribution[msg.sender] = contribution
    }

    function approve_vault( uint256 vault_id){
        //for individual vault
        if(vaultId_vault[vault_id].vault_owner){
        vaultId_vault[vault_id].status = Status.approved;
        vaultId_vault[vault_id].creation_date = block.timestamp;
        vaultId_vault[vault_id].remaining_supply = vaultId_vault[vault_id].total_supply;
        }
    }


    function individual_borrow(
        uint256 vault_id,
        uint _amount,
        uint _each_installment_amount,
        uint _no_of_installments,
        uint _each_term,
        uint _vault_id,
        ){
          require(
            _amount <= 10000,
            "exceeded loan limit. Only upto 10000 taka"
        );
        uint256 loan_id= last_loan_id++;
        loanId_loan[loan_id] = Loan({
            borrower : msg.sender;
            amount: _amount;
            status: Status.pending;
            vault_id: _vault_id;
            no_of_installments: _no_of_installments;
            each_installment_amount: _each_installment_amount;
            each_term: _each_term;
        })
    }

    function approve_loan(_loan_id){
        require(vaultId_vault[loanId_loan[_loan_id].vault_id].total_supply >= loanId_loan[_loan_id].amount,
                "Not enough fund in the vault");
        require(loanId_loan[_loan_id].staker, "no staker found");

        address_user[loanId_loan[_loan_id].borrower].balance = loanId_loan[_loan_id].amount;
        vaultId_vault[loanId_loan[_loan_id].vault_id].total_supply -= loanId_loan[_loan_id].amount;
    }


    function cashout_loan(uint _amount){
        // require(msg.sender == owner, "Only the owner can transfer money from contract.");
        require(address_user[msg.sender].balance >= _amount,
        "not enough balance");
        require(address(this).balance >= _amount, "Not enough Ether in the contract.");
        uint cashout_amount = _amount - calculate_fees(_amount);
        payable(msg.sender).transfer(cashout_amount);
    }

    function individual_installment_repay_wtih_interest(uint _loan_id) payable external{
        uint installment_amount = loanId_loan[_loan_id].each_installment_amount;
        uint vault_id = loanId_loan[_loan_id].vault_id;
        Vault vault = vaultId_vault[vault_id]
        require(msg.value >= installment_amount, "Amount must be equal or more than each_term");
        loanId_loan[_loan_id].no_of_installments_done += 1;
        // add the interest later. will deal with fixed point number.
        vault.remaining_supply = installment_amount;
        vault.interest_earned = calculate_interest;
    }


    function calculate_fees(uint256 _amount) returns (uint256){
        return 100;
    }

    function calculate_interest() returns (uint256){
            return 200;
    }

 

}