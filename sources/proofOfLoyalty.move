//Flex on how much money you can give/deposit
module grantproject::proofOfLoyalty{

    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::object::{Self,ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::clock::{Self, Clock};
    
    // simpler at the begening only sui coin
    use sui::sui::SUI;

    use sui::object_table::{Self, ObjectTable};


    const ValFee1Suicoin: u64 = 1;

    // ===== Errors =====

    const ENonExistentContainer: u64 = 0;
    const EContainerAlreadyExist: u64 = 1;
    const ENoFeesToTake: u64 = 2;
    const ENoMoney: u64 = 3;

    // Proof of Flex is a NFT that you can mint if you have a container with a certain amount of money
    struct ProofOfLoyalty has key, store{
        id: UID,
        url: Url,
        name: String,
        amount: u64,
        assetID: String,
        timeLockedDays: u64
    }

    // admin cap for the creator allowing to take the fees
    struct AdminCap has key{
        id: UID,
    }

    struct Winner has store, copy, drop{
        user: address,
        amount: u64,
    }
    //keep track of the amount of money in the container (could simplifiy with only Suicoin) why an object ?
    struct Container has key, store{
        id: UID,
        userOwner: address,
        balance: Balance<SUI>,
        startingTime: u64
    }

    //Store all the containers in the record table (dynamical storage already) could add a table to keep track of the record for the best 3
    // winner should be tupple of (address, amount) to keep track of the winner
    struct ContainerManager has key{
        id: UID,
        amount: u64,
        record: ObjectTable<address, Container>,
        winnerAmount: Winner,
        winnerTime: Winner,
        //Coin is a wrapper for balance as balance cannot exist by itself (no key ability)
        containerFees: Balance<SUI>
    }

    // ===== Events =====

    struct NFTMinted has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The creator of the NFT
        creator: address,
        // The name of the NFT
        name: string::String,
    }

    // ===== Public view functions =====

    fun init(ctx: &mut TxContext){

        //create the containerManager
        transfer::share_object(ContainerManager{
            id: object::new(ctx),
            amount: 0,
            record: object_table::new(ctx),
            winnerAmount : Winner{
                user: @0x0,
                amount: 0
            },
            winnerTime : Winner{
                user: @0x0,
                amount: 0
            },
            containerFees: balance::zero<SUI>()
        });
        //create the adminCap
        transfer::transfer(AdminCap{
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    // ===== Public getters functions =====

     public fun getWinnerUser(winner: Winner): address{
        return winner.user
    }
     public fun getWinnerAmount (winner: Winner): u64{
        return winner.amount
    }

    public entry fun getContainerSize(containerManager: &ContainerManager): u64{
        return object_table::length(&containerManager.record)
    }

    public entry fun getContainerAmount(containerManager: &ContainerManager): u64{
        return containerManager.amount
    }
    public entry fun getContainerWinnerAmount(containerManager: &ContainerManager): Winner{
        return containerManager.winnerAmount
    } 

    public entry fun getContainerWinnerTime(containerManager: &ContainerManager): Winner{
        return containerManager.winnerTime
    }

    public entry fun getContainerFees(containerManager: &ContainerManager): u64{
        return balance::value(&containerManager.containerFees)
    }

    
    // ===== Public functions =====

    // create a container with the asset choosen, and put it into container Manager in a table. Pass in argument the clock at address (0x6)
    public entry fun depositFlexMoney( containerManager: &mut ContainerManager, coin: Coin<SUI>, clock: &Clock, ctx: &mut TxContext){

        //beta does not allow user to have severals positions
        let contains = object_table::contains(&containerManager.record, tx_context::sender(ctx));

        assert!(!contains, EContainerAlreadyExist);
        

        let container = Container{
            id: object::new(ctx),
            userOwner: tx_context::sender(ctx),
            balance: coin::into_balance(coin),
            startingTime: clock::timestamp_ms(clock)
        };
        //put the container in the table
        containerManager.amount = containerManager.amount + balance::value(&container.balance);
        object_table::add(&mut containerManager.record, tx_context::sender(ctx), container);

    }

    

    //could I have just returned the coin and not send it ?
    public entry fun redeemFlexMoney( containerManager: &mut ContainerManager, ctx: &mut TxContext){

        assert!(object_table::contains(&containerManager.record, tx_context::sender(ctx)),ENonExistentContainer);

        //let container = object_table::borrow_mut( &mut containerManager.record, tx_context::sender(ctx));
        let Container{
            id,
            userOwner: _,
            balance,
            startingTime: _
        } = object_table::remove(&mut containerManager.record, tx_context::sender(ctx));



        let value = balance::value<SUI>(&balance);
        let redemed = coin::take<SUI>(&mut balance,value, ctx);

        //delete the container in the containerManager. Good practice if returned value not null 

        balance::destroy_zero(balance);
        object::delete(id);

        containerManager.amount = containerManager.amount - value;

        //transfer the money to the owner
        transfer::public_transfer(redemed, tx_context::sender(ctx));
      
        

    }

    public entry fun mintFlexNFT( containerManager: &mut ContainerManager, coin: Coin<SUI>, clock: &Clock, ctx: &mut TxContext ){

        assert!(object_table::contains(& containerManager.record, tx_context::sender(ctx)),ENonExistentContainer);

        let container = object_table::borrow(&containerManager.record, tx_context::sender(ctx));

        let sender = tx_context::sender(ctx);

        assert!(coin::value(&coin) >= ValFee1Suicoin, ENoMoney );
        // 1000000000 = 1 Sui

        let fees = coin::split(&mut coin, ValFee1Suicoin ,ctx);
        balance::join(&mut containerManager.containerFees, coin::into_balance(fees));
        
        transfer::public_transfer(coin, sender);


        //try to get the container of the user in read only 

        let proof = ProofOfLoyalty{
            id: object::new(ctx),
            url: url::new_unsafe_from_bytes(b"https://pixnio.com/free-images/2017/06/08/2017-06-08-14-28-22-1152x768.jpg"),
            name: string::utf8(b"Proof of Flex"),
            amount: balance::value(&container.balance), //check if it is the right way to access the balancer
            assetID: string::utf8(b"Suicoin"),
            timeLockedDays: (clock::timestamp_ms(clock) - container.startingTime)/86400000
        };
        if (proof.amount > containerManager.winnerAmount.amount) {
            containerManager.winnerAmount = Winner{
            user: sender, 
            amount: proof.amount
            } 
        };
        if (proof.timeLockedDays > containerManager.winnerTime.amount) {
            containerManager.winnerTime = Winner{
            user : sender, 
            amount : proof.timeLockedDays
            }
        };


        event::emit(NFTMinted {
            object_id: object::id(&proof),
            creator: sender,
            name: proof.name,
        });
        
        transfer::transfer(proof, sender);
    }

    public entry fun takeProfit(_: &AdminCap, containerManager : &mut ContainerManager, ctx: &mut TxContext){
        //transfer the money to the owner
        let containerFees = balance::value(&containerManager.containerFees);
        // diff between returning a coin and transfer ?
        assert!(containerFees > 0, ENoFeesToTake);

        transfer::public_transfer(coin::take<SUI>(&mut containerManager.containerFees, containerFees, ctx), tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(ctx);
    }
}
