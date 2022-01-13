

access(all) contract CarOwnership {

    pub var totalSupply: UInt64

    pub struct Ownership {
        pub let vin: String

        init(vin: String) {
            self.vin = vin
        }
    }

    pub resource NFT {
        // Global unique ownership ID
        pub let id: UInt64    
        pub let data: Ownership

        init(ownership: Ownership) {
            self.data = ownership
            CarOwnership.totalSupply = CarOwnership.totalSupply + 1 as UInt64
            self.id = CarOwnership.totalSupply
        }
    }

    pub resource interface OwnershipCollectionPublic {
        pub fun deposit(token: @NFT)
        pub fun getOwnerships(): {UInt64: Ownership}
        pub fun getVins(): {UInt64: String}
        pub fun getIDs(): [UInt64]
    }

    pub resource Collection : OwnershipCollectionPublic {
        //Arrays should be private (Cadence anti-pattern)
        access(contract) var ownedNFTs: @{UInt64: NFT}

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }
        pub fun getOwnerships(): {UInt64: Ownership} {
            var ownerships: {UInt64:Ownership} = {}
            
            for key in self.ownedNFTs.keys {
                let own = &self.ownedNFTs[key] as &NFT
                ownerships.insert(key: own.id, own.data)
            }

            return ownerships
        }
        pub fun getVins(): {UInt64: String} {
            var ownerships: {UInt64:String} = {}
            
            for key in self.ownedNFTs.keys {
                let nft = &self.ownedNFTs[key] as &NFT
                ownerships.insert(key: nft.id, nft.data.vin)
            }

            return ownerships
        }                 

        pub fun withdraw(withdrawID: UInt64): @NFT {
            // Remove the nft from the Collection
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Cannot withdraw: Ownership does not exist in the collection")
            // Return the withdrawn token
            return <- token
        }

        pub fun deposit(token: @NFT) {
            
            //let token <- token as! @CarOwnership.NFT

            // Get the token's ID
            let id = token.id

            // Add the new token to the dictionary
            // Only makes sense if you withdraw and deposit into the same account
            // otherwise id is unique for all Ownerships across all accounts
            let oldToken <- self.ownedNFTs[id] <- token

            // Destroy the empty old token that was "removed"
            destroy oldToken
        }        

         init() {
            self.ownedNFTs <- {}
         }
         destroy() {
            destroy self.ownedNFTs
        }
    }

    // --------
    // Admin 
    // Only Admin should be able to create a new car (a new admin can be created and given to a factory, assembly line, ...)
    // --------
    pub resource Admin {

        /*pub fun createCar(vin: String): Car {
            return Car(vin: vin)
        }*/

        pub fun createOwnership(vin: String): Ownership {
            return Ownership(vin: vin)
        }

        pub fun mintCarOwnership(ownership: Ownership): @NFT {
            return <- create NFT(ownership: ownership)
        }
    
    }

    // --------
    // contract functions
    // --------
    pub fun createEmptyCollection(): @Collection {
        return <-create CarOwnership.Collection()
    }

    // Init of the contract
    init() {
       self.totalSupply = 0

        // Put a new Collection in storage
        self.account.save<@Collection>(<- create Collection(), to: /storage/OwnershipCollection)
        // Create a public capability for the Collection
        self.account.link<&CarOwnership.Collection{CarOwnership.OwnershipCollectionPublic}>
                (/public/OwnershipCollection, target: /storage/OwnershipCollection)

        // The account which deployes this contract is the admin
        // and can create cars
        self.account.save<@Admin>(<- create Admin(), to: /storage/CarOwnershipAdmin)
    }


}
