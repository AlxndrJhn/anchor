export interface User {
  id: string;
  email: string;
  name: string;
  profileImage?: string;
  isAdmin?: boolean;
  /** Older servers leave it out. */
  hasPassword?: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface AuthResponse {
  access_token?: string;
  refresh_token?: string;
  user: User;
  message?: string;
}

export interface RefreshTokenResponse {
  access_token: string;
  refresh_token: string;
}

export interface ApiTokenResponse {
  apiToken: string | null;
}

export interface LoginCredentials {
  email: string;
  password: string;
  /** From the authenticator app, or a recovery code, once two-step is on. */
  code?: string;
}

export interface RegisterCredentials {
  email: string;
  password: string;
  name: string;
}

export interface ChangePasswordCredentials {
  currentPassword: string;
  newPassword: string;
}

export interface UpdateProfileDto {
  name?: string | null;
}

export interface OidcConfig {
  enabled: boolean;
  providerName: string;
  issuerUrl?: string;
  clientId?: string;
  disableInternalAuth: boolean;
}

export interface OidcExchangeResponse {
  access_token: string;
  refresh_token: string;
  user: User;
  redirectUrl: string;
}

export interface MagicLoginCode {
  code: string;
  expiresAt: string;
}

export type RegistrationMode = "disabled" | "enabled" | "review";

export interface Passkey {
  id: string;
  name: string;
  createdAt: string;
  lastUsedAt: string | null;
}

/** How you sign in, for Settings. */
export interface SecurityStatus {
  hasPassword: boolean;
  passwordSignIn: boolean;
  twoStep: boolean;
  recoveryCodesLeft: number;
  passkeys: Passkey[];
}

export interface TwoStepSetup {
  secret: string;
  uri: string;
}

export interface RecoveryCodes {
  recoveryCodes: string[];
}
