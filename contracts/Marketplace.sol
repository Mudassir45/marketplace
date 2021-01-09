// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Marketplace {
    enum Stage { Open, Closed }
    enum OfferStatus { Pending, Accepted, Rejected }
    
    struct Product {
        uint256 Id;
        uint256 price;
        uint256 quantity;
        uint256 deadline;
        uint256 acceptedOfferId;
        uint256[] offerIds;
        string name;
        bytes32 description; // optional offchain || hash number on IPFS
        address orderOwner;
        Stage reqStage;
        uint8 paymentType;
        address tokenAddress; 
        bool isDecided;
        bool isPaid;
    }
    
    struct Offer {
        uint256 Id;
        uint256 productId;
        uint256 price;
        uint256 quantity;
        address offerMaker;
        OfferStatus offStage;
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
    
    event ProductAdded(uint256 productId, uint256 price, uint256 quantity, uint256 deadline, string productName, address orderOwner, Stage status, address token);
    event ProductClosed(uint256 productId);
    event ProductRemoved(uint256 productId);
    event OfferAdded(uint256 offerId, uint256 productId, uint256 price, uint256 quantity, address offerMaker);
    event TradeSettled(uint256 productId, uint256 offerId);
    event OfferDecided(uint256 productId, uint256 offerId, address offerMaker);
    event OfferPaymentSentInEther(uint256 productId, uint256 offerId, uint256 amount, address beneficiary, address offerMaker);
    event OfferPaymentSentInToken(uint256 productId, uint256 offerId, uint256 amount, address beneficiary, address offerMaker);

    constructor() {
        productNum = 1;
        offNum = 1;
    }
    
    function getProduct(uint256 _productId) external view returns(string memory name, Stage stage, address productOwner, uint256 quantity, uint256 deadline) {
        return (products[_productId].name, products[_productId].reqStage, products[_productId].orderOwner, products[_productId].quantity, products[_productId].deadline);
    }
    
    function getProductOfferIds(uint256 _productId) external view returns(uint256[] memory offerIds) {
        return products[_productId].offerIds;
    }

    function getOffer(uint256 _productId) external view returns(uint256 productId, address offerMaker, uint256 quantity, OfferStatus stage, uint256 amount) {
        return (
            offers[_productId].productId, 
            offers[_productId].offerMaker, 
            offers[_productId].quantity, 
            offers[_productId].offStage,
            offers[_productId].price
        );
    }

    function submitProduct(uint256 _deadline, uint256 _quantity, uint256 _price, string memory _name, bytes32 _description, address token) external returns(uint256 productId) {
        require(_quantity > 0, "Atleast has 1 item");
        require(_deadline > block.timestamp, "Invalid timestamp");
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
        product.tokenAddress = token;
        products[product.Id] = product;
        productsOwner[msg.sender] = product;

        emit ProductAdded(product.Id, product.price, product.quantity, product.deadline, product.name, product.orderOwner, product.reqStage, product.tokenAddress);
        return product.Id;
    }

    function _closeProduct(uint256 _productId) internal {
        require(block.timestamp > products[_productId].deadline, "Deadline not completed");
        products[_productId].reqStage = Stage.Closed;
        emit ProductClosed(_productId);
    }

    // Choose which offer to accept, based on the proposed prices.
    // only order owner can execute & rejects all other offers
    function decideOffer(uint256 _productId, uint256 _acceptedOfferId) external onlySeller(_productId) returns(bool status) {
        _closeProduct(_productId);
        for (uint k = 0; k < products[_productId].offerIds.length; k++) {
            if(products[_productId].offerIds[k] == _acceptedOfferId) {
                offers[_acceptedOfferId].offStage = OfferStatus.Accepted;
                continue;
            }
            offers[products[_productId].offerIds[k]].offStage = OfferStatus.Rejected;
        }
        products[_productId].acceptedOfferId = _acceptedOfferId;
        products[_productId].isDecided = true;

        emit OfferDecided(_productId, _acceptedOfferId, offers[_acceptedOfferId].offerMaker);
        return true;
    }
    
    function submitOffer(uint256 _productId, uint256 _price, uint256 _quantity) external returns(uint256 offerId) {
        require(block.timestamp <= products[_productId].deadline, "Sorry time is completed to submit offer");
        require(Stage.Open == products[_productId].reqStage, "Product is not open now");
        require(_quantity <= products[_productId].quantity, "No more stock left");
        require(products[_productId].offerIds.length <= 50, "Limit of offers crossed");
        require(products[_productId].orderOwner != msg.sender, "Order owner can not make any offer");

        Offer memory offer;
        offer.productId = _productId;
        offer.price = _price;
        offer.offerMaker = msg.sender;
        offer.quantity = _quantity;
        offer.Id = offNum;
        offNum += 1;
        offer.offStage = OfferStatus.Pending;
        offers[offer.Id] = offer;
        products[offer.productId].offerIds.push(offer.Id);
        
        emit OfferAdded(offer.Id, offer.productId, offer.price, offer.quantity, offer.offerMaker);
        return offer.Id;
    }

    function deleteProduct(uint256 _productId) external onlySeller(_productId) {
        for (uint i = 0; i < products[_productId].offerIds.length; i++) {
            delete offers[products[_productId].offerIds[i]];
        }

        delete products[_productId];
        emit ProductRemoved(_productId);
    }

    function paymentInEther(uint256 _productId) external payable {
        require(msg.value <= address(msg.sender).balance, "You don't have sufficiet funds");
        require(offers[products[_productId].acceptedOfferId].offerMaker == msg.sender, "Only authorize buyer can access");
        uint256 offerID = products[_productId].acceptedOfferId;
        address _beneficiary = products[_productId].orderOwner;
        if(products[_productId].isDecided == true && products[_productId].isPaid == false) {
        payable(_beneficiary).transfer(msg.value);
        }
        
        products[_productId].isPaid = true;
        emit OfferPaymentSentInEther(_productId, offerID, msg.value, _beneficiary, offers[offerID].offerMaker);
        emit TradeSettled(_productId, offerID);
    }

    function paymentInToken(uint256 _productId, uint256 _amount, address token) external returns(bool) {
        require(products[_productId].tokenAddress == token, "You can only pay in token defined by order owner");
        require(offers[products[_productId].acceptedOfferId].offerMaker == msg.sender, "Only authorize buyer can access");
        uint256 offerId = products[_productId].acceptedOfferId;
        if(products[_productId].isDecided == true && products[_productId].isPaid == false) {
            IERC20(token).transfer(products[_productId].orderOwner, offers[offerId].price);
        }
        
        products[_productId].isPaid = true;
        emit OfferPaymentSentInToken(_productId, offerId, _amount, products[_productId].orderOwner, offers[offerId].offerMaker);
        emit TradeSettled(_productId, offerId);
    }
}