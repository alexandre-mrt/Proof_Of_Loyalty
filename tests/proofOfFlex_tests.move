#[test_only]
module grantproject::proofOfFlex_tests{
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    // simpler at the begening only sui coin
    use sui::sui::SUI;
    use sui::pay;

    use sui::object_table::{Self, ObjectTable};
    use grantproject::proofOfFlex::{Self, ProofOfFlex, Container, ContainerManager};

    use sui::test_scenario;

    #[test]
    fun test_POF(){
        let admin = @0x1;
        let user1 = @0x2;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        {
            proofOfFlex::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, user1);
        {
            let coin = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario) );
            let containerManager = test_scenario::take_shared<ContainerManager>(scenario);

            proofOfFlex::depositFlexMoney( &mut containerManager, coin ,test_scenario::ctx(scenario));

            assert!(proofOfFlex::getContainerAmount(&containerManager)== 1000, 1000);
            assert!(proofOfFlex::getContainerSize(&containerManager)== 1, 1);

            test_scenario::return_shared<ContainerManager>(containerManager);
        };

        test_scenario::next_tx(scenario, user1);
        {
            let containerManager = test_scenario::take_shared<ContainerManager>(scenario);
            proofOfFlex::mintFlexNFT(  &mut containerManager, test_scenario::ctx(scenario));
            assert!(proofOfFlex::getContainerWinner(&containerManager) == 1000, 1001);
            test_scenario::return_shared<ContainerManager>(containerManager);

        };

        test_scenario::next_tx(scenario, user1);
        {
            
            let containerManager = test_scenario::take_shared<ContainerManager>(scenario);

            proofOfFlex::redeemFlexMoney(  &mut containerManager, test_scenario::ctx(scenario));

            assert!(proofOfFlex::getContainerAmount(&containerManager)== 0, 0);
            // take the user balance to check if he received well the money
            //assert!(coin::balance<SUI>(ctx,user1 )  1000, 404);

            test_scenario::return_shared<ContainerManager>(containerManager);
        };

        test_scenario::end(scenario_val);
    }
}