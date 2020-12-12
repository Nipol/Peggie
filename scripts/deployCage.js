async function main() {
  const CageTemplate = await ethers.getContractFactory('Cage');
  // const TokenFactoryTemplate = await ethers.getContractFactory('TokenFactory');

  // const StandardToken = await StandardTokenTemplate.deploy();
  // await StandardToken.deployed();
  // await StandardToken.initialize('1', 'Template', 'TEMP', 18);
  const Cage = await CageTemplate.deploy();
  await Cage.deployed();
  await Cage.initialize(
    '0x0000000000000000000000000000000000000000',
    '0x0000000000000000000000000000000000000000',
    0,
    '0x0000000000000000000000000000000000000000',
    '0x0000000000000000000000000000000000000000',
  );

  console.log('Cage deployed to:', Cage.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
