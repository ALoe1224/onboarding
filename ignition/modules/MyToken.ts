import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MyTokenModule", (m) => {
  const initialSupply = m.getParameter(
    "initialSupply",
    1000n * 10n ** 18n
  );

  const token = m.contract("MyToken", [initialSupply]);

  return { token };
});