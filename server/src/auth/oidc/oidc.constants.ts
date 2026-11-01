/**
 * Constants for OIDC module
 */

// Standard user fields for OIDC user queries
export const OIDC_USER_SELECT = {
  id: true,
  email: true,
  name: true,
  profileImage: true,
  isAdmin: true,
  status: true,
  createdAt: true,
  updatedAt: true,
} as const;
