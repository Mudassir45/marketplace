// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Marketplace is Ownable {
    enum Stage { Open, Closed }
    enum OfferStatus { Pending, Accepted, Rejected }
    
    struct Product {
        uint256 Id;
        uint256 price;
        uint256 quantity;
        uint256 deadline;
        uint256 acceptedOfferId;
        uint256[] offerIds; // loop for rejection
        string name;
        bytes32 description; // optional offchain || hash number on IPFS
        address orderOwner;
        Stage reqStage;
        uint8 paymentType; // 0: Ether, 1: Token ?? || 2 ftns
        address tokenAddress; // 0x0, 0xa56fgvdf67a ??
        bool isDecided;
        bool isPaid;
    }
    
    struct Offer {
        uint256 Id;
        uint256 productId;
        uint256 price;
        uint256 quantity;
        address offerMaker;
        OfferStatus offStage; // accepted or rejected
    }

    modifier onlySeller(uint256 _productId) {
        require(products[_productId].orderOwner == msg.sender, "Only order owner can access");
        _;
    }
    
    uint256 internal productNum;
    uint256 internal offNum;
    
    mapping(uint256 => Product) internal products;
    mapping(uint256 => Offer) internal offers;
    mapping(address => Product) internal productsOwner;
    
    event ProductAdded(uint256 productId, uint256 deadline);
    event ProductClosed(uint256 productId);
    event ProductRemoved(uint256 productId);
    event OfferAdded(uint256 offerId);
    event TradeSettled(uint256 productId, uint256 offerId);
    event OfferDecided(uint24 productId, uint256 offerId);

    constructor() {
        productNum = 1;
        offNum = 1;
    }
    
    function getProduct(uint256 _productId) external view returns(Stage stage, address productOwner, uint256 deadline) {
        return (products[_productId].reqStage, products[_productId].orderOwner, products[_productId].deadline);
    }

    function getOrders(address _orderOwner) external view returns(uint256) {

    }
    
    function getProductOfferIds(uint256 _productId) external view returns(uint256[] memory offerIds) {
        return products[_productId].offerIds;
    }

    function getOffer(uint256 _productId) external view returns(uint256 offerId, address offerMaker, uint256 quantity, Stage stage, uint256 amount) {
        return (
            offers[_productId].productId, 
            offers[_productId].offerMaker, 
            offers[_productId].quantity, 
            offers[_productId].offStage,
            offers[_productId].amount
        );
    }

    function submitProduct(uint256 _deadline, uint256 _quantity, uint256 _price, string memory _name, bytes32 _description) external returns(uint256 productId) {
        Product memory product;
        product.Id = productNum;
        productNum += 1;
        product.deadline = _deadline;
        product.quantity = _quantity;
        product.price = _price;
        product.name = _name;
        product.description = _description;
        product.orderOwner = msg.sender;
        product.reqStage = Stage.Open;
        product.isDecided = false;
        products[product.Id] = product;
        productsOwner[msg.sender] = product;

        emit ProductAdded(product.Id, product.deadline);
        return product.Id;
    }

    function _closeProduct(uint256 _productId) internal {
        require(products[_productId].deadline == block.timestamp, "Deadline not completed");
        products[_productId].reqStage = Stage.Closed;
        emit ProductClosed(_productId);
    }

    // Choose which offer to accept, based on the proposed prices.
    // only order owner can execute & rejects all other offers
    function decideOffer(uint256 _productId, uint256 _acceptedOfferId) external onlySeller(_productId) returns(bool status) {
        _closeProduct(_productId);
        for (uint k = 0; k <= products[_productId].offerIds.length; k++) {
            if(products[_productId].offerIds == _acceptedOfferId) {
                continue;
            }
            products[_productsId].offerIds = OfferStatus.Rejected;
        }
        products[_productId].acceptedOfferId = _acceptedOfferId;
        products[_productId].isDecided = true;

        emit OfferDecided(_productId, _acceptedOfferId);
        return true;
    }
    
    function submitOffer(uint256 _productId, uint256 _amount, uint256 _quantity) external returns(uint256 offerId) {
        require(block.timestamp > products[_productId].deadline, "Sorry time is completed to submit offer");
        require(Stage.Open == products[_productId].reqStage, "Product is not open now");
        require(products[_productId].offerIds.length <= 50, "Limit of offers crossed");
        require(offers[_productId].offerMaker != msg.sender, "You can make only single offer");

        Offer memory offer;
        offer.productId = _productId;
        offer.amount = _amount;
        offer.offerMaker = msg.sender;
        offer.quantity = _quantity;
        offer.Id = offNum;
        offNum += 1;
        offer.offStage = OfferStatus.Pending;
        offers[offer.Id] = offer;
        products[offer.productId].offerIds.push(offer.Id);
        
        emit OfferAdded(offer.Id);
        return offer.Id;
    }

    function deleteProduct(uint256 _productId) external returns() {
        for (uint i = 0; i < products[_productId].offerIds.length; i++) {
            delete offers[products[_productId].offerIds[i]];
        }

        delete products[_productId];
    }

    function payment(uint256 _productId) external {
        uint256 offerId = products[_productId].acceptedOfferId;
        bool result = false;
        if(products[_productId].isDecided == true && products[_productId].isPaid == false) {
            result = transferFrom(products[_productId].orderOwner, offers[offerId].offerMaker, offers[offerId].price);
        }
        if(result == true) {
            products[_productId].isPaid = true;
            return true;
        }
        return false;
    }
}