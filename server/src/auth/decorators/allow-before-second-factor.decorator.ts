import { SetMetadata } from '@nestjs/common';

export const ALLOW_BEFORE_SECOND_FACTOR = 'allowBeforeSecondFactor';

/**
 * Open to someone who must still add a passkey or authenticator app: what
 * they need to set one up, and to see why.
 */
export const AllowBeforeSecondFactor = () =>
  SetMetadata(ALLOW_BEFORE_SECOND_FACTOR, true);
