async function main() {
  const HouseTemplate = await ethers.getContractFactory('House');
  // const TokenFactoryTemplate = await ethers.getContractFactory('TokenFactory');

  // const StandardToken = await StandardTokenTemplate.deploy();
  // await StandardToken.deployed();
  // await StandardToken.initialize('1', 'Template', 'TEMP', 18);
  const House = await HouseTemplate.deploy();
  await House.deployed();
  await House.initialize(
    '0x0000000000000000000000000000000000000000',
    '0x0000000000000000000000000000000000000000',
    '0x0000000000000000000000000000000000000000',
    0,
    0,
  );

  console.log('House deployed to:', House.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
