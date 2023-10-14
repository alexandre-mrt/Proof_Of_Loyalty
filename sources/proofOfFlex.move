//Flex on how much money you can give/deposit
module grantproject::proofOfFlex{

    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::object::{Self,ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::event;
    // simpler at the begening only sui coin
    use sui::sui::SUI;

    use sui::object_table::{Self, ObjectTable};




    const ENonExistentContainer: u64 = 0;
    const EContainerAlreadyExist: u64 = 1;

    // Proof of Flex is a NFT that you can mint if you have a container with a certain amount of money
    struct ProofOfFlex has key, store{
        id: UID,
        url: Url,
        name: String,
        amount: u64,
        assetID: String
    }

    struct AdminCap has key{
        id: UID,
    }

    //keep track of the amount of money in the container (could simplifiy with only Suicoin) why an object ?
    struct Container has key, store{
        id: UID,
        userOwner: address,
        balance: Balance<SUI>
    }

    //Store all the containers in the record table (dynamical storage already) could add a table to keep track of the record for the best 3
    // winner should be tupple of (address, amount) to keep track of the winner
    struct ContainerManager has key{
        id: UID,
        amount: u64,
        record: ObjectTable<address, Container>,
        winnerTime: u64,
        winnerAmount: u64
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

        transfer::share_object(ContainerManager{
            id: object::new(ctx),
            amount: 0,
            record: object_table::new(ctx),
            winnerAmount : 0,
            winnerTime : 0
        });
    }

    public entry fun getContainerSize(containerManager: &ContainerManager): u64{
        return object_table::length(&containerManager.record)
    }

    public entry fun getContainerAmount(containerManager: &ContainerManager): u64{
        return containerManager.amount
    }
    public entry fun getContainerWinner(containerManager: &ContainerManager): u64{
        return containerManager.winnerAmount
    }

    // create a container with the asset choosen, and put it into container Manager in a table
    public entry fun depositFlexMoney( containerManager: &mut ContainerManager, coin: Coin<SUI>, ctx: &mut TxContext){

        //beta does not allow user to have severals positions
        assert!(!object_table::contains(&containerManager.record, tx_context::sender(ctx)),EContainerAlreadyExist);
        

        let container = Container{
            id: object::new(ctx),
            userOwner: tx_context::sender(ctx),
            balance: coin::into_balance(coin)
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
            balance
        } = object_table::remove(&mut containerManager.record, tx_context::sender(ctx));



        let value = balance::value<SUI>(&balance);
        let redemed = coin::take<SUI>(&mut balance,value, ctx);

        //delete balance as it has not drop ability
        
        

        //delete the container in the containerManager. Good practice if returned value not null 

        //how to fucking delete this
        balance::destroy_zero(balance);
        object::delete(id);

        containerManager.amount = containerManager.amount - value;

        //transfer the money to the owner
        transfer::public_transfer(redemed, tx_context::sender(ctx));
      
        

    }

    public entry fun mintFlexNFT( containerManager: &mut ContainerManager , ctx: &mut TxContext ){

        assert!(object_table::contains(& containerManager.record, tx_context::sender(ctx)),ENonExistentContainer); //check if it's the good way to return errors

        //try to get the container of the user in read only 
        let container = object_table::borrow(&containerManager.record, tx_context::sender(ctx));

        let sender = tx_context::sender(ctx);
        let proof = ProofOfFlex{
            id: object::new(ctx),
            url: url::new_unsafe_from_bytes(b"https://pixnio.com/free-images/2017/06/08/2017-06-08-14-28-22-1152x768.jpg"),
            name: string::utf8(b"Proof of Flex"),
            amount: balance::value(&container.balance), //check if it is the right way to access the balancer
            assetID: string::utf8(b"Suicoin")
        };
        containerManager.winnerAmount = if (proof.amount > containerManager.winnerAmount) proof.amount else containerManager.winnerAmount;

        event::emit(NFTMinted {
            object_id: object::id(&proof),
            creator: sender,
            name: proof.name,
        });
        
        transfer::public_transfer(proof,sender );
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(ctx);
    }
}
