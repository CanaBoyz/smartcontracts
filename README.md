# Canaboyz

## prepare

- `yarn install`
- copy secrets.json.example to secrets.json and edit

## run tests

```shell
yarn run test
```

## deploy coin

```shell
yarn run deploy:coin:testnet

#OR

hardhat run --network testnet scripts/01.deployCoin.ts
```

## deploy nft

```shell
yarn run deploy:nft:testnet

#OR

hardhat run --network testnet scripts/02.deployNFT.ts
```

## deploy cards

```shell
yarn run deploy:cards:testnet

#OR

hardhat run --network testnet scripts/03.deployCards.ts
```