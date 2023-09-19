//Flex on how much money you can give/deposit
module grantproject::proofOfFlex{

    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    // simpler at the begening only sui coin
    use sui::sui::SUI;

    use sui::object_table::{Self, ObjectTable};




    const ENonExistentContainer: u64 = 0;

    struct ProofOfFlex has key{
        uid: UID,
        url: Url,
        name: String,
        amount: u64,
        assetID: String
    }

    struct AdminCap has key{
        uid: UID,
    }

    //keep track of the amount of money in the container (could simplifiy with only Suicoin) why an object ?
    struct Container has key, store{
        uid: UID,
        userOwner: address,
        balance: Balance<SUI>
    }

    //Store all the containers in the record table (dynamical storage already) could add a table to keep track of the record for the best 3
    // winner should be tupple of (address, amount) to keep track of the winner
    struct ContainerManager has key{
        uid: UID,
        amount: u64,
        record: ObjectTable<address, Container>,
        winner: u64
    }

    fun init(ctx: &mut TxContext){

        transfer::share_object(ContainerManager{
            uid: object::new(ctx),
            amount: 0,
            record: object_table::new(ctx),
            winner: 0
        });
    }

    public entry fun getContainerSize(containerManager: &ContainerManager): u64{
        return object_table::length(&containerManager.record)
    }

    public entry fun getContainerAmount(containerManager: &ContainerManager): u64{
        return containerManager.amount
    }
    public entry fun getContainerWinner(containerManager: &ContainerManager): u64{
        return containerManager.winner
    }

    // create a container with the asset choosen, and put it into container Manager in a table
    public entry fun depositFlexMoney(ctx: &mut TxContext, containerManager: &mut ContainerManager, coin: Coin<SUI>){

        let container = Container{
            uid: object::new(ctx),
            userOwner: tx_context::sender(ctx),
            balance: coin::into_balance(coin)
        };
        //put the container in the table
        containerManager.amount = containerManager.amount + balance::value(&container.balance);
        object_table::add(&mut containerManager.record, tx_context::sender(ctx), container);

    }

    

    //could I have just returned the coin and not send it ?
    public entry fun redeemFlexMoney(ctx: &mut TxContext, containerManager: &mut ContainerManager){

        assert!(object_table::contains(&containerManager.record, tx_context::sender(ctx)),ENonExistentContainer);

        //let container = object_table::borrow_mut( &mut containerManager.record, tx_context::sender(ctx));
        let Container{
            uid,
            userOwner: _,
            balance
        } = object_table::remove(&mut containerManager.record, tx_context::sender(ctx));



        let value = balance::value<SUI>(&balance);
        let redemed = coin::take<SUI>(&mut balance,value, ctx);

        //delete balance as it has not drop ability
        
        

        //delete the container in the containerManager. Good practice if returned value not null 

        //how to fucking delete this
        balance::destroy_zero(balance);
        object::delete(uid);

        containerManager.amount = containerManager.amount - value;

        //transfer the money to the owner
        transfer::transfer(redemed, tx_context::sender(ctx));
        

    }

    public entry fun mintFlexNFT(ctx: &mut TxContext, containerManager: &mut ContainerManager ){

        assert!(object_table::contains(& containerManager.record, tx_context::sender(ctx)),ENonExistentContainer); //check if it's the good way to return errors

        //try to get the container of the user in read only 
        let container = object_table::borrow(&containerManager.record, tx_context::sender(ctx));

        let proof = ProofOfFlex{
            uid: object::new(ctx),
            url: url::new_unsafe_from_bytes(b"https://pixnio.com/free-images/2017/06/08/2017-06-08-14-28-22-1152x768.jpg"),
            name: string::utf8(b"Proof of Flex"),
            amount: balance::value(&container.balance), //check if it is the right way to access the balance
            assetID: string::utf8(b"Suicoin")
        };
        containerManager.winner = if (proof.amount > containerManager.winner) proof.amount else containerManager.winner;
        

        transfer::transfer(proof, tx_context::sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(ctx);
    }
}
