// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.7.0;

contract Marketplace {
    enum Stage { Pending, Open, Closed }
    
    struct Product {
        uint256 Id;
        uint256 price;
        uint256 quantity;
        uint256[] offerIds;
        string name;
        bytes32 description; // optional offchain
        address orderOwner;
        Stage reqStage;
        uint8 paymentType; // 0: Ether, 1: Token
        address tokenAddress; // 0x0, 0xa56fgvdf67a
    }
    
    struct Offer {
        uint256 Id;
        uint256 productId;
        uint256 amount;
        uint256 quantity;
        address offerMaker;
        Stage offStage;
    }
    
    uint256 internal reqNum = 1;
    uint256 internal offNum = 1;
    
    mapping(uint256 => Product) internal products;
    mapping(uint256 => Offer) internal offers;
    
    event ProductAdded(uint256 productId);
    event OfferAdded(uint256 offerId);
    event TradeSettled(uint256 productId, uint256 offerId);
    
    function getOpenProductIds() external view returns(uint256[] memory) {
        return openProductIds;
    }
    
    function getClosedProductIds() external view returns(uint256[] memory) {
        return closedProductIds;
    }
    
    function getProduct(uint256 _productId) external view returns(Stage stage, address productOwner) {
        return (products[_productId].reqStage, products[_productId].orderOwner);
    }
    
    function getOffer(uint256 _productId) external view returns(uint256 offerId, address offerMaker, uint256 quantity, Stage stage, uint256 amount) {
        return (offers[_productId].productId, 
        offers[_productId].offerMaker, 
        offers[_productId].quantity, 
        offers[_productId].offStage,
        offers[_productId].amount
        );
    }
    
    function getProductOfferIds(uint256 _productId) external view returns(uint256[] memory offerIds) {
        return products[_productId].offerIds;
    }
    
    function submitOffer(uint256 _productId, uint256 _amount, uint256 _quantity) external returns(uint256 offerId) {
        Offer memory offer;
        offer.productId = _productId;
        offer.amount = _amount;
        offer.offerMaker = msg.sender;
        offer.quantity = _quantity;
        offer.Id = offNum;
        offNum += 1;
        offer.offStage = Stage.Pending;
        offers[offer.Id] = offer;
        products[offer.productId].offerIds.push(offer.Id);
        
        emit OfferAdded(offer.Id);
        return offer.Id;
    }
}