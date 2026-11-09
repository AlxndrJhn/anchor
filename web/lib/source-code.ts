// Where to get the source of what's running, as the AGPL asks of a program
// people use over a network.
const REPOSITORY = "https://github.com/AlxndrJhn/anchor-plus";

/** A release, e.g. 0.18.0.80, has a tag; any other build points at main. */
const refOf = (version?: string) =>
  version && /^\d+\.\d+\.\d+\.\d+$/.test(version) ? `fork-${version}` : "main";

export const sourceCodeUrl = (version?: string) =>
  `${REPOSITORY}/tree/${refOf(version)}`;

export const licenseUrl = (version?: string) =>
  `${REPOSITORY}/blob/${refOf(version)}/LICENSE`;
