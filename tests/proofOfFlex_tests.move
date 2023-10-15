#[test_only]
module grantproject::proofOfFlex_tests{
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};

     use sui::clock::{Self, Clock};
    // simpler at the begening only sui coin
    use sui::sui::SUI;

    
    use grantproject::proofOfFlex::{Self, AdminCap, ProofOfFlex, Container, ContainerManager};

    use sui::test_scenario;

    const ErrWithdraw: u64 = 1;
    const ErrWithdrawSendMoney: u64 = 2;

    #[test]
    fun test_POF(){
        let admin = @0x1;
        let user1 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        

        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        {
            proofOfFlex::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, user1);
        {

            let coin = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario) );
            let containerManager = test_scenario::take_shared<ContainerManager>(scenario);

            proofOfFlex::depositFlexMoney( &mut containerManager, coin, &clock,test_scenario::ctx(scenario));

            assert!(proofOfFlex::getContainerAmount(&containerManager)== 1000, 1000);
            assert!(proofOfFlex::getContainerSize(&containerManager)== 1, 1);

            test_scenario::return_shared<ContainerManager>(containerManager);
        };

        test_scenario::next_tx(scenario, user1);
        {
            // > 3 days
            clock::increment_for_testing(&mut clock,266400000);

            // to pay minitng fees
            let coin = coin::mint_for_testing<SUI>(9, test_scenario::ctx(scenario) );

            let containerManager = test_scenario::take_shared<ContainerManager>(scenario);
            proofOfFlex::mintFlexNFT(  &mut containerManager, coin,  &clock,  test_scenario::ctx(scenario));

            assert!(proofOfFlex::getContainerWinner(&containerManager) == 1000, 1001);
            assert!(proofOfFlex::getContainerWinnerTime(&containerManager)==266400000/86400000 , 999);

            test_scenario::return_shared<ContainerManager>(containerManager);

        };

        test_scenario::next_tx(scenario, user1);
        {
            
            let containerManager = test_scenario::take_shared<ContainerManager>(scenario);

            proofOfFlex::redeemFlexMoney( &mut containerManager, test_scenario::ctx(scenario));

            assert!(proofOfFlex::getContainerAmount(&containerManager)== 0, 0);
            // take the user balance to check if he received well the money
            //let coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            // assert!(coin::value(&coin) == 1000, 404);
            //test_scenario::return_to_sender(scenario, coin);

            test_scenario::return_shared<ContainerManager>(containerManager);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let containerManager = test_scenario::take_shared<ContainerManager>(scenario);
            let cap = test_scenario::take_from_sender<AdminCap>(scenario);


            proofOfFlex::takeProfit(&cap, &mut containerManager, test_scenario::ctx(scenario));
            assert!(proofOfFlex::getContainerFees(&containerManager)== 0, ErrWithdraw);

            let coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&coin) == 1, ErrWithdrawSendMoney);
            test_scenario::return_to_sender(scenario, coin);

            test_scenario::return_to_sender(scenario, cap);
            

           

            test_scenario::return_shared<ContainerManager>(containerManager);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
}