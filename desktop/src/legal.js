// Where to get the source of this version, as the AGPL asks of a program that
// is passed on to people.
const REPOSITORY = "https://github.com/AlxndrJhn/anchor-plus";

/** A release has a tag, fork-<version>.<build>; any other build points at main. */
const refOf = (version, build) => (version && build ? `fork-${version}.${build}` : "main");

const sourceCodeUrl = (version, build) => `${REPOSITORY}/tree/${refOf(version, build)}`;
const licenseUrl = (version, build) => `${REPOSITORY}/blob/${refOf(version, build)}/LICENSE`;

module.exports = { REPOSITORY, sourceCodeUrl, licenseUrl };
