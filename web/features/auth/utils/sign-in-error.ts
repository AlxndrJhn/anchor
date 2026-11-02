import { HTTPError } from "ky";

/** The password was right; the authenticator app's code is still needed. */
export function isTwoStepRequired(error: Error | null) {
  return (
    error instanceof HTTPError &&
    error.response.status === 401 &&
    (error.data as { error?: string } | undefined)?.error ===
      "two_step_required"
  );
}

/** The browser's passkey prompt was closed, or timed out. */
export function isPasskeyCancelled(error: Error | null) {
  return (
    !!error &&
    !(error instanceof HTTPError) &&
    (error.name === "NotAllowedError" ||
      (error.cause instanceof Error && error.cause.name === "NotAllowedError"))
  );
}

/** "pending" when the account waits for approval, otherwise a message to show. */
export function signInError(error: Error | null, provider: string) {
  if (!error) return null;
  if (isPasskeyCancelled(error)) return null;
  if (error.name === "WebAuthnError")
    return "This browser couldn’t use a passkey. Try another one, or sign in with your password.";
  if (!(error instanceof HTTPError))
    return "Couldn’t reach the server. Check your connection and try again.";
  const status = error.response.status;
  if ((status === 403 || status === 401) && /pending/i.test(error.message))
    return "pending" as const;
  if (isTwoStepRequired(error))
    return /isn’t right/.test(error.message)
      ? "That code isn’t right. Check your authenticator app and try again."
      : null;
  if (status === 403 && /turned off for this account/i.test(error.message))
    return "This account signs in with a passkey. Use “Sign in with a passkey” above.";
  if (/passkey/i.test(error.message)) return error.message;
  if (status === 403 && /turned off/i.test(error.message))
    return `Sign in with ${provider} instead.`;
  if ((status === 401 || status === 400) && /oidc/i.test(error.message))
    return `This account signs in with ${provider}. Use the button above.`;
  if (status === 401) return "Incorrect email or password.";
  if (status === 429) return "Too many tries. Wait a minute, then try again.";
  if (status >= 500)
    return "Something went wrong on the server. Try again in a moment.";
  return "Couldn’t sign in. Try again.";
}

/** status is 0 when the server couldn't be reached. */
export function serverSignInError(status: number, isProviderOnly = false) {
  if (!status)
    return "Couldn’t reach the server. Check your connection and try again.";
  if (status === 429) return "Too many tries. Wait a minute, then try again.";
  if (status >= 500)
    return "Something went wrong on the server. Try again in a moment.";
  return isProviderOnly
    ? "That sign-in has expired. Try again."
    : "That sign-in has expired. Try again, or sign in with your email.";
}
