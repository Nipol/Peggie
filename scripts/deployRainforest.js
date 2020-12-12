async function main() {
  const RainforestTemplate = await ethers.getContractFactory('Rainforest');
  // const TokenFactoryTemplate = await ethers.getContractFactory('TokenFactory');

  // const StandardToken = await StandardTokenTemplate.deploy();
  // await StandardToken.deployed();
  // await StandardToken.initialize('1', 'Template', 'TEMP', 18);
  const Rainforest = await RainforestTemplate.deploy(
    '0x198dc91934928ed7d6a95f1c1a07c583891149af',
    '0x342B31ddc0dd2Be5598E6A8C7392ABd8a5993D61',
    '0xDB078287f8b44F3998c81E2e7cd3E793DD3d1694',
    '0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6',
    '0x82E9Ee68fDC77dF1EDd5F7691A82b630636656db',
    '0x0000000000000000000000002eadf1aa0504fbf5f65e6e23f21a63e5b4182b3a',
  );
  await Rainforest.deployed();

  console.log('Rainforest deployed to:', Rainforest.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
